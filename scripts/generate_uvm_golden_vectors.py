"""Generate deterministic NumPy golden vectors for the stage-12 UVM test."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any

import numpy as np

from model.fixed_model import ComplexInt, precoder_fixed_int
from model.numeric_analysis import evaluate_q14_batch, quantize_array


FORMAT_VERSION = 1
QAM_ORDERS = (4, 16, 64)


def qam_constellation(order: int) -> np.ndarray:
    side = int(math.isqrt(order))
    if side * side != order:
        raise ValueError("QAM order must be a positive square")
    levels = np.arange(-(side - 1), side, 2, dtype=np.float64)
    points = (levels[:, None] + 1j * levels[None, :]).reshape(-1)
    return points / np.sqrt(np.mean(np.abs(points) ** 2))


def normalized_matrix(rng: np.random.Generator) -> np.ndarray:
    matrix = rng.normal(size=(4, 4)) + 1j * rng.normal(size=(4, 4))
    return 0.9 * matrix / np.linalg.norm(matrix)


def _matrix_line(bank: int, real: np.ndarray, imag: np.ndarray) -> str:
    fields = ["BANK", str(bank)]
    for row in range(4):
        for col in range(4):
            fields.extend((str(int(real[row, col])), str(int(imag[row, col]))))
    return " ".join(fields)


def _cross_check_scalar_model(
    matrix_real: np.ndarray,
    matrix_imag: np.ndarray,
    symbol_real: np.ndarray,
    symbol_imag: np.ndarray,
    output_real: np.ndarray,
    output_imag: np.ndarray,
) -> None:
    matrix = [
        [
            ComplexInt(int(matrix_real[row, col]), int(matrix_imag[row, col]))
            for col in range(4)
        ]
        for row in range(4)
    ]
    symbols = [
        ComplexInt(int(symbol_real[col]), int(symbol_imag[col]))
        for col in range(4)
    ]
    scalar_outputs = precoder_fixed_int(matrix, symbols)
    for row, scalar in enumerate(scalar_outputs):
        if scalar.real != int(output_real[row]) or scalar.imag != int(output_imag[row]):
            raise AssertionError(
                f"vectorized/scalar model mismatch on row {row}: "
                f"{int(output_real[row])}+{int(output_imag[row])}j versus "
                f"{scalar.real}+{scalar.imag}j"
            )


def generate_dataset(
    block_count: int = 20,
    vectors_per_block: int = 50,
    base_seed: int = 20260808,
) -> tuple[str, dict[str, Any]]:
    if block_count < 1:
        raise ValueError("block_count must be positive")
    if vectors_per_block < 2:
        raise ValueError("vectors_per_block must be at least two")

    lines = [
        f"STAGE12 {FORMAT_VERSION} {block_count} {vectors_per_block} {base_seed}"
    ]
    block_records: list[dict[str, Any]] = []
    qam_vector_counts = {str(order): 0 for order in QAM_ORDERS}
    total_saturated_outputs = 0

    for block_index in range(block_count):
        data_seed = base_seed + block_index
        qam_order = QAM_ORDERS[block_index % len(QAM_ORDERS)]
        bank1_version = 1 + ((64 + 37 * block_index) % 255)
        switch_index = vectors_per_block // 2
        rng = np.random.default_rng(data_seed)

        floating_matrices = np.stack((normalized_matrix(rng), normalized_matrix(rng)))
        matrix_real = quantize_array(floating_matrices.real)
        matrix_imag = quantize_array(floating_matrices.imag)
        constellation = qam_constellation(qam_order)
        floating_symbols = constellation[
            rng.integers(0, len(constellation), size=(vectors_per_block, 4))
        ]
        symbol_real = quantize_array(floating_symbols.real)
        symbol_imag = quantize_array(floating_symbols.imag)
        selected_bank = np.arange(vectors_per_block) >= switch_index
        matrix_real_batch = matrix_real[selected_bank.astype(np.int64)]
        matrix_imag_batch = matrix_imag[selected_bank.astype(np.int64)]
        floating_matrix_batch = floating_matrices[selected_bank.astype(np.int64)]

        analysis = evaluate_q14_batch(
            matrix_real_batch,
            matrix_imag_batch,
            symbol_real,
            symbol_imag,
            original_matrix=floating_matrix_batch,
            original_symbols=floating_symbols,
        )

        lines.append(
            f"BLOCK {block_index} {data_seed} {qam_order} "
            f"{bank1_version} {switch_index}"
        )
        lines.append(_matrix_line(0, matrix_real[0], matrix_imag[0]))
        lines.append(_matrix_line(1, matrix_real[1], matrix_imag[1]))

        for vector_index in range(vectors_per_block):
            bank = int(selected_bank[vector_index])
            version = bank1_version if bank else 0
            output_real = analysis["output_real"][vector_index]
            output_imag = analysis["output_imag"][vector_index]
            saturation = analysis["saturation_mask"][vector_index]
            _cross_check_scalar_model(
                matrix_real[bank],
                matrix_imag[bank],
                symbol_real[vector_index],
                symbol_imag[vector_index],
                output_real,
                output_imag,
            )

            fields = ["VECTOR", str(vector_index), str(bank), str(version)]
            for column in range(4):
                fields.extend(
                    (
                        str(int(symbol_real[vector_index, column])),
                        str(int(symbol_imag[vector_index, column])),
                    )
                )
            for row in range(4):
                fields.extend(
                    (
                        str(int(output_real[row])),
                        str(int(output_imag[row])),
                        str(int(saturation[row])),
                    )
                )
            fields.extend(
                (
                    f"{float(analysis['implementation_evm'][vector_index]):.17e}",
                    f"{float(analysis['end_to_end_evm'][vector_index]):.17e}",
                )
            )
            lines.append(" ".join(fields))

        lines.append("END_BLOCK")
        saturated_outputs = int(np.sum(analysis["saturation_mask"]))
        total_saturated_outputs += saturated_outputs
        qam_vector_counts[str(qam_order)] += vectors_per_block
        block_records.append(
            {
                "block_index": block_index,
                "data_seed": data_seed,
                "qam_order": qam_order,
                "vectors": vectors_per_block,
                "switch_index": switch_index,
                "bank1_version": bank1_version,
                "saturated_outputs": saturated_outputs,
                "implementation_evm_max": float(np.max(analysis["implementation_evm"])),
                "end_to_end_evm_max": float(np.max(analysis["end_to_end_evm"])),
            }
        )

    lines.append("END_STAGE12")
    text = "\n".join(lines) + "\n"
    manifest: dict[str, Any] = {
        "format_version": FORMAT_VERSION,
        "base_seed": base_seed,
        "block_count": block_count,
        "vectors_per_block": vectors_per_block,
        "total_vectors": block_count * vectors_per_block,
        "qam_vector_counts": qam_vector_counts,
        "matrix_frobenius_norm": 0.9,
        "total_saturated_outputs": total_saturated_outputs,
        "golden_sha256": hashlib.sha256(text.encode("ascii")).hexdigest(),
        "numpy_version": np.__version__,
        "blocks": block_records,
    }
    return text, manifest


def write_dataset(
    output: Path,
    manifest_path: Path,
    block_count: int = 20,
    vectors_per_block: int = 50,
    base_seed: int = 20260808,
) -> dict[str, Any]:
    text, manifest = generate_dataset(block_count, vectors_per_block, base_seed)
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="ascii", newline="\n")
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--blocks", type=int, default=20)
    parser.add_argument("--vectors-per-block", type=int, default=50)
    parser.add_argument("--seed", type=int, default=20260808)
    parser.add_argument(
        "--output", type=Path, default=Path("tb/vectors/stage12_golden_vectors.txt")
    )
    parser.add_argument(
        "--manifest", type=Path, default=Path("tb/vectors/stage12_manifest.json")
    )
    args = parser.parse_args()
    manifest = write_dataset(
        args.output,
        args.manifest,
        args.blocks,
        args.vectors_per_block,
        args.seed,
    )
    print(
        f"wrote {manifest['total_vectors']} vectors in {manifest['block_count']} blocks "
        f"to {args.output}"
    )
    print(f"manifest: {args.manifest}")
    print(f"sha256: {manifest['golden_sha256']}")


if __name__ == "__main__":
    main()
