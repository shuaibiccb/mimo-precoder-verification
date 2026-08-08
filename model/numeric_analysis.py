"""Vectorized fixed-point quality analysis and feedback-guided worst-case search."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import json
import math
from typing import Any

import numpy as np

from .fixed_model import ACC_WIDTH, DATA_FRAC, DATA_WIDTH


SCALE = 1 << DATA_FRAC
PRODUCT_SCALE = SCALE * SCALE
DATA_MIN = -(1 << (DATA_WIDTH - 1))
DATA_MAX = (1 << (DATA_WIDTH - 1)) - 1
ACC_MAX = (1 << (ACC_WIDTH - 1)) - 1
METRIC_NAMES = (
    "end_to_end_evm",
    "implementation_evm",
    "max_abs_error",
    "peak_accumulator",
    "saturated_outputs",
    "saturated_components",
)


@dataclass(frozen=True)
class SearchConfig:
    samples: int = 100_000
    mutation_samples: int = 20_000
    batch_size: int = 2_000
    seed: int = 20260808

    def validate(self) -> None:
        if self.samples < 5:
            raise ValueError("samples must be at least 5")
        if self.mutation_samples < 0:
            raise ValueError("mutation_samples cannot be negative")
        if self.batch_size < 1:
            raise ValueError("batch_size must be positive")


def round_shift_away_from_zero_array(values: np.ndarray, shift: int) -> np.ndarray:
    """Apply the RTL signed nearest rounding rule to an integer array."""
    values = np.asarray(values, dtype=np.int64)
    if shift < 0:
        return values << -shift
    if shift == 0:
        return values.copy()
    magnitude = np.abs(values)
    rounded = (magnitude + (1 << (shift - 1))) >> shift
    return np.where(values < 0, -rounded, rounded)


def quantize_array(values: np.ndarray) -> np.ndarray:
    """Quantize finite floating-point values to signed Q1.14 integers."""
    values = np.asarray(values, dtype=np.float64)
    if not np.all(np.isfinite(values)):
        raise ValueError("values must be finite")
    scaled = values * SCALE
    rounded = np.floor(np.abs(scaled) + 0.5)
    signed = np.where(scaled < 0, -rounded, rounded)
    return np.clip(signed, DATA_MIN, DATA_MAX).astype(np.int64)


def _evm_batch(reference: np.ndarray, measured: np.ndarray) -> np.ndarray:
    error_energy = np.sum(np.abs(measured - reference) ** 2, axis=1)
    reference_energy = np.sum(np.abs(reference) ** 2, axis=1)
    result = np.full(reference_energy.shape, np.nan, dtype=np.float64)
    nonzero = reference_energy > 1e-18
    result[nonzero] = np.sqrt(error_energy[nonzero] / reference_energy[nonzero])
    result[~nonzero & (error_energy == 0.0)] = 0.0
    return result


def evaluate_q14_batch(
    matrix_real: np.ndarray,
    matrix_imag: np.ndarray,
    symbol_real: np.ndarray,
    symbol_imag: np.ndarray,
    original_matrix: np.ndarray | None = None,
    original_symbols: np.ndarray | None = None,
) -> dict[str, np.ndarray]:
    """Evaluate batches shaped [N,4,4] and [N,4] using exact Q1.14 math."""
    mr = np.asarray(matrix_real, dtype=np.int64)
    mi = np.asarray(matrix_imag, dtype=np.int64)
    sr = np.asarray(symbol_real, dtype=np.int64)
    si = np.asarray(symbol_imag, dtype=np.int64)
    if mr.shape != mi.shape or mr.ndim != 3 or mr.shape[1:] != (4, 4):
        raise ValueError("matrix components must have shape [N,4,4]")
    if sr.shape != si.shape or sr.shape != (mr.shape[0], 4):
        raise ValueError("symbol components must have shape [N,4]")
    for values in (mr, mi, sr, si):
        if np.any(values < DATA_MIN) or np.any(values > DATA_MAX):
            raise ValueError("Q1.14 component is outside the signed 16-bit range")

    sr_lane = sr[:, None, :]
    si_lane = si[:, None, :]
    acc_real = np.sum(mr * sr_lane - mi * si_lane, axis=2, dtype=np.int64)
    acc_imag = np.sum(mr * si_lane + mi * sr_lane, axis=2, dtype=np.int64)
    if np.any(np.abs(acc_real) > ACC_MAX) or np.any(np.abs(acc_imag) > ACC_MAX):
        raise OverflowError("40-bit accumulator overflow")

    rounded_real = round_shift_away_from_zero_array(acc_real, DATA_FRAC)
    rounded_imag = round_shift_away_from_zero_array(acc_imag, DATA_FRAC)
    saturation_real = (rounded_real < DATA_MIN) | (rounded_real > DATA_MAX)
    saturation_imag = (rounded_imag < DATA_MIN) | (rounded_imag > DATA_MAX)
    saturation_mask = saturation_real | saturation_imag
    output_real = np.clip(rounded_real, DATA_MIN, DATA_MAX)
    output_imag = np.clip(rounded_imag, DATA_MIN, DATA_MAX)

    quantized_reference = (acc_real + 1j * acc_imag) / PRODUCT_SCALE
    fixed_output = (output_real + 1j * output_imag) / SCALE
    if original_matrix is None or original_symbols is None:
        floating_reference = quantized_reference
    else:
        matrix = np.asarray(original_matrix, dtype=np.complex128)
        symbols = np.asarray(original_symbols, dtype=np.complex128)
        if matrix.shape != mr.shape or symbols.shape != sr.shape:
            raise ValueError("original floating-point arrays do not match Q1.14 arrays")
        floating_reference = np.einsum("bij,bj->bi", matrix, symbols)

    implementation_error = np.abs(fixed_output - quantized_reference)
    end_to_end_error = np.abs(fixed_output - floating_reference)
    peak_accumulator = np.maximum(
        np.max(np.abs(acc_real), axis=1), np.max(np.abs(acc_imag), axis=1)
    )
    return {
        "acc_real": acc_real,
        "acc_imag": acc_imag,
        "rounded_real": rounded_real,
        "rounded_imag": rounded_imag,
        "output_real": output_real,
        "output_imag": output_imag,
        "saturation_mask": saturation_mask,
        "saturated_outputs": np.sum(saturation_mask, axis=1),
        "saturated_components": np.sum(saturation_real, axis=1)
                                + np.sum(saturation_imag, axis=1),
        "peak_accumulator": peak_accumulator,
        "accumulator_utilization": peak_accumulator / ACC_MAX,
        "implementation_evm": _evm_batch(quantized_reference, fixed_output),
        "input_quantization_evm": _evm_batch(floating_reference, quantized_reference),
        "end_to_end_evm": _evm_batch(floating_reference, fixed_output),
        "max_abs_error": np.max(end_to_end_error, axis=1),
        "max_implementation_error": np.max(implementation_error, axis=1),
        "floating_reference": floating_reference,
        "quantized_reference": quantized_reference,
        "fixed_output": fixed_output,
    }


def _qam_constellation(order: int) -> np.ndarray:
    side = int(math.isqrt(order))
    if side * side != order:
        raise ValueError("QAM order must be a square")
    levels = np.arange(-(side - 1), side, 2, dtype=np.float64)
    points = (levels[:, None] + 1j * levels[None, :]).reshape(-1)
    return points / np.sqrt(np.mean(np.abs(points) ** 2))


def _normalized_qam_batch(
    rng: np.random.Generator, count: int, order: int
) -> tuple[np.ndarray, ...]:
    matrix = rng.normal(size=(count, 4, 4)) + 1j * rng.normal(size=(count, 4, 4))
    norm = np.sqrt(np.sum(np.abs(matrix) ** 2, axis=(1, 2), keepdims=True))
    matrix = 0.9 * matrix / norm
    constellation = _qam_constellation(order)
    symbols = constellation[rng.integers(0, len(constellation), size=(count, 4))]
    mr = quantize_array(matrix.real)
    mi = quantize_array(matrix.imag)
    sr = quantize_array(symbols.real)
    si = quantize_array(symbols.imag)
    return mr, mi, sr, si, matrix, symbols


def _uniform_stress_batch(
    rng: np.random.Generator, count: int
) -> tuple[np.ndarray, ...]:
    shape_matrix = (count, 4, 4)
    shape_symbols = (count, 4)
    mr = rng.integers(DATA_MIN, DATA_MAX + 1, size=shape_matrix, dtype=np.int64)
    mi = rng.integers(DATA_MIN, DATA_MAX + 1, size=shape_matrix, dtype=np.int64)
    sr = rng.integers(DATA_MIN, DATA_MAX + 1, size=shape_symbols, dtype=np.int64)
    si = rng.integers(DATA_MIN, DATA_MAX + 1, size=shape_symbols, dtype=np.int64)
    matrix = (mr + 1j * mi) / SCALE
    symbols = (sr + 1j * si) / SCALE
    return mr, mi, sr, si, matrix, symbols


def _json_complex(values: np.ndarray) -> list[list[float]]:
    return [[float(value.real), float(value.imag)] for value in values]


def _case_record(
    profile: str,
    index: int,
    inputs: tuple[np.ndarray, ...],
    analysis: dict[str, np.ndarray],
) -> dict[str, Any]:
    mr, mi, sr, si, _, _ = inputs
    metrics = {
        name: float(analysis[name][index]) for name in METRIC_NAMES
    }
    metrics.update({
        "input_quantization_evm": float(analysis["input_quantization_evm"][index]),
        "max_implementation_error": float(analysis["max_implementation_error"][index]),
        "accumulator_utilization": float(analysis["accumulator_utilization"][index]),
    })
    return {
        "profile": profile,
        "metrics": metrics,
        "matrix_real_q14": mr[index].astype(int).tolist(),
        "matrix_imag_q14": mi[index].astype(int).tolist(),
        "symbols_real_q14": sr[index].astype(int).tolist(),
        "symbols_imag_q14": si[index].astype(int).tolist(),
        "accumulator_real_q28": analysis["acc_real"][index].astype(int).tolist(),
        "accumulator_imag_q28": analysis["acc_imag"][index].astype(int).tolist(),
        "output_real_q14": analysis["output_real"][index].astype(int).tolist(),
        "output_imag_q14": analysis["output_imag"][index].astype(int).tolist(),
        "saturated": analysis["saturation_mask"][index].astype(bool).tolist(),
        "floating_reference": _json_complex(analysis["floating_reference"][index]),
        "fixed_output": _json_complex(analysis["fixed_output"][index]),
    }


def _profile_stats(metric_values: dict[str, list[np.ndarray]]) -> dict[str, Any]:
    arrays = {name: np.concatenate(values) for name, values in metric_values.items()}
    finite_evm = arrays["end_to_end_evm"][np.isfinite(arrays["end_to_end_evm"])]
    return {
        "cases": int(arrays["peak_accumulator"].size),
        "saturated_case_rate": float(np.mean(arrays["saturated_outputs"] > 0)),
        "saturated_output_rate": float(np.sum(arrays["saturated_outputs"])
                                       / (4 * arrays["saturated_outputs"].size)),
        "saturated_component_rate": float(np.sum(arrays["saturated_components"])
                                          / (8 * arrays["saturated_components"].size)),
        "end_to_end_evm_mean": float(np.mean(finite_evm)),
        "end_to_end_evm_p95": float(np.percentile(finite_evm, 95)),
        "end_to_end_evm_p99": float(np.percentile(finite_evm, 99)),
        "end_to_end_evm_max": float(np.max(finite_evm)),
        "input_quantization_evm_p99": float(np.nanpercentile(arrays["input_quantization_evm"], 99)),
        "implementation_evm_mean": float(np.nanmean(arrays["implementation_evm"])),
        "implementation_evm_p99": float(np.nanpercentile(arrays["implementation_evm"], 99)),
        "implementation_evm_max": float(np.nanmax(arrays["implementation_evm"])),
        "max_abs_error": float(np.max(arrays["max_abs_error"])),
        "peak_accumulator_q28": int(np.max(arrays["peak_accumulator"])),
        "peak_accumulator_utilization": float(np.max(arrays["accumulator_utilization"])),
    }


def _update_worst(
    worst: dict[str, dict[str, Any]],
    profile: str,
    inputs: tuple[np.ndarray, ...],
    analysis: dict[str, np.ndarray],
) -> None:
    for metric in METRIC_NAMES:
        values = np.asarray(analysis[metric], dtype=np.float64)
        finite = np.where(np.isfinite(values), values, -np.inf)
        index = int(np.argmax(finite))
        candidate = _case_record(profile, index, inputs, analysis)
        if metric not in worst or finite[index] > worst[metric]["metrics"][metric]:
            worst[metric] = candidate


def _metric_store(analysis: dict[str, np.ndarray]) -> dict[str, np.ndarray]:
    names = set(METRIC_NAMES) | {
        "accumulator_utilization", "input_quantization_evm",
    }
    return {name: np.asarray(analysis[name]) for name in names}


def _mutated_batch(
    rng: np.random.Generator,
    worst: dict[str, dict[str, Any]],
    count: int,
    step: int,
) -> tuple[np.ndarray, ...]:
    records = list(worst.values())
    selection = rng.integers(0, len(records), size=count)
    mr = np.asarray([records[i]["matrix_real_q14"] for i in selection], dtype=np.int64)
    mi = np.asarray([records[i]["matrix_imag_q14"] for i in selection], dtype=np.int64)
    sr = np.asarray([records[i]["symbols_real_q14"] for i in selection], dtype=np.int64)
    si = np.asarray([records[i]["symbols_imag_q14"] for i in selection], dtype=np.int64)
    for values in (mr, mi, sr, si):
        mask = rng.random(values.shape) < 0.35
        delta = rng.integers(-step, step + 1, size=values.shape, dtype=np.int64)
        values[:] = np.clip(values + mask * delta, DATA_MIN, DATA_MAX)
        boundary_mask = rng.random(values.shape) < 0.03
        boundaries = rng.choice(np.asarray([DATA_MIN, DATA_MAX], dtype=np.int64), size=values.shape)
        values[:] = np.where(boundary_mask, boundaries, values)
    matrix = (mr + 1j * mi) / SCALE
    symbols = (sr + 1j * si) / SCALE
    return mr, mi, sr, si, matrix, symbols


def run_worst_case_search(config: SearchConfig) -> dict[str, Any]:
    """Run deterministic random profiles followed by feedback-guided mutation."""
    config.validate()
    rng = np.random.default_rng(config.seed)
    profiles = (
        ("normalized_qpsk", 4),
        ("normalized_16qam", 16),
        ("normalized_64qam", 64),
        ("uniform_full_scale", None),
    )
    base = config.samples // len(profiles)
    remainder = config.samples % len(profiles)
    profile_stats: dict[str, Any] = {}
    worst: dict[str, dict[str, Any]] = {}

    for profile_index, (profile, order) in enumerate(profiles):
        profile_count = base + (1 if profile_index < remainder else 0)
        metric_values: dict[str, list[np.ndarray]] = {}
        completed = 0
        while completed < profile_count:
            count = min(config.batch_size, profile_count - completed)
            if order is None:
                inputs = _uniform_stress_batch(rng, count)
            else:
                inputs = _normalized_qam_batch(rng, count, order)
            analysis = evaluate_q14_batch(*inputs)
            _update_worst(worst, profile, inputs, analysis)
            for name, values in _metric_store(analysis).items():
                metric_values.setdefault(name, []).append(values)
            completed += count
        profile_stats[profile] = _profile_stats(metric_values)

    mutation_values: dict[str, list[np.ndarray]] = {}
    completed = 0
    generation = 0
    while completed < config.mutation_samples:
        count = min(config.batch_size, config.mutation_samples - completed)
        step = max(1, 8192 >> min(generation, 12))
        inputs = _mutated_batch(rng, worst, count, step)
        analysis = evaluate_q14_batch(*inputs)
        _update_worst(worst, "adaptive_feedback", inputs, analysis)
        for name, values in _metric_store(analysis).items():
            mutation_values.setdefault(name, []).append(values)
        completed += count
        generation += 1
    if mutation_values:
        profile_stats["adaptive_feedback"] = _profile_stats(mutation_values)

    normalized = [profile_stats[name] for name, _ in profiles if name.startswith("normalized_")]
    normalized_sat_rate = max(item["saturated_case_rate"] for item in normalized)
    normalized_p99_evm = max(item["end_to_end_evm_p99"] for item in normalized)
    assessment = (
        "reasonable_with_power_normalization"
        if normalized_sat_rate < 1e-4 and normalized_p99_evm < 1e-3
        else "requires_additional_headroom_or_scaling"
    )
    return {
        "format_version": 1,
        "configuration": {
            "samples": config.samples,
            "mutation_samples": config.mutation_samples,
            "batch_size": config.batch_size,
            "seed": config.seed,
            "data_format": "signed_16_bit_q1_14",
            "accumulator_format": "signed_40_bit_q11_28",
        },
        "profiles": profile_stats,
        "worst_cases": worst,
        "q14_assessment": {
            "result": assessment,
            "normalized_max_saturated_case_rate": normalized_sat_rate,
            "normalized_max_p99_evm": normalized_p99_evm,
            "condition": "Matrix Frobenius norm is 0.9 and QAM symbols use unit average power.",
        },
    }


def render_markdown_report(result: dict[str, Any]) -> str:
    config = result["configuration"]
    lines = [
        "# Stage 10 Numeric Search Report",
        "",
        f"Seed: `{config['seed']}`  ",
        f"Random cases: `{config['samples']}`  ",
        f"Feedback mutation cases: `{config['mutation_samples']}`",
        "",
        "| Profile | Cases | Saturated cases | EVM mean | EVM p99 | EVM max | Accumulator use |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for name, stats in result["profiles"].items():
        lines.append(
            f"| {name} | {stats['cases']} | {stats['saturated_case_rate']:.6%} "
            f"| {stats['end_to_end_evm_mean']:.6e} | {stats['end_to_end_evm_p99']:.6e} "
            f"| {stats['end_to_end_evm_max']:.6e} "
            f"| {stats['peak_accumulator_utilization']:.6%} |"
        )
    lines.extend(["", "## Worst Cases", ""])
    for metric, case in result["worst_cases"].items():
        lines.append(
            f"- `{metric}`: {case['metrics'][metric]:.9e} ({case['profile']})"
        )
    assessment = result["q14_assessment"]
    lines.extend([
        "",
        "## Q1.14 Assessment",
        "",
        f"Result: `{assessment['result']}`",
        "",
        assessment["condition"],
        "",
    ])
    return "\n".join(lines)


def write_search_outputs(result: dict[str, Any], output_dir: Path) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "stage10_numeric_search.json"
    markdown_path = output_dir / "stage10_numeric_search.md"
    json_path.write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
    markdown_path.write_text(render_markdown_report(result), encoding="utf-8")
    return json_path, markdown_path
