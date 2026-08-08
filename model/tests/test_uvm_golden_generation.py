import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.generate_uvm_golden_vectors import generate_dataset, write_dataset


class UvmGoldenGenerationTests(unittest.TestCase):
    def test_dataset_is_deterministic_and_self_describing(self):
        first_text, first_manifest = generate_dataset(3, 4, 99)
        second_text, second_manifest = generate_dataset(3, 4, 99)

        self.assertEqual(first_text, second_text)
        self.assertEqual(first_manifest, second_manifest)
        self.assertTrue(first_text.startswith("STAGE12 1 3 4 99\n"))
        self.assertTrue(first_text.endswith("END_STAGE12\n"))
        self.assertEqual(first_manifest["total_vectors"], 12)
        self.assertEqual(first_manifest["qam_vector_counts"], {"4": 4, "16": 4, "64": 4})
        self.assertEqual(
            first_manifest["golden_sha256"],
            hashlib.sha256(first_text.encode("ascii")).hexdigest(),
        )

    def test_written_manifest_matches_vector_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            vectors = root / "vectors.txt"
            manifest_path = root / "manifest.json"
            manifest = write_dataset(vectors, manifest_path, 2, 3, 1234)
            loaded = json.loads(manifest_path.read_text(encoding="utf-8"))

            self.assertEqual(loaded, manifest)
            self.assertEqual(
                loaded["golden_sha256"],
                hashlib.sha256(vectors.read_bytes()).hexdigest(),
            )
            self.assertEqual(vectors.read_text(encoding="ascii").count("VECTOR "), 6)

    def test_rejects_invalid_dimensions(self):
        with self.assertRaises(ValueError):
            generate_dataset(0, 4, 1)
        with self.assertRaises(ValueError):
            generate_dataset(1, 1, 1)


if __name__ == "__main__":
    unittest.main()
