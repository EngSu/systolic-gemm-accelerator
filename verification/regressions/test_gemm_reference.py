
import unittest

from verification.reference_models.gemm_reference import (
    gemm,
    wrap_signed,
)


class TestGemmReference(unittest.TestCase):

    def test_positive_matrices(self):
        A = [[1, 2], [3, 4]]
        B = [[5, 6], [7, 8]]

        self.assertEqual(
            gemm(A, B),
            [[19, 22], [43, 50]]
        )

    def test_signed_matrices(self):
        A = [[-2, 5], [6, -1]]
        B = [[-1, 2], [3, -4]]

        self.assertEqual(
            gemm(A, B),
            [[17, -24], [-9, 16]]
        )

    def test_rectangular_matrices(self):
        A = [[1, 2, 3]]
        B = [[4, 5], [6, 7], [8, 9]]

        self.assertEqual(
            gemm(A, B),
            [[40, 46]]
        )

    def test_accumulator_overflow(self):
        A = [[127, 127, 127]]
        B = [[127], [127], [127]]

        self.assertEqual(
            gemm(A, B, data_width=8, acc_width=16),
            [[-17149]]
        )

    def test_signed_wrapping(self):
        self.assertEqual(wrap_signed(65535, 16), -1)
        self.assertEqual(wrap_signed(32768, 16), -32768)

    def test_incompatible_dimensions(self):
        A = [[1, 2]]
        B = [[3, 4]]

        with self.assertRaises(ValueError):
            gemm(A, B)


if __name__ == "__main__":
    unittest.main()

