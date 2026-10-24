#!/usr/bin/env python3
"""Run parameterized OS and WS Icarus simulations against Python GEMM.

Run from anywhere with:
    /usr/bin/python3 verification/regressions/run_param_gemm_regression.py

Requires the repository's existing os_array_param_tb.v, ws_array_param_tb.v,
and verification/reference_models/gemm_reference.py. Does not modify RTL.
"""

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from verification.reference_models.gemm_reference import gemm

# (M output rows, K reduction terms, N output columns)
CONFIGS = [(2, 2, 2), (3, 3, 3), (4, 4, 4), (2, 4, 3)]

RTL = {
    "OS": (
        "os_array_param_tb",
        ["rtl/pe/pe_os.v", "rtl/array/os/os_array_param.v",
         "tb/array/os/os_array_param_tb.v"],
    ),
    "WS": (
        "ws_array_param_tb",
        ["rtl/pe/pe_ws.v", "rtl/array/ws/ws_array_param.v",
         "tb/array/ws/ws_array_param_tb.v"],
    ),
}


def expected_matrix(m, k, n, case_id):
    """Reconstruct the stimulus pattern from the existing RTL testbenches."""
    if case_id == 0:
        a = [[i * k + h + 1 for h in range(k)] for i in range(m)]
        b = [[5 + h * n + j for j in range(n)] for h in range(k)]
    else:
        a = [[(i * k + h + 1) * (-1 if (i + h) % 2 == 0 else 1)
              for h in range(k)] for i in range(m)]
        b = [[(h * n + j + 2) * (-1 if (h + j) % 2 else 1)
              for j in range(n)] for h in range(k)]
    return gemm(a, b, data_width=16, acc_width=32)


def run_command(args):
    result = subprocess.run(args, cwd=str(ROOT), text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(
            "Command failed (exit {}): {}\nSTDOUT:\n{}\nSTDERR:\n{}".format(
                result.returncode, " ".join(map(str, args)),
                result.stdout, result.stderr))
    return result.stdout


def parse_os(output, m, k, n):
    lines = output.splitlines()
    observed = {}
    pattern = re.compile(r"^COMPLETED case=(\d+) array=(\d+)x(\d+) K=(\d+)$")
    for i, raw_line in enumerate(lines):
        match = pattern.match(raw_line.strip())
        if not match:
            continue
        case, rows, cols, reduction = map(int, match.groups())
        if (rows, reduction, cols) != (m, k, n):
            raise ValueError("OS completion dimensions do not match configuration")
        if case in observed:
            raise ValueError("Duplicate OS case {}".format(case))
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j >= len(lines) or lines[j].strip() != "Final C matrix:":
            raise ValueError("OS matrix header missing for case {}".format(case))
        matrix = []
        for line in lines[j + 1:j + 1 + m]:
            try:
                row = [int(token) for token in line.split()]
            except ValueError as exc:
                raise ValueError("OS matrix row is not numeric: {!r}".format(line)) from exc
            if len(row) != n:
                raise ValueError("OS case {} row has {} columns; expected {}".format(case, len(row), n))
            matrix.append(row)
        if len(matrix) != m:
            raise ValueError("OS case {} has insufficient rows".format(case))
        observed[case] = matrix
    if "ALL PARAMETERIZED OS ARRAY TESTS PASSED" not in output:
        raise ValueError("OS testbench did not report a passing simulation")
    if set(observed) != {0, 1}:
        raise ValueError("OS expected cases 0 and 1, got {}".format(sorted(observed)))
    return observed


def parse_ws(output, m, k, n):
    observed = {0: {}, 1: {}}
    pattern = re.compile(r"^Case (\d+) row (\d+):\s*(.*)$")
    for raw_line in output.splitlines():
        match = pattern.match(raw_line.strip())
        if not match:
            continue
        case, row = int(match.group(1)), int(match.group(2))
        if case not in observed or row < 0 or row >= m:
            raise ValueError("WS unexpected case or row: {} / {}".format(case, row))
        if row in observed[case]:
            raise ValueError("WS duplicate output row {} in case {}".format(row, case))
        values = [int(part) for part in match.group(3).split()]
        if len(values) != n:
            raise ValueError("WS case {} row {} has {} columns; expected {}".format(
                case, row, len(values), n))
        observed[case][row] = values

    if "ALL PARAMETERIZED WS ARRAY TESTS PASSED" not in output:
        raise ValueError("WS testbench did not report a passing simulation")
    result = {}
    for case in (0, 1):
        if set(observed[case]) != set(range(m)):
            raise ValueError("WS missing output row(s) for case {}".format(case))
        result[case] = [observed[case][row] for row in range(m)]
    return result


def compile_and_simulate(flow, m, k, n, directory):
    top, source_paths = RTL[flow]
    executable = directory / ("{}_{}x{}x{}.vvp".format(flow.lower(), m, k, n))
    args = ["iverilog", "-g2012", "-s", top,
            "-P", top + ".COLS=" + str(n)]
    if flow == "OS":
        args += ["-P", top + ".ROWS=" + str(m),
                 "-P", top + ".K=" + str(k)]
    else:
        args += ["-P", top + ".M_ROWS=" + str(m),
                 "-P", top + ".K_STAGES=" + str(k)]
    args += ["-o", str(executable)] + source_paths
    run_command(args)
    output = run_command(["vvp", str(executable)])
    if flow == "OS":
        return parse_os(output, m, k, n)
    return parse_ws(output, m, k, n)


def main():
    for tool in ("iverilog", "vvp"):
        if shutil.which(tool) is None:
            raise RuntimeError("Missing executable on PATH: " + tool)

    total = 0
    with tempfile.TemporaryDirectory(prefix="gemm_param_regression_") as tmp:
        working = Path(tmp)
        for m, k, n in CONFIGS:
            os_results = compile_and_simulate("OS", m, k, n, working)
            ws_results = compile_and_simulate("WS", m, k, n, working)
            for case in (0, 1):
                expected = expected_matrix(m, k, n, case)
                os_matrix = os_results[case]
                ws_matrix = ws_results[case]
                if os_matrix != expected or ws_matrix != expected:
                    raise AssertionError(
                        "M={} K={} N={} case={}\nExpected: {}\nOS: {}\nWS: {}".format(
                            m, k, n, case, expected, os_matrix, ws_matrix))
                total += 1
                print("PASS M={} K={} N={} case={} | OS == WS == Python".format(
                    m, k, n, case))

    print("\n{} GEMM workloads; {} OS and {} WS results verified".format(
        total, total, total))
    print("ALL PARAMETERIZED OS/WS REGRESSION TESTS PASSED")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, AssertionError, OSError) as exc:
        print("REGRESSION FAILED: {}".format(exc), file=sys.stderr)
        sys.exit(1)
