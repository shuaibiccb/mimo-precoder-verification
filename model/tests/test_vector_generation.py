import unittest

from model.generate_vectors import generate_cases


class VectorGenerationTests(unittest.TestCase):
    def test_seed_is_reproducible(self):
        self.assertEqual(generate_cases(2, 1234), generate_cases(2, 1234))

    def test_rtl_fields_exist(self):
        case = generate_cases(1, 7)[0]
        self.assertEqual(len(case["matrix"]), 4)
        self.assertEqual(len(case["symbols"]), 4)
        self.assertEqual(len(case["expected"]), 4)
        self.assertRegex(case["expected"][0]["hex"]["real"], r"^[0-9A-F]{4}$")


if __name__ == "__main__":
    unittest.main()

