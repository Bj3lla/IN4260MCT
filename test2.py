import collections
import signal
import socket
import struct
import threading
import time
from collections import deque

import matplotlib.pyplot as plt
import neurokit2 as nk
import numpy as np
import sifi_bridge_py as sbp
from matplotlib import animation

# ---------------------------------------------------------------------------
# Live plot configuration.
#
#   IMU_FS         IMU sampling rate in Hz. Must match configure_imu(fs=...)
#                  so the time axis is correct.
#   WINDOW_SEC     How many seconds of history to keep on screen. The plot
#                  scrolls left as new samples arrive.
#   FRAME_INTERVAL How often (in ms) matplotlib redraws the plot. The data
#                  itself arrives much faster than this on the BLE side —
#                  we just don't need to redraw at the BLE rate.
# ---------------------------------------------------------------------------
#

# SOCKET SETUP

UDP_IP = "127.0.0.1"  # Use "127.0.0.1" for testing locally, or a remote IP address
UDP_PORT = 4242
MESSAGE = "Hello, UDP Server!"

keep_running = True

DEBUG = True

IMU_FS = 100
WINDOW_SEC = 10
FRAME_INTERVAL = 50  # ms


PPG_SPS = 200  # raw AFE sample rate (Hz)
PPG_AVG = 4  # averaging factor
PPG_FS = PPG_SPS // PPG_AVG  # effective rate delivered in the stream (Hz)

HR_UPDATE_SEC = 1.0  # interval between HR computations
HR_AXIS_PADDING_BPM = 5.0
PPG_CHANNEL = "g"


ppg_buf = deque(maxlen=PPG_FS * WINDOW_SEC)
warmup_samples_remaining = PPG_FS

# ---------------------------------------------------------------------------
# Shared state between the acquisition thread (which receives BLE packets)
# and the plotting thread (matplotlib's main loop).
#
# A deque with a bounded maxlen automatically discards the oldest sample
# when full, so we always hold exactly WINDOW_SEC seconds of history with
# no manual trimming. Appends and iteration are atomic enough under the
# GIL for a tutorial-grade plot.
# ---------------------------------------------------------------------------
norm_buffer = collections.deque(maxlen=IMU_FS * WINDOW_SEC)

x_buffer = collections.deque(maxlen=IMU_FS * WINDOW_SEC)
y_buffer = collections.deque(maxlen=IMU_FS * WINDOW_SEC)
z_buffer = collections.deque(maxlen=IMU_FS * WINDOW_SEC)

# create socket for sending
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# precode
stop_event = threading.Event()


def acquisition_loop(sb):
    """Background thread: pull IMU packets and append the accel norm."""
    last_hr_update = -1.0
    current_hr = None
    current_hr_sd = None
    t0 = time.time()
    while not stop_event.is_set():
        t = time.time() - t0
        packet = sb.get_data(timeout=0.5)
        if not packet:
            continue

        p_type = packet.get("packet_type")

        if p_type == "imu":
            # Extract all the data and average it before sending in a new format
            data = packet["data"]
            ax, ay, az = data["ax"], data["ay"], data["az"]
            qw, qx, qy, qz = data["qw"], data["qx"], data["qy"], data["qz"]

            valid_samples = [
                (x, y, z, w, q_x, q_y, q_z)
                for x, y, z, w, q_x, q_y, q_z in zip(ax, ay, az, qw, qx, qy, qz)
                if None not in (x, y, z, w, q_x, q_y, q_z)
            ]
            if not valid_samples:
                if DEBUG:
                    print("Skipping IMU packet: no complete samples yet.")
                continue

            values = np.asarray(valid_samples, dtype=np.float32)
            avgX, avgY, avgZ, avgQW, avgQX, avgQY, avgQZ = np.mean(values,axis=0,)

            if DEBUG:
                print("--------------")
                print(f"Valid IMU samples: {len(valid_samples)}/{len(ax)}")
                print(f"avg X: {avgX}")
                print(f"avg Y: {avgY}")
                print(f"avg Z: {avgZ}")
                print(f"avg Q: {avgQW}, {avgQX}, {avgQY}, {avgQZ}")
                print("--------------")


            type_str = "IMU"
            send_buffer = [avgX, avgY, avgZ, avgQW, avgQX, avgQY, avgQZ]

            text_bytes = type_str.encode('utf-8')
            struct_format = '<3s7F'
            packed_buffer = struct.pack(struct_format,text_bytes,*send_buffer)
            sock.sendto(packed_buffer, (UDP_IP, UDP_PORT))


            x_buffer.append(avgX)
            y_buffer.append(avgY)
            z_buffer.append(avgZ)

        
        # this part is essentially just ripped from the example code, hopefully it runs fast enough?
        if p_type == "ppg":
            samples = packet["data"].get(PPG_CHANNEL, [])
            global warmup_samples_remaining
            if warmup_samples_remaining > 0:
                skip = min(warmup_samples_remaining, len(samples))
                samples = samples[skip:]
                warmup_samples_remaining -= skip
            ppg_buf.extend(samples)
            if (len(ppg_buf) >= PPG_FS * WINDOW_SEC
                    and t - last_hr_update >= HR_UPDATE_SEC):
                last_hr_update = t

                # nk.ppg_process runs the whole pipeline for us: bandpass
                # cleaning, systolic-peak detection, and per-beat HR in bpm.
                # We feed it only the current window, so the cost stays
                # bounded no matter how long the demo runs.
                signal = np.asarray(ppg_buf, dtype=float)
                try:
                    df, info = nk.ppg_process(signal, sampling_rate=PPG_FS)
                    hr_series = df["PPG_Rate"].to_numpy()
                    # Use the mean for a robust central estimate and the
                    # standard deviation as a quick measure of how steady
                    # the rate is across the window. Both ignore NaNs that
                    # can appear before the first peak is detected.
                    hr_clean = hr_series[np.isfinite(hr_series)]
                    if hr_clean.size > 0:
                        current_hr = float(np.mean(hr_clean))
                        current_hr_sd = float(np.std(hr_clean))
                        if DEBUG:
                            print(f"  t={t:5.1f} s | "
                                f"HR = {current_hr:5.1f} ± "
                                f"{current_hr_sd:4.1f} bpm")

                        hdr = "HRT"
                        struct_format = "<3s2F"
                        text_bytes = hdr.encode('utf-8')
                        packed_data = struct.pack(struct_format,text_bytes,current_hr, current_hr_sd)
                        sock.sendto(packed_data, (UDP_IP, UDP_PORT))

                except Exception as e:
                    # nk.ppg_process can raise on very short or very noisy
                    # windows. Skip and try again on the next tick.
                    print(f"  t={t:5.1f} s | HR computation skipped ({e})")
            if DEBUG:
                print("--------------")
                print(f"PPG: {samples}")
                print("--------------")


# ---------------------------------------------------------------------------
# Connect, configure, start streaming.
# ---------------------------------------------------------------------------
sb = sbp.SifiBridge()
sb.connect()

# Restrict streaming to the IMU only so the BLE link isn't shared with
# sensors we don't plot. configure_sensors() is the on/off switch;
# configure_imu() then sets the IMU-specific parameters. accel_range=8
sb.configure_sensors(imu=True, ppg=True)
sb.configure_imu(fs=IMU_FS, accel_range=8)

sb.configure_ppg(
    sps=PPG_SPS,
    ir=15,
    red=15,
    green=15,
    blue=15,
    sens=sbp.PpgSensitivity.MEDIUM,
    avg=PPG_AVG,
)

sb.start()
time.sleep(1.0)
sb.clear_data_buffer()

# Spawn the acquisition thread. It runs until stop_event is set in the
# cleanup block below.
acq_thread = threading.Thread(target=acquisition_loop, args=(sb,), name="imu-acq")
acq_thread.start()

# ---------------------------------------------------------------------------
# Matplotlib live plot. FuncAnimation calls update() every FRAME_INTERVAL
# ms; update() snapshots the buffer and redraws the line. The window
# scrolls left as new samples arrive because xlim is anchored to the
# right edge of the buffer.
# ---------------------------------------------------------------------------

fig, ax = plt.subplots(figsize=(10, 4))

(line_x,) = ax.plot([], [], color="tab:red", linewidth=0.9, label="Avg X")
(line_y,) = ax.plot([], [], color="tab:green", linewidth=0.9, label="Avg Y")
(line_z,) = ax.plot([], [], color="tab:blue", linewidth=0.9, label="Avg Z")

ax.set_xlim(0, WINDOW_SEC)
ax.set_ylim(-10, 10)

ax.set_xlabel("Time (s, trailing window)")
ax.set_ylabel("|avg acceleration|")
ax.set_title(f"Live IMU acceleration norm — last {WINDOW_SEC} s")
ax.grid(True, alpha=0.3)


def update(_frame):
    # take snapshot of our different quques
    x_samples = list(x_buffer)
    y_samples = list(y_buffer)
    z_samples = list(z_buffer)

    n = len(x_samples)
    if n == 0:
        return line_x, line_y, line_z

    # Snapshot the deque so the line draw sees a stable view even if the
    # acquisition thread keeps appending behind us.
    t = [(i - (n - 1)) / IMU_FS + WINDOW_SEC for i in range(n)]

    line_x.set_data(t, x_samples)
    line_y.set_data(t, y_samples)
    line_z.set_data(t, z_samples)

    all_samples = x_samples + y_samples + z_samples
    ymin = min(all_samples)
    ymax = max(all_samples)

    padding = max((ymax - ymin) * 0.1, 0.1)
    ax.set_ylim(ymin - padding, ymax + padding)

    return line_x, line_y, line_z


anim = animation.FuncAnimation(
    fig, update, interval=FRAME_INTERVAL, blit=True, cache_frame_data=False
)

print("Live IMU norm plot. Close the window to stop.")
try:
    plt.show()  # blocks until the window is closed
finally:
    # Clean shutdown: tell the acquisition thread to exit, then tear
    # down the BLE link.
    stop_event.set()
    acq_thread.join(timeout=2.0)
    sb.stop()
    sb.disconnect()
    time.sleep(0.5)
    print("Disconnected.")
