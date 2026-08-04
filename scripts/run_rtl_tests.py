"""Generate vectors, compile phase-2 RTL, and run all unit simulations."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from scripts.generate_rtl_vectors import generate_all


ROOT = Path(__file__).resolve().parents[1]


def find_tool(name: str) -> str | None:
    located = shutil.which(name)
    if located:
        return located
    if os.name == "nt":
        candidate = Path(r"C:\iverilog\bin") / f"{name}.exe"
        if candidate.exists():
            return str(candidate)
    return None


def run(command: list[str]) -> None:
    print("+", " ".join(command))
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--random-count", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=20260803)
    parser.add_argument("--waves", action="store_true", help="reserved for later waveform-enabled tests")
    args = parser.parse_args()
    if args.random_count < 1:
        parser.error("--random-count must be positive")

    iverilog = find_tool("iverilog")
    vvp = find_tool("vvp")
    if not iverilog or not vvp:
        raise SystemExit(
            "Icarus Verilog was not found. Install it or add iverilog and vvp to PATH."
        )

    vector_dir = ROOT / "build" / "rtl_vectors"
    sim_dir = ROOT / "build" / "sim"
    sim_dir.mkdir(parents=True, exist_ok=True)
    counts = generate_all(vector_dir, args.random_count, args.seed)
    for name, count in counts.items():
        print(f"{name}: generated {count} vectors")

    tests = [
        (
            "complex_mult",
            [ROOT / "rtl" / "complex_mult.sv", ROOT / "tb" / "unit" / "tb_complex_mult.sv"],
        ),
        (
            "complex_mac",
            [
                ROOT / "rtl" / "complex_mult.sv",
                ROOT / "rtl" / "complex_mac.sv",
                ROOT / "tb" / "unit" / "tb_complex_mac.sv",
            ],
        ),
        (
            "fixed_round_sat",
            [ROOT / "rtl" / "fixed_round_sat.sv", ROOT / "tb" / "unit" / "tb_fixed_round_sat.sv"],
        ),
    ]

    for top, sources in tests:
        image = sim_dir / f"{top}.vvp"
        run([iverilog, "-g2012", "-Wall", "-s", f"tb_{top}", "-o", str(image)]
            + [str(source) for source in sources])
        run([vvp, str(image)])

    print(f"PASS: all {len(tests)} phase-2 RTL unit tests completed")


if __name__ == "__main__":
    main()

