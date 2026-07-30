"""Floating-point algorithm model for x = W @ s."""

from __future__ import annotations

import numpy as np


def validate_shapes(matrix: np.ndarray, symbols: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    matrix = np.asarray(matrix, dtype=np.complex128)
    symbols = np.asarray(symbols, dtype=np.complex128)
    if matrix.ndim != 2 or symbols.ndim != 1:
        raise ValueError("matrix must be 2-D and symbols must be 1-D")
    if matrix.shape[1] != symbols.shape[0]:
        raise ValueError("matrix column count must match symbol count")
    if not np.all(np.isfinite(matrix)) or not np.all(np.isfinite(symbols)):
        raise ValueError("matrix and symbols must contain finite values")
    return matrix, symbols


def precoder_float(matrix: np.ndarray, symbols: np.ndarray) -> np.ndarray:
    """Return the complex floating-point matrix-vector product."""
    matrix, symbols = validate_shapes(matrix, symbols)
    return matrix @ symbols


def evm(reference: np.ndarray, measured: np.ndarray) -> float:
    """Return RMS error-vector magnitude as a linear ratio."""
    reference = np.asarray(reference, dtype=np.complex128)
    measured = np.asarray(measured, dtype=np.complex128)
    if reference.shape != measured.shape:
        raise ValueError("reference and measured shapes must match")
    error_energy = float(np.sum(np.abs(measured - reference) ** 2))
    reference_energy = float(np.sum(np.abs(reference) ** 2))
    if reference_energy == 0.0:
        return 0.0 if error_energy == 0.0 else float("inf")
    return float(np.sqrt(error_energy / reference_energy))


if __name__ == "__main__":
    w = np.eye(4, dtype=np.complex128)
    s = np.array([1 + 0j, 0.5 - 0.25j, -1 + 0.5j, 0 + 1j])
    print(precoder_float(w, s))

