import tempfile
import unittest
from pathlib import Path

import numpy as np

from model.fixed_model import round_shift_away_from_zero
from model.numeric_analysis import (
    SearchConfig,
    evaluate_q14_batch,
    round_shift_away_from_zero_array,
    run_worst_case_search,
    write_search_outputs,
)


class NumericAnalysisTests(unittest.TestCase):
    def test_vector_rounding_matches_golden_scalar_rule(self):
        values = np.arange(-40_000, 40_001, 137, dtype=np.int64)
        expected = np.asarray([round_shift_away_from_zero(int(value), 14)
                               for value in values])
        np.testing.assert_array_equal(
            round_shift_away_from_zero_array(values, 14), expected
        )

    def test_identity_has_no_saturation_and_exact_integer_output(self):
        mr = np.zeros((1, 4, 4), dtype=np.int64)
        mi = np.zeros_like(mr)
        mr[0] = np.eye(4, dtype=np.int64) * 16384
        sr = np.asarray([[16384, 8192, -16384, 4096]], dtype=np.int64)
        si = np.asarray([[0, -4096, 8192, 16384]], dtype=np.int64)
        result = evaluate_q14_batch(mr, mi, sr, si)
        np.testing.assert_array_equal(result["output_real"][0], sr[0])
        np.testing.assert_array_equal(result["output_imag"][0], si[0])
        self.assertEqual(int(result["saturated_components"][0]), 0)
        self.assertEqual(int(result["saturated_outputs"][0]), 0)
        self.assertEqual(float(result["implementation_evm"][0]), 0.0)

    def test_full_scale_case_reports_saturation(self):
        mr = np.full((1, 4, 4), 32767, dtype=np.int64)
        mi = np.zeros_like(mr)
        sr = np.full((1, 4), 32767, dtype=np.int64)
        si = np.zeros_like(sr)
        result = evaluate_q14_batch(mr, mi, sr, si)
        self.assertEqual(int(result["saturated_components"][0]), 4)
        self.assertEqual(int(result["saturated_outputs"][0]), 4)
        self.assertTrue(np.all(result["output_real"][0] == 32767))

    def test_search_is_reproducible_and_writes_reports(self):
        config = SearchConfig(samples=40, mutation_samples=10, batch_size=10, seed=77)
        first = run_worst_case_search(config)
        second = run_worst_case_search(config)
        self.assertEqual(first, second)
        self.assertEqual(first["configuration"]["samples"], 40)
        self.assertIn("peak_accumulator", first["worst_cases"])
        with tempfile.TemporaryDirectory() as directory:
            json_path, markdown_path = write_search_outputs(first, Path(directory))
            self.assertTrue(json_path.is_file())
            self.assertTrue(markdown_path.is_file())


if __name__ == "__main__":
    unittest.main()
