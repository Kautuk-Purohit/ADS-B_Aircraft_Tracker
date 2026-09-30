#!/usr/bin/env python3
"""
Streams a captured RTL-SDR I/Q file (raw interleaved bytes, same format as
modes1.bin) out over a serial port to the FPGA's rf_receiver.sv, at the
baud rate uart_rx is configured for.

This is playback mode, not live capture: true real-time 2MHz I/Q streaming
needs ~40 Mbps, and even the fastest practical UART link (~12 Mbaud) only
covers a fraction of that -- the math doesn't work, not a code problem. At
3M baud this sends slower than the original 2MHz capture rate (about 13x
slower), which is fine for what this proves: that the FPGA correctly
decodes real captured ADS-B data, not that it runs at live line-rate.

The FPGA side never needs to be told to slow down -- rf_receiver.sv and
everything downstream of it runs on a 100MHz clock, vastly faster than any
UART bit rate, so every byte gets fully processed long before the next one
arrives. No flow control, no buffering, no backpressure needed.

Usage:
    python3 pc_sender.py --port /dev/ttyUSB1 --file modes1.bin
    python3 pc_sender.py --port COM5 --file modes1.bin --baud 3000000
    python3 pc_sender.py --port /dev/ttyUSB1 --file modes1.bin --loop
"""

import argparse
import sys
import time

try:
    import serial
except ImportError:
    print("This needs pyserial: pip install pyserial", file=sys.stderr)
    sys.exit(1)

CHUNK_SIZE = 4096


def stream_file(port_name: str, baud: int, file_path: str, loop: bool, quiet: bool) -> None:
    with open(file_path, "rb") as f:
        data = f.read()

    if len(data) == 0:
        print(f"'{file_path}' is empty, nothing to send.", file=sys.stderr)
        sys.exit(1)

    if len(data) % 2 != 0:
        print(f"Warning: '{file_path}' has an odd number of bytes ({len(data)}); "
              f"the last byte has no I/Q partner and iq_deinterleaver will hold "
              f"it until the next run's first byte arrives.", file=sys.stderr)

    # opened once and kept open across every pass -- reopening the port between
    # passes (as an earlier version of this script did) toggles DTR/RTS and can
    # glitch a stray bit onto the line right at the pass boundary, corrupting
    # the first byte or two of the next pass. Confirmed by testing --loop
    # against a real serial loopback: reopening every pass failed a byte
    # comparison at the boundary, keeping the port open across passes did not.
    with serial.Serial(port_name, baudrate=baud, bytesize=8, parity='N', stopbits=1) as ser:
        pass_num = 0
        while True:
            pass_num += 1
            sent = 0
            start = time.time()
            for offset in range(0, len(data), CHUNK_SIZE):
                chunk = data[offset:offset + CHUNK_SIZE]
                ser.write(chunk)
                sent += len(chunk)
                if not quiet:
                    pct = 100 * sent / len(data)
                    print(f"\rpass {pass_num}: {sent}/{len(data)} bytes ({pct:.1f}%)",
                          end="", file=sys.stderr)
            ser.flush()
            elapsed = time.time() - start
            if not quiet:
                print(f"\rpass {pass_num}: {sent}/{len(data)} bytes sent in {elapsed:.2f}s"
                      f" ({sent/elapsed/1000:.1f} KB/s)                    ", file=sys.stderr)
            if not loop:
                break


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--port", required=True, help="serial port, e.g. /dev/ttyUSB1 or COM5")
    p.add_argument("--file", required=True, help="raw I/Q capture file to stream (e.g. modes1.bin)")
    p.add_argument("--baud", type=int, default=3_000_000,
                    help="must match uart_rx's BAUD_RATE parameter (default 3000000)")
    p.add_argument("--loop", action="store_true", help="keep re-sending the file until stopped")
    p.add_argument("--quiet", action="store_true", help="suppress progress output")
    args = p.parse_args()

    try:
        stream_file(args.port, args.baud, args.file, args.loop, args.quiet)
    except KeyboardInterrupt:
        print("\nstopped.", file=sys.stderr)
    except serial.SerialException as e:
        print(f"Couldn't open '{args.port}': {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()