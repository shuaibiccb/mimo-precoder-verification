"""Generate deterministic, RTL-ready 4x4 precoder vectors."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from .fixed_model import ComplexInt, complex_hex, precoder_fixed, quantize_complex
from .floating_model import evm, precoder_float


def encode_value(value: ComplexInt) -> dict[str, object]:
    return {
        "real_int": value.real,
        "imag_int": value.imag,
        "hex": complex_hex(value),
    }


def generate_cases(count: int, seed: int) -> list[dict[str, object]]:
    if count < 1:
        raise ValueError("count must be positive")
    rng = np.random.default_rng(seed)
    cases: list[dict[str, object]] = []
    for case_id in range(count):
        matrix = rng.uniform(-1.0, 1.0, (4, 4)) + 1j * rng.uniform(-1.0, 1.0, (4, 4))
        symbols = rng.uniform(-1.0, 1.0, 4) + 1j * rng.uniform(-1.0, 1.0, 4)
        floating = precoder_float(matrix, symbols)
        fixed_values, fixed_ints = precoder_fixed(matrix, symbols)
        q_matrix = [[quantize_complex(matrix[i, j]) for j in range(4)] for i in range(4)]
        q_symbols = [quantize_complex(value) for value in symbols]
        cases.append({
            "case_id": case_id,
            "matrix": [[encode_value(value) for value in row] for row in q_matrix],
            "symbols": [encode_value(value) for value in q_symbols],
            "expected": [encode_value(value) for value in fixed_ints],
            "floating_output": [[float(value.real), float(value.imag)] for value in floating],
            "fixed_output": [[float(value.real), float(value.imag)] for value in fixed_values],
            "evm": evm(floating, fixed_values),
        })
    return cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260730)
    parser.add_argument("--output", type=Path, default=Path("build/vectors.json"))
    args = parser.parse_args()
    payload = {"format_version": 1, "seed": args.seed, "cases": generate_cases(args.count, args.seed)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"wrote {len(payload['cases'])} cases to {args.output}")


if __name__ == "__main__":
    main()

