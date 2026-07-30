import unittest

import numpy as np

from model.fixed_model import (
    ComplexInt, decode_twos, encode_twos, precoder_fixed, precoder_fixed_int,
    quantize_scalar, requantize_accumulator, round_shift_away_from_zero,
    signed_limits,
)


class FixedModelTests(unittest.TestCase):
    def test_limits_and_twos_complement(self):
        self.assertEqual(signed_limits(16), (-32768, 32767))
        for value in (-32768, -1, 0, 1, 32767):
            self.assertEqual(decode_twos(encode_twos(value)), value)

    def test_quantization_and_saturation(self):
        self.assertEqual(quantize_scalar(1.0), 16384)
        self.assertEqual(quantize_scalar(-1.0), -16384)
        self.assertEqual(quantize_scalar(3.0), 32767)
        self.assertEqual(quantize_scalar(-3.0), -32768)

    def test_round_half_away_from_zero(self):
        self.assertEqual(round_shift_away_from_zero(1, 1), 1)
        self.assertEqual(round_shift_away_from_zero(3, 1), 2)
        self.assertEqual(round_shift_away_from_zero(-1, 1), -1)
        self.assertEqual(round_shift_away_from_zero(-3, 1), -2)

    def test_output_saturation(self):
        self.assertEqual(requantize_accumulator(32767 << 14), 32767)
        self.assertEqual(requantize_accumulator(40000 << 14), 32767)
        self.assertEqual(requantize_accumulator(-40000 << 14), -32768)

    def test_complex_multiply_via_one_by_one_precoder(self):
        result = precoder_fixed_int([[ComplexInt(16384, 16384)]], [ComplexInt(16384, -16384)])
        self.assertEqual(result, [ComplexInt(32767, 0)])  # ideal real value 2.0 saturates

    def test_identity_matrix(self):
        matrix = np.eye(4, dtype=np.complex128)
        symbols = np.array([1 + 0j, 0.5 - 0.25j, -1 + 0.5j, 0 + 1j])
        output, integers = precoder_fixed(matrix, symbols)
        np.testing.assert_allclose(output, symbols, atol=1 / 16384)
        self.assertEqual(len(integers), 4)

    def test_randomized_invariants_10000_cases(self):
        rng = np.random.default_rng(20260730)
        for _ in range(10_000):
            matrix = rng.uniform(-1.0, 1.0, (4, 4)) + 1j * rng.uniform(-1.0, 1.0, (4, 4))
            symbols = rng.uniform(-1.0, 1.0, 4) + 1j * rng.uniform(-1.0, 1.0, 4)
            output, integers = precoder_fixed(matrix, symbols)
            self.assertTrue(np.all(np.isfinite(output)))
            for value in integers:
                self.assertGreaterEqual(value.real, -32768)
                self.assertLessEqual(value.real, 32767)
                self.assertGreaterEqual(value.imag, -32768)
                self.assertLessEqual(value.imag, 32767)


if __name__ == "__main__":
    unittest.main()

