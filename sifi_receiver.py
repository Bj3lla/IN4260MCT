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

DEBUG = False
DEBUG_PPG = True
DEBUG_IMU = False
DEBUG_EMG = False

IMU_FS = 100
WINDOW_SEC = 10
FRAME_INTERVAL = 50  # ms


PPG_SPS = 200  # raw AFE sample rate (Hz)
PPG_AVG = 4  # averaging factor
PPG_FS = PPG_SPS // PPG_AVG  # effective rate delivered in the stream (Hz)

HR_UPDATE_SEC = 1.0  # interval between HR computations
HR_AXIS_PADDING_BPM = 5.0
PPG_CHANNEL = "g"

# EMG fist-clench detection.

EMG_FS = 2000
EMG_WINDOW_SEC = 0.050
EMG_WINDOW_SAMPLES = int(EMG_FS * EMG_WINDOW_SEC)

emg_sample_buffer = deque(maxlen=EMG_WINDOW_SAMPLES)

# Avoid flooding Godot with UDP messages at the raw EMG packet rate.
EMG_SEND_RATE_HZ = 50.0
EMG_SEND_INTERVAL = 1.0 / EMG_SEND_RATE_HZ

# These are temporary starting values based on your output.
# Calibrate them using real relaxed/clenched recordings.
EMG_ON_THRESHOLD = 0.00015
EMG_OFF_THRESHOLD = 0.00007

emg_active_since = None
emg_is_clenched = False
emg_last_trigger_time = -float("inf")

# Optional display/history buffer.
emg_envelope_buffer = deque(maxlen=200)


ppg_buf = deque(maxlen=PPG_FS * WINDOW_SEC)

# try different values here, how many samples do we average over
emg_buf = deque(maxlen=50)
warmup_samples_remaining = PPG_FS

# ---------------------------------------------------------------------------
# A deque with a bounded maxlen automatically discards the oldest sample
# when full, so we always hold exactly WINDOW_SEC seconds of history with
# no manual trimming. Appends and iteration are atomic enough under the
# GIL for a tutorial-grade plot.
# ---------------------------------------------------------------------------
norm_buffer = collections.deque(maxlen=IMU_FS * WINDOW_SEC)


# unused - debug
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
    last_emg_send_time = 0.0


    while not stop_event.is_set():
        t = time.time() - t0
        packet = sb.get_data(timeout=0.5)
        if not packet:
            continue

        p_type = packet.get("packet_type")
        data = packet["data"]

        if p_type == "imu":
            # Extract all the data and average it before sending in a new format
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

            if DEBUG or DEBUG_IMU:
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
            struct_format = '<3s7f'
            packed_buffer = struct.pack(struct_format,text_bytes,*send_buffer)
            sock.sendto(packed_buffer, (UDP_IP, UDP_PORT))


        # we has to work for both band and point
        if p_type in ("emg", "emg_armband"):
            if "emg" in data:
                emg_measurement = data["emg"]
            else:
                emg_measurement = data.get("emg0", [])

            if emg_measurement is None or len(emg_measurement) == 0:
                continue

            emg = np.asarray(
                [sample for sample in emg_measurement if sample is not None],
                dtype=np.float32,
            )

            if emg.size == 0:
                continue

            # Keep a rolling 50 ms history of raw, already-filtered EMG samples.
            emg_sample_buffer.extend(emg.tolist())

            if len(emg_sample_buffer) < EMG_WINDOW_SAMPLES:
                continue

            window = np.asarray(emg_sample_buffer, dtype=np.float32)

            # Mean absolute value: rectified EMG + moving average.
            emg_strength = float(np.mean(np.abs(window)))

            # RMS is also valid, but choose one measure and stay consistent.
            # emg_strength = float(np.sqrt(np.mean(window * window)))

            now = time.monotonic()

            # Send at 50 Hz, rather than sending raw 2000 Hz EMG samples.
            if now - last_emg_send_time >= EMG_SEND_INTERVAL:
                last_emg_send_time = now

                # 3-byte header + one 32-bit float = 7 bytes.
                packed_emg = struct.pack(
                    "<3sf",
                    b"EMG",
                    emg_strength,
                )

                sock.sendto(packed_emg, (UDP_IP, UDP_PORT))

                if DEBUG_EMG:
                    print(f"EMG envelope: {emg_strength:.8f}")

        if p_type == "ppg":
            samples = data.get(PPG_CHANNEL, [])
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
                        if DEBUG or DEBUG_PPG:
                            print(f"  t={t:5.1f} s | "
                                f"HR = {current_hr:5.1f} ± "
                                f"{current_hr_sd:4.1f} bpm")

                        hdr = "HRT"
                        struct_format = "<3s2f"
                        text_bytes = hdr.encode('utf-8')
                        packed_data = struct.pack(struct_format,text_bytes,current_hr, current_hr_sd)
                        sock.sendto(packed_data, (UDP_IP, UDP_PORT))

                except Exception as e:
                    # nk.ppg_process can raise on very short or very noisy
                    # windows. Skip and try again on the next tick.
                    print(f"  t={t:5.1f} s | HR computation skipped ({e})")
            if DEBUG or DEBUG_PPG:
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
sb.configure_sensors(imu=True, emg=True, ppg=True)
sb.configure_imu(fs=IMU_FS, accel_range=8)
sb.configure_emg(fs=2000, mains_notch=50, bandpass=True, flo=20, fhi=450)

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

try:
    acq_thread.start()
except (KeyboardInterrupt, SystemExit):
    stop_event.set()
    acq_thread.join(timeout=2.0)
    sb.stop()
    sb.disconnect()
    time.sleep(0.5)
    print("Disconnected.")
# ---------------------------------------------------------------------------
# Matplotlib live plot. FuncAnimation calls update() every FRAME_INTERVAL
# ms; update() snapshots the buffer and redraws the line. The window
# scrolls left as new samples arrive because xlim is anchored to the
# right edge of the buffer.
# ---------------------------------------------------------------------------








def plot():

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
