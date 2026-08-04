"""Generate deterministic golden vectors for phase-2 RTL unit tests."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from model.fixed_model import (
    ACC_WIDTH,
    ComplexInt,
    complex_multiply,
    precoder_fixed_int,
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


def output_saturated(matrix: list[list[ComplexInt]], symbols: list[ComplexInt], row: int) -> int:
    acc_real = 0
    acc_imag = 0
    for coefficient, symbol in zip(matrix[row], symbols):
        product = complex_multiply(coefficient, symbol)
        acc_real += product.real
        acc_imag += product.imag

    half = 1 << 13
    rounded_real = (abs(acc_real) + half) >> 14
    rounded_imag = (abs(acc_imag) + half) >> 14
    if acc_real < 0:
        rounded_real = -rounded_real
    if acc_imag < 0:
        rounded_imag = -rounded_imag
    return int(not (-32768 <= rounded_real <= 32767)
               or not (-32768 <= rounded_imag <= 32767))


def write_precoder_core(path: Path, count: int, seed: int) -> int:
    zero = ComplexInt(0, 0)
    one = ComplexInt(16384, 0)
    half = ComplexInt(8192, 0)
    neg_one = ComplexInt(-16384, 0)
    imag_one = ComplexInt(0, 16384)

    identity = [[one if row == col else zero for col in range(4)] for row in range(4)]
    zero_matrix = [[zero for _ in range(4)] for _ in range(4)]
    diagonal_values = [one, half, neg_one, imag_one]
    diagonal = [[diagonal_values[row] if row == col else zero for col in range(4)]
                for row in range(4)]
    single = [[zero for _ in range(4)] for _ in range(4)]
    single[2][1] = ComplexInt(12288, -4096)
    all_one = [[one for _ in range(4)] for _ in range(4)]
    directed_symbols = [
        ComplexInt(4096, -2048),
        ComplexInt(-8192, 6144),
        ComplexInt(12288, 4096),
        ComplexInt(-2048, -10240),
    ]
    saturation_symbols = [ComplexInt(32767, 32767) for _ in range(4)]
    cases: list[tuple[list[list[ComplexInt]], list[ComplexInt]]] = [
        (zero_matrix, directed_symbols),
        (identity, directed_symbols),
        (diagonal, directed_symbols),
        (single, directed_symbols),
        (all_one, saturation_symbols),
    ]

    rng = np.random.default_rng(seed)
    for _ in range(count):
        matrix_values = random_signed(rng, 16, 32).reshape(4, 4, 2)
        symbol_values = random_signed(rng, 16, 8).reshape(4, 2)
        matrix = [[ComplexInt(int(matrix_values[row, col, 0]),
                              int(matrix_values[row, col, 1]))
                   for col in range(4)] for row in range(4)]
        symbols = [ComplexInt(int(symbol_values[idx, 0]), int(symbol_values[idx, 1]))
                   for idx in range(4)]
        cases.append((matrix, symbols))

    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write(f"{len(cases)}\n")
        for case_id, (matrix, symbols) in enumerate(cases):
            expected = precoder_fixed_int(matrix, symbols)
            handle.write(f"{case_id}\n")
            for row in matrix:
                for value in row:
                    handle.write(f"{value.real} {value.imag}\n")
            for value in symbols:
                handle.write(f"{value.real} {value.imag}\n")
            for row, value in enumerate(expected):
                handle.write(f"{value.real} {value.imag} "
                             f"{output_saturated(matrix, symbols, row)}\n")
    return len(cases)


def generate_all(output_dir: Path, random_count: int, seed: int) -> dict[str, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    return {
        "complex_mult": write_complex_mult(output_dir / "complex_mult.txt", random_count, seed),
        "complex_mac": write_complex_mac(output_dir / "complex_mac.txt", max(1, random_count // 4), seed + 1),
        "fixed_round_sat": write_round_sat(output_dir / "fixed_round_sat.txt", random_count, seed + 2),
        "precoder_core": write_precoder_core(output_dir / "precoder_core.txt", random_count, seed + 3),
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
