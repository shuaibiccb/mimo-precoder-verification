"""Generate deterministic golden vectors for phase-2 RTL unit tests."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from model.fixed_model import (
    ACC_WIDTH,
    ComplexInt,
    complex_multiply,
    requantize_accumulator,
    signed_limits,
)


def random_signed(rng: np.random.Generator, width: int, count: int) -> np.ndarray:
    low, high = signed_limits(width)
    return rng.integers(low, high + 1, size=count, dtype=np.int64)


def write_complex_mult(path: Path, count: int, seed: int) -> int:
    corners = [
        (0, 0, 0, 0),
        (16384, 0, 16384, 0),
        (-16384, 0, 16384, 0),
        (0, 16384, 0, 16384),
        (16384, 16384, 16384, -16384),
        (32767, 32767, 32767, 32767),
        (-32768, -32768, -32768, -32768),
        (-32768, 32767, 32767, -32768),
    ]
    rng = np.random.default_rng(seed)
    random_values = random_signed(rng, 16, count * 4).reshape(count, 4)
    cases = corners + [tuple(int(v) for v in row) for row in random_values]

    with path.open("w", encoding="ascii", newline="\n") as handle:
        for ar, ai, br, bi in cases:
            product = complex_multiply(ComplexInt(ar, ai), ComplexInt(br, bi))
            handle.write(f"{ar} {ai} {br} {bi} {product.real} {product.imag}\n")
    return len(cases)


def write_complex_mac(path: Path, groups: int, seed: int) -> int:
    rng = np.random.default_rng(seed)
    rows: list[tuple[int, int, int, int, int, int, int, int]] = []
    acc_real = 0
    acc_imag = 0

    # clear has priority over enable, and disabled cycles hold the accumulator.
    rows.append((1, 1, 16384, 0, 16384, 0, 0, 0))
    product = complex_multiply(ComplexInt(16384, 0), ComplexInt(16384, 0))
    acc_real += product.real
    acc_imag += product.imag
    rows.append((0, 1, 16384, 0, 16384, 0, acc_real, acc_imag))
    rows.append((0, 0, -32768, 32767, 32767, -32768, acc_real, acc_imag))
    rows.append((1, 1, -32768, -32768, -32768, -32768, 0, 0))

    for _ in range(groups):
        rows.append((1, 0, 0, 0, 0, 0, 0, 0))
        acc_real = 0
        acc_imag = 0
        values = random_signed(rng, 16, 16).reshape(4, 4)
        for ar, ai, br, bi in values:
            product = complex_multiply(
                ComplexInt(int(ar), int(ai)), ComplexInt(int(br), int(bi))
            )
            acc_real += product.real
            acc_imag += product.imag
            rows.append((0, 1, int(ar), int(ai), int(br), int(bi), acc_real, acc_imag))
        rows.append((0, 0, 0, 0, 0, 0, acc_real, acc_imag))

    with path.open("w", encoding="ascii", newline="\n") as handle:
        for row in rows:
            handle.write(" ".join(str(value) for value in row) + "\n")
    return len(rows)


def write_round_sat(path: Path, count: int, seed: int) -> int:
    half = 1 << 13
    corners = [
        0,
        1,
        half - 1,
        half,
        half + 1,
        -1,
        -(half - 1),
        -half,
        -(half + 1),
        32767 << 14,
        (32767 << 14) + half - 1,
        (32767 << 14) + half,
        32768 << 14,
        -32768 << 14,
        (-32768 << 14) - half,
        -40000 << 14,
        40000 << 14,
        -(1 << (ACC_WIDTH - 1)),
        (1 << (ACC_WIDTH - 1)) - 1,
    ]
    rng = np.random.default_rng(seed)
    random_values = random_signed(rng, ACC_WIDTH, count)
    cases = corners + [int(value) for value in random_values]

    with path.open("w", encoding="ascii", newline="\n") as handle:
        for accumulator in cases:
            expected = requantize_accumulator(accumulator)
            saturated = int(expected in (-32768, 32767) and
                            not (-32768 <= (accumulator / (1 << 14)) <= 32767))
            # Exact half values beyond the limit also saturate; derive from rounded value.
            rounded_unbounded = ((abs(accumulator) + half) >> 14)
            if accumulator < 0:
                rounded_unbounded = -rounded_unbounded
            saturated = int(rounded_unbounded > 32767 or rounded_unbounded < -32768)
            handle.write(f"{accumulator} {expected} {saturated}\n")
    return len(cases)


def generate_all(output_dir: Path, random_count: int, seed: int) -> dict[str, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    return {
        "complex_mult": write_complex_mult(output_dir / "complex_mult.txt", random_count, seed),
        "complex_mac": write_complex_mac(output_dir / "complex_mac.txt", max(1, random_count // 4), seed + 1),
        "fixed_round_sat": write_round_sat(output_dir / "fixed_round_sat.txt", random_count, seed + 2),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("build/rtl_vectors"))
    parser.add_argument("--random-count", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=20260803)
    args = parser.parse_args()
    if args.random_count < 1:
        parser.error("--random-count must be positive")
    counts = generate_all(args.output_dir, args.random_count, args.seed)
    for name, count in counts.items():
        print(f"{name}: generated {count} vectors")


if __name__ == "__main__":
    main()

