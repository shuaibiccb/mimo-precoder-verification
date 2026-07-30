import unittest

import numpy as np

from model.floating_model import evm, precoder_float


class FloatingModelTests(unittest.TestCase):
    def test_identity(self):
        symbols = np.array([1 + 2j, -0.5j, -1 + 0j, 0.25 - 0.75j])
        np.testing.assert_allclose(precoder_float(np.eye(4), symbols), symbols)

    def test_hand_calculated(self):
        matrix = np.array([[1 + 1j, 2 - 1j], [0.5 + 0j, 0 + 1j]])
        symbols = np.array([1 - 1j, 2 + 0.5j])
        np.testing.assert_allclose(precoder_float(matrix, symbols), matrix @ symbols)

    def test_shape_error(self):
        with self.assertRaises(ValueError):
            precoder_float(np.eye(4), np.ones(3))

    def test_evm(self):
        reference = np.array([1 + 0j, 0 + 1j])
        self.assertAlmostEqual(evm(reference, reference), 0.0)
        self.assertAlmostEqual(evm(reference, np.zeros(2)), 1.0)


if __name__ == "__main__":
    unittest.main()

