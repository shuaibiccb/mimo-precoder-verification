"""Bit-accurate signed fixed-point model for the MIMO precoder."""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Iterable, Sequence

import numpy as np

DATA_WIDTH = 16
DATA_FRAC = 14
ACC_WIDTH = 40
PRODUCT_FRAC = DATA_FRAC * 2


class FixedPointOverflow(OverflowError):
    """Raised when an internal checked fixed-point value exceeds its width."""


@dataclass(frozen=True)
class ComplexInt:
    real: int
    imag: int


def signed_limits(width: int) -> tuple[int, int]:
    if width < 1:
        raise ValueError("width must be positive")
    return -(1 << (width - 1)), (1 << (width - 1)) - 1


def check_signed(value: int, width: int, label: str = "value") -> int:
    low, high = signed_limits(width)
    if not low <= int(value) <= high:
        raise FixedPointOverflow(f"{label}={value} does not fit signed {width} bits")
    return int(value)


def saturate_signed(value: int, width: int) -> int:
    low, high = signed_limits(width)
    return min(max(int(value), low), high)


def round_shift_away_from_zero(value: int, shift: int) -> int:
    """Divide by 2**shift, nearest rounding, exact halves away from zero."""
    if shift < 0:
        return int(value) << -shift
    if shift == 0:
        return int(value)
    magnitude = abs(int(value))
    rounded = (magnitude + (1 << (shift - 1))) >> shift
    return -rounded if value < 0 else rounded


def quantize_scalar(value: float, width: int = DATA_WIDTH, frac: int = DATA_FRAC) -> int:
    if not math.isfinite(float(value)):
        raise ValueError("fixed-point input must be finite")
    scaled = float(value) * (1 << frac)
    magnitude = math.floor(abs(scaled) + 0.5)
    integer = -magnitude if scaled < 0 else magnitude
    return saturate_signed(integer, width)


def dequantize_scalar(value: int, frac: int = DATA_FRAC) -> float:
    return int(value) / float(1 << frac)


def encode_twos(value: int, width: int = DATA_WIDTH) -> int:
    check_signed(value, width)
    return int(value) & ((1 << width) - 1)


def decode_twos(bits: int, width: int = DATA_WIDTH) -> int:
    if bits < 0 or bits >= (1 << width):
        raise ValueError("encoded value does not fit width")
    sign = 1 << (width - 1)
    return bits - (1 << width) if bits & sign else bits


def quantize_complex(value: complex) -> ComplexInt:
    return ComplexInt(quantize_scalar(value.real), quantize_scalar(value.imag))


def dequantize_complex(value: ComplexInt, frac: int = DATA_FRAC) -> complex:
    return complex(dequantize_scalar(value.real, frac), dequantize_scalar(value.imag, frac))


def complex_multiply(a: ComplexInt, b: ComplexInt) -> ComplexInt:
    for label, component in (("a.real", a.real), ("a.imag", a.imag),
                             ("b.real", b.real), ("b.imag", b.imag)):
        check_signed(component, DATA_WIDTH, label)
    real = a.real * b.real - a.imag * b.imag
    imag = a.real * b.imag + a.imag * b.real
    return ComplexInt(check_signed(real, 33, "product.real"),
                      check_signed(imag, 33, "product.imag"))


def requantize_accumulator(value: int) -> int:
    check_signed(value, ACC_WIDTH, "accumulator")
    rounded = round_shift_away_from_zero(value, PRODUCT_FRAC - DATA_FRAC)
    return saturate_signed(rounded, DATA_WIDTH)


def precoder_fixed_int(matrix: Sequence[Sequence[ComplexInt]],
                       symbols: Sequence[ComplexInt]) -> list[ComplexInt]:
    rows = [list(row) for row in matrix]
    symbols = list(symbols)
    if not rows or not symbols or any(len(row) != len(symbols) for row in rows):
        raise ValueError("matrix must be non-empty and rectangular with K columns")

    outputs: list[ComplexInt] = []
    for row_index, row in enumerate(rows):
        acc_real = 0
        acc_imag = 0
        for column_index, (coefficient, symbol) in enumerate(zip(row, symbols)):
            product = complex_multiply(coefficient, symbol)
            acc_real = check_signed(acc_real + product.real, ACC_WIDTH,
                                    f"acc[{row_index}].real after column {column_index}")
            acc_imag = check_signed(acc_imag + product.imag, ACC_WIDTH,
                                    f"acc[{row_index}].imag after column {column_index}")
        outputs.append(ComplexInt(requantize_accumulator(acc_real),
                                  requantize_accumulator(acc_imag)))
    return outputs


def precoder_fixed(matrix: np.ndarray, symbols: np.ndarray) -> tuple[np.ndarray, list[ComplexInt]]:
    matrix = np.asarray(matrix, dtype=np.complex128)
    symbols = np.asarray(symbols, dtype=np.complex128)
    if matrix.ndim != 2 or symbols.ndim != 1 or matrix.shape[1] != symbols.shape[0]:
        raise ValueError("matrix must be 2-D and match the 1-D symbol vector")
    if not np.all(np.isfinite(matrix)) or not np.all(np.isfinite(symbols)):
        raise ValueError("matrix and symbols must contain finite values")

    q_matrix = [[quantize_complex(matrix[i, j]) for j in range(matrix.shape[1])]
                for i in range(matrix.shape[0])]
    q_symbols = [quantize_complex(value) for value in symbols]
    q_outputs = precoder_fixed_int(q_matrix, q_symbols)
    output = np.asarray([dequantize_complex(value) for value in q_outputs], dtype=np.complex128)
    return output, q_outputs


def complex_hex(value: ComplexInt, width: int = DATA_WIDTH) -> dict[str, str]:
    digits = (width + 3) // 4
    return {
        "real": f"{encode_twos(value.real, width):0{digits}X}",
        "imag": f"{encode_twos(value.imag, width):0{digits}X}",
    }


if __name__ == "__main__":
    w = np.eye(4, dtype=np.complex128)
    s = np.array([1 + 0j, 0.5 - 0.25j, -1 + 0.5j, 0 + 1j])
    values, integers = precoder_fixed(w, s)
    print(values)
    print([complex_hex(value) for value in integers])

