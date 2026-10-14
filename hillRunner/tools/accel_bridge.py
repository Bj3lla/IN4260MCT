#!/usr/bin/env python3
"""
Send accelerometer samples to the game over UDP (default 127.0.0.1:4242).

  python accel_bridge.py sim                    # fake device: rhythmic dive pattern
  python accel_bridge.py serial COM3            # forward "x,y,z" lines from a serial device
  python accel_bridge.py serial /dev/ttyUSB0 --baud 115200

Serial mode needs:  pip install pyserial
Your device should print one line per sample, e.g. "0.02,-0.11,9.79".
"""
import argparse
import math
import socket
import time


def send(sock, addr, x, y, z):
    sock.sendto(f"{x:.4f},{y:.4f},{z:.4f}".encode(), addr)


def run_sim(sock, addr, rate):
    print(f"Simulating device -> {addr[0]}:{addr[1]}  (Ctrl+C to stop)")
    t0 = time.time()
    # A couple of seconds of rest first so the game can auto-calibrate.
    while True:
        t = time.time() - t0
        z = 9.81
        if t > 2.0:
            # push for ~0.6 s every 1.5 s
            phase = (t - 2.0) % 1.5
            if phase < 0.6:
                z += 6.0 * math.sin(phase / 0.6 * math.pi)
        send(sock, addr, 0.0, 0.0, z)
        time.sleep(1.0 / rate)


def run_serial(sock, addr, port, baud):
    import serial  # pyserial

    print(f"Forwarding {port} @ {baud} -> {addr[0]}:{addr[1]}  (Ctrl+C to stop)")
    with serial.Serial(port, baud, timeout=1) as ser:
        while True:
            line = ser.readline().decode(errors="ignore").strip()
            if not line:
                continue
            parts = line.replace(";", ",").replace(" ", ",").split(",")
            parts = [p for p in parts if p]
            try:
                x, y, z = (float(v) for v in parts[:3])
            except ValueError:
                continue
            send(sock, addr, x, y, z)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["sim", "serial"])
    ap.add_argument("port", nargs="?", help="serial port, e.g. COM3 or /dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--udp-port", type=int, default=4242)
    ap.add_argument("--rate", type=float, default=100.0, help="sim samples per second")
    a = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    addr = (a.host, a.udp_port)
    try:
        if a.mode == "sim":
            run_sim(sock, addr, a.rate)
        else:
            if not a.port:
                ap.error("serial mode needs a port")
            run_serial(sock, addr, a.port, a.baud)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
