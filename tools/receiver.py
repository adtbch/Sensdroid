#!/usr/bin/env python3
"""Sensdroid PC receiver (TCP).

Listens on 127.0.0.1:<port> and prints incoming 26-byte frames.

Frame format (little-endian, 26 bytes):
  - Byte 0:  sensor type id (uint8)
  - Byte 1-8: timestamp ms (uint64)
  - Byte 9-24: 4 x float32 values
  - Byte 25: checksum (uint8) = XOR of bytes 0..24

This matches SensorData.toBytes() in the Flutter app.

Usage:
  1) Enable USB debugging and connect phone to PC
  2) Run: adb reverse tcp:7788 tcp:7788
  3) Run: python tools/receiver.py --port 7788
  4) In the app: Target Device = PC, Scan -> Connect -> Start Transmission
"""

from __future__ import annotations

import argparse
import datetime as _dt
import socket
import struct
import sys
from typing import Iterable, Tuple

FRAME_SIZE = 26

SENSOR_TYPE = {
    0: "accelerometer",
    1: "gyroscope",
    2: "magnetometer",
    3: "gps",
    4: "proximity",
    5: "light",
    6: "YPR",
    255: "unknown",
}


def _xor_checksum(data: bytes) -> int:
    c = 0
    for b in data:
        c ^= b
    return c & 0xFF


def _decode_frame(frame: bytes) -> Tuple[int, int, Tuple[float, float, float, float], int, bool]:
    if len(frame) != FRAME_SIZE:
        raise ValueError(f"frame must be {FRAME_SIZE} bytes")

    sensor_type_id = frame[0]
    ts_ms = struct.unpack_from("<Q", frame, 1)[0]
    values = struct.unpack_from("<ffff", frame, 9)
    recv_checksum = frame[25]
    calc_checksum = _xor_checksum(frame[:25])
    ok = recv_checksum == calc_checksum
    return sensor_type_id, ts_ms, values, calc_checksum, ok


def _format_line(
    idx: int,
    sensor_type_id: int,
    ts_ms: int,
    values: Tuple[float, float, float, float],
    checksum_ok: bool,
) -> str:
    sensor_name = SENSOR_TYPE.get(sensor_type_id, f"type:{sensor_type_id}")
    ts = _dt.datetime.fromtimestamp(ts_ms / 1000.0)

    v0, v1, v2, v3 = values
    # Keep output stable and easy to grep.
    return (
        f"{idx:06d} | {sensor_name:<14} | {ts.isoformat(timespec='milliseconds')} | "
        f"{v0:+.4f}, {v1:+.4f}, {v2:+.4f}, {v3:+.4f} | "
        f"checksum={'OK' if checksum_ok else 'BAD'}"
    )


def _frames_from_stream(chunks: Iterable[bytes]) -> Iterable[bytes]:
    buf = bytearray()
    for chunk in chunks:
        if not chunk:
            continue
        buf.extend(chunk)
        while len(buf) >= FRAME_SIZE:
            frame = bytes(buf[:FRAME_SIZE])
            del buf[:FRAME_SIZE]
            yield frame


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Sensdroid TCP receiver")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=7788, help="Bind port (default: 7788)")
    parser.add_argument("--limit", type=int, default=0, help="Stop after N frames (0 = infinite)")
    args = parser.parse_args(argv)

    if not (1 <= args.port <= 65535):
        print("Invalid --port", file=sys.stderr)
        return 2

    print(f"Listening on {args.host}:{args.port} (frame={FRAME_SIZE} bytes) …")
    print("Tip: run `adb reverse tcp:{0} tcp:{0}` before connecting from the phone.".format(args.port))

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((args.host, args.port))
        server.listen(1)

        conn, addr = server.accept()
        with conn:
            print(f"Client connected from {addr[0]}:{addr[1]}")
            conn.settimeout(None)

            def _read_chunks() -> Iterable[bytes]:
                while True:
                    data = conn.recv(4096)
                    if not data:
                        break
                    yield data

            idx = 0
            for frame in _frames_from_stream(_read_chunks()):
                idx += 1
                sensor_type_id, ts_ms, values, _calc, ok = _decode_frame(frame)
                print(_format_line(idx, sensor_type_id, ts_ms, values, ok))
                if args.limit and idx >= args.limit:
                    break

    print("Disconnected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
