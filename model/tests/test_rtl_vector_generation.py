import tempfile
import unittest
from pathlib import Path

from scripts.generate_rtl_vectors import generate_all


class RtlVectorGenerationTests(unittest.TestCase):
    def test_all_vector_files_are_deterministic_and_nonempty(self):
        with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
            first = Path(first_dir)
            second = Path(second_dir)
            first_counts = generate_all(first, 8, 99)
            second_counts = generate_all(second, 8, 99)
            self.assertEqual(first_counts, second_counts)

            for filename in ("complex_mult.txt", "complex_mac.txt", "fixed_round_sat.txt"):
                first_content = (first / filename).read_text(encoding="ascii")
                second_content = (second / filename).read_text(encoding="ascii")
                self.assertTrue(first_content)
                self.assertEqual(first_content, second_content)


if __name__ == "__main__":
    unittest.main()

