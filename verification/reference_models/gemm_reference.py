
"""
Signed integer GEMM reference model.

C[M][N] = A[M][K] * B[K][N]

Multiplication is signed.
Accumulator overflow wraps in two's complement.
"""


def wrap_signed(value, width):
    """Wrap an integer to a signed value of the given bit width."""
    mask = (1 << width) - 1
    value &= mask

    if value & (1 << (width - 1)):
        value -= 1 << width

    return value


def gemm(A, B, data_width=16, acc_width=32):
    """Return C = A * B, matching fixed-width RTL arithmetic."""

    if data_width < 1 or acc_width < 2 * data_width:
        raise ValueError("Invalid data or accumulator width")

    if not A or not B or not A[0] or not B[0]:
        raise ValueError("Matrices must be nonempty")

    M = len(A)
    K = len(A[0])
    N = len(B[0])

    if any(len(row) != K for row in A):
        raise ValueError("Matrix A is not rectangular")

    if any(len(row) != N for row in B):
        raise ValueError("Matrix B is not rectangular")

    if len(B) != K:
        raise ValueError("Incompatible matrix dimensions")

    minimum = -(1 << (data_width - 1))
    maximum = (1 << (data_width - 1)) - 1

    for matrix in (A, B):
        for row in matrix:
            for value in row:
                if not isinstance(value, int):
                    raise ValueError("Matrix elements must be integers")
                if not minimum <= value <= maximum:
                    raise ValueError("Matrix element exceeds data width")

    C = [[0 for _ in range(N)] for _ in range(M)]

    for i in range(M):
        for j in range(N):
            accumulator = 0

            for k in range(K):
                product = A[i][k] * B[k][j]

                accumulator = wrap_signed(
                    accumulator + product,
                    acc_width
                )

            C[i][j] = accumulator

    return C


if __name__ == "__main__":

    A = [[1, 2],
         [3, 4]]

    B = [[5, 6],
         [7, 8]]

    print("Matrix test 1:", gemm(A, B))

    A = [[-2, 5],
         [6, -1]]

    B = [[-1, 2],
         [3, -4]]

    print("Matrix test 2:", gemm(A, B))

