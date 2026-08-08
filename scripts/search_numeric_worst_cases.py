"""Command-line entry point for the Stage 10 Q1.14 numeric search."""

from __future__ import annotations

import argparse
from pathlib import Path

from model.numeric_analysis import SearchConfig, run_worst_case_search, write_search_outputs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=100_000)
    parser.add_argument("--mutation-samples", type=int, default=20_000)
    parser.add_argument("--batch-size", type=int, default=2_000)
    parser.add_argument("--seed", type=int, default=20260808)
    parser.add_argument("--output-dir", type=Path, default=Path("reports/generated/stage10"))
    args = parser.parse_args()
    config = SearchConfig(
        samples=args.samples,
        mutation_samples=args.mutation_samples,
        batch_size=args.batch_size,
        seed=args.seed,
    )
    result = run_worst_case_search(config)
    json_path, markdown_path = write_search_outputs(result, args.output_dir)
    print(f"PASS: analyzed {args.samples + args.mutation_samples} Q1.14 cases")
    print(f"Q1.14 assessment: {result['q14_assessment']['result']}")
    print(f"JSON report: {json_path}")
    print(f"Markdown report: {markdown_path}")


if __name__ == "__main__":
    main()
