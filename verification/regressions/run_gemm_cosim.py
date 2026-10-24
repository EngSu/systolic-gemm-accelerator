#!/usr/bin/env python3
"""Compare OS and WS 2x2 RTL against the independent Python GEMM model.

Run from the repository root:
    /usr/bin/python3 verification/regressions/run_gemm_cosim.py
"""

import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from verification.reference_models.gemm_reference import gemm

SEED = 20261024
RANDOM_CASES = 25

# A and B are each 2x2. Each case is a pair (A, B).
CASES = [
    ([[1, 2], [3, 4]], [[5, 6], [7, 8]]),
    ([[-2, 5], [6, -1]], [[-1, 2], [3, -4]]),
    ([[0, 0], [0, 0]], [[0, 0], [0, 0]]),
    ([[32767, 32767], [32767, 32767]], [[32767, 32767], [32767, 32767]]),
    ([[-32768, -32768], [-32768, -32768]], [[-32768, -32768], [-32768, -32768]]),
    ([[32767, -32768], [-1, 0]], [[-32768, 32767], [1, -1]]),
]
rng = random.Random(SEED)
for _ in range(RANDOM_CASES):
    A = [[rng.randint(-32768, 32767) for _ in range(2)] for _ in range(2)]
    B = [[rng.randint(-32768, 32767) for _ in range(2)] for _ in range(2)]
    CASES.append((A, B))

TB = r'''`timescale 1ns/1ps
module gemm_cosim_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg clear_acc = 0;
    reg load_weights = 0;

    reg signed [15:0] a_row0 = 0, a_row1 = 0;
    reg signed [15:0] b_col0 = 0, b_col1 = 0;
    reg a_valid0 = 0, a_valid1 = 0, b_valid0 = 0, b_valid1 = 0;
    wire signed [31:0] c00, c01, c10, c11;

    reg signed [15:0] w00 = 0, w01 = 0, w10 = 0, w11 = 0;
    reg signed [15:0] act0 = 0, act1 = 0;
    reg v0 = 0, v1 = 0;
    wire signed [31:0] ws_col0, ws_col1;
    wire ws_valid0, ws_valid1;

    systolic_array_os_2x2 os_dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_row0(a_row0), .a_row1(a_row1),
        .a_valid0(a_valid0), .a_valid1(a_valid1),
        .b_col0(b_col0), .b_col1(b_col1),
        .b_valid0(b_valid0), .b_valid1(b_valid1),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    ws_array_2x2 ws_dut (
        .clk(clk), .rst_n(rst_n), .load_weights(load_weights),
        .b00(w00), .b01(w01), .b10(w10), .b11(w11),
        .a_k0_in(act0), .a_k1_in(act1),
        .a_k0_valid(v0), .a_k1_valid(v1),
        .c_col0(ws_col0), .c_col1(ws_col1),
        .c_col0_valid(ws_valid0), .c_col1_valid(ws_valid1)
    );

    task run_case;
        input integer id;
        input signed [15:0] a00, a01, a10, a11;
        input signed [15:0] b00, b01, b10, b11;
        begin
            // Reset both implementations between independent matrix cases.
            @(negedge clk);
            rst_n = 0;
            load_weights = 0;
            clear_acc = 0;
            a_valid0 = 0; a_valid1 = 0;
            b_valid0 = 0; b_valid1 = 0;
            v0 = 0; v1 = 0;
            @(posedge clk); #1;

            // Preload the WS weights before either array processes inputs.
            @(negedge clk);
            rst_n = 1;
            load_weights = 1;
            w00 = b00; w01 = b01;
            w10 = b10; w11 = b11;
            @(posedge clk); #1;

            // E0: launch A row 0 / first contribution.
            @(negedge clk);
            load_weights = 0;
            a_row0 = a00; a_row1 = 0;
            b_col0 = b00; b_col1 = 0;
            a_valid0 = 1; a_valid1 = 0;
            b_valid0 = 1; b_valid1 = 0;
            act0 = a00; act1 = 0;
            v0 = 1; v1 = 0;
            @(posedge clk); #1;
            if (ws_valid0 !== 0 || ws_valid1 !== 0)
                $fatal(1, "Case %0d: WS valid too early at E0", id);

            // E1: WS finishes row 0 and begins row 1.
            @(negedge clk);
            a_row0 = a01; a_row1 = a10;
            b_col0 = b10; b_col1 = b01;
            a_valid0 = 1; a_valid1 = 1;
            b_valid0 = 1; b_valid1 = 1;
            act0 = a10; act1 = a01;
            v0 = 1; v1 = 1;
            @(posedge clk); #1;
            if (ws_valid0 !== 1 || ws_valid1 !== 1)
                $fatal(1, "Case %0d: WS row 0 missing at E1", id);
            $display("CASE %0d WS_ROW0 %0d %0d", id, ws_col0, ws_col1);

            // E2: WS finishes row 1; OS continues accumulating.
            @(negedge clk);
            a_row0 = 0; a_row1 = a11;
            b_col0 = 0; b_col1 = b11;
            a_valid0 = 0; a_valid1 = 1;
            b_valid0 = 0; b_valid1 = 1;
            act0 = 0; act1 = a11;
            v0 = 0; v1 = 1;
            @(posedge clk); #1;
            if (ws_valid0 !== 1 || ws_valid1 !== 1)
                $fatal(1, "Case %0d: WS row 1 missing at E2", id);
            $display("CASE %0d WS_ROW1 %0d %0d", id, ws_col0, ws_col1);

            // E3: OS finishes its bottom-right accumulator.
            @(negedge clk);
            a_row0 = 0; a_row1 = 0;
            b_col0 = 0; b_col1 = 0;
            a_valid0 = 0; a_valid1 = 0;
            b_valid0 = 0; b_valid1 = 0;
            v0 = 0; v1 = 0;
            @(posedge clk); #1;
            if (ws_valid0 !== 0 || ws_valid1 !== 0)
                $fatal(1, "Case %0d: WS valid unexpectedly high at E3", id);
            $display("CASE %0d OS %0d %0d %0d %0d", id, c00, c01, c10, c11);
        end
    endtask

    initial begin
/*CASES*/
        $finish;
    end
endmodule
'''


def verilog_call(index, A, B):
    values = [A[0][0], A[0][1], A[1][0], A[1][1],
              B[0][0], B[0][1], B[1][0], B[1][1]]
    return '        run_case({}, {});'.format(index, ', '.join(map(str, values)))


def main():
    if shutil.which('iverilog') is None or shutil.which('vvp') is None:
        sys.exit('ERROR: iverilog and vvp must be installed and on PATH')

    sources = [
        'rtl/pe/pe_os.v',
        'rtl/pe/pe_ws.v',
        'rtl/array/os/systolic_array_os_2x2.v',
        'rtl/array/ws/ws_chain_2.v',
        'rtl/array/ws/ws_array_2x2.v',
    ]
    for source in sources:
        if not (ROOT / source).is_file():
            sys.exit('ERROR: missing RTL source: ' + source)

    calls = '\n'.join(verilog_call(i, A, B) for i, (A, B) in enumerate(CASES))
    with tempfile.TemporaryDirectory(prefix='gemm_cosim_') as temp:
        tb_path = Path(temp) / 'gemm_cosim_tb.v'
        output_path = Path(temp) / 'gemm_cosim.vvp'
        tb_path.write_text(TB.replace('/*CASES*/', calls), encoding='utf-8')

        compile_cmd = [
            'iverilog', '-g2012', '-s', 'gemm_cosim_tb',
            '-o', str(output_path),
        ] + [str(ROOT / s) for s in sources] + [str(tb_path)]
        subprocess.run(compile_cmd, cwd=ROOT, check=True)
        completed = subprocess.run(
            ['vvp', str(output_path)], cwd=ROOT,
            check=True, capture_output=True, text=True,
        )

    results = {}
    pattern = re.compile(r'^CASE (\d+) (WS_ROW0|WS_ROW1|OS) ((?:-?\d+\s*)+)$')
    for line in completed.stdout.splitlines():
        match = pattern.fullmatch(line.strip())
        if match:
            idx, kind, values = match.groups()
            key = (int(idx), kind)
            if key in results:
                sys.exit('ERROR: duplicate RTL result: {}'.format(key))
            results[key] = [int(x) for x in values.split()]

    failures = 0
    for idx, (A, B) in enumerate(CASES):
        expected = gemm(A, B, data_width=16, acc_width=32)
        checks = {
            'WS_ROW0': expected[0],
            'WS_ROW1': expected[1],
            'OS': expected[0] + expected[1],
        }
        case_ok = all(results.get((idx, kind)) == value
                      for kind, value in checks.items())
        if case_ok:
            print('PASS case {:02d}: {}'.format(idx, expected))
        else:
            failures += 1
            print('FAIL case {:02d}: A={} B={} expected={}'.format(idx, A, B, expected))
            for kind, value in checks.items():
                print('  {}: got {}, expected {}'.format(
                    kind, results.get((idx, kind)), value))

    print('\n{} matrices, seed {}, {} failures'.format(len(CASES), SEED, failures))
    if failures:
        sys.exit(1)
    print('ALL OS/WS GEMM COSIM TESTS PASSED')


if __name__ == '__main__':
    main()
