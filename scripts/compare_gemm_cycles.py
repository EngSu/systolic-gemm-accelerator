#!/usr/bin/env python3
"""Analytical cycle-accounting baseline for currently verified OS/WS GEMM grids."""
import csv
from pathlib import Path

CONFIGS = [(2, 2, 2), (3, 3, 3), (4, 4, 4), (2, 4, 3)]  # M, K, N
DATA_WIDTH = 16
ACC_WIDTH = 32
SETUP_EDGES = 1  # OS: clear accumulator; WS: parallel weight preload


def estimate(m, k, n):
    if min(m, k, n) < 1:
        raise ValueError("Matrix dimensions must be positive")
    return {
        "gemm_MxKxN": "{}x{}x{}".format(m, k, n),
        "macs": m * k * n,
        "os_pes": m * n,
        "ws_pes": k * n,
        "os_compute_edges": k + m + n - 2,
        "ws_compute_edges": m + k - 1,
        "os_setup_edges": SETUP_EDGES,
        "ws_setup_edges": SETUP_EDGES,
        "os_setup_plus_compute": SETUP_EDGES + k + m + n - 2,
        "ws_setup_plus_compute": SETUP_EDGES + m + k - 1,
        "os_input_bits_per_edge": (m + n) * DATA_WIDTH,
        "ws_activation_bits_per_edge": k * DATA_WIDTH,
        "ws_parallel_weight_bits": k * n * DATA_WIDTH,
        "os_output_bits": m * n * ACC_WIDTH,
        "ws_output_bits_per_row": n * ACC_WIDTH,
    }


def main():
    rows = [estimate(*config) for config in CONFIGS]
    destination = Path("reports/comparison")
    destination.mkdir(parents=True, exist_ok=True)
    csv_path = destination / "baseline_cycle_estimates.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    print("GEMM       MACs  OS PEs  WS PEs  OS compute  WS compute  OS total  WS total")
    for row in rows:
        print("{:<10} {:>4} {:>7} {:>7} {:>11} {:>11} {:>9} {:>9}".format(
            row["gemm_MxKxN"], row["macs"], row["os_pes"],
            row["ws_pes"], row["os_compute_edges"],
            row["ws_compute_edges"], row["os_setup_plus_compute"],
            row["ws_setup_plus_compute"]
        ))
    print("\nSaved:", csv_path)
    print("MODEL ONLY: not measured RTL wall-clock time or FPGA performance.")
    print("Totals assume one clear/preload edge; exclude reset, output collection, stalls, and memory transfers.")


if __name__ == "__main__":
    main()
