#!/usr/bin/env python3
"""Run the analysis notebooks in order."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CODE_DIR = ROOT / "code"
NOTEBOOK_DIR = ROOT / "outputs" / "notebooks"

STAGES = [
    ("00", "00_build_graphs.ipynb"),
    ("01", "01_real_network_benchmark.ipynb"),
    ("02", "02_structural_metrics.ipynb"),
    ("03", "03_local_exposure.ipynb"),
    ("04", "04_exposure_diagnostics.ipynb"),
    ("05", "05_matched_assortativity_exposure.ipynb"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="+", choices=[number for number, _ in STAGES])
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        for number, notebook in STAGES:
            print(number, notebook)
        return

    for required in (
        ROOT / "data" / "anes_100.csv",
        ROOT / "data" / "sample_100_v3",
        ROOT / "data" / "real_networks_datasets",
    ):
        if not required.exists():
            raise SystemExit(f"Missing input: {required}")

    selected = STAGES if args.only is None else [stage for stage in STAGES if stage[0] in args.only]
    jupyter = ROOT / ".conda" / "bin" / "jupyter"
    if not jupyter.exists():
        found = shutil.which("jupyter")
        if not found:
            raise SystemExit("Jupyter is not installed. See code/requirements.txt.")
        jupyter = Path(found)

    NOTEBOOK_DIR.mkdir(parents=True, exist_ok=True)
    for number, notebook in selected:
        source = CODE_DIR / notebook
        print(f"[{number}] {notebook}", flush=True)
        subprocess.run(
            [
                str(jupyter), "nbconvert", "--to", "notebook", "--execute",
                "--ExecutePreprocessor.timeout=-1",
                "--output-dir", str(NOTEBOOK_DIR),
                "--output", f"{source.stem}.executed.ipynb",
                str(source),
            ],
            cwd=ROOT,
            check=True,
        )
        if number == "04":
            subprocess.run(
                [str(Path(sys.executable)), str(CODE_DIR / "generate_si_s5_table.py")],
                cwd=ROOT,
                check=True,
            )


if __name__ == "__main__":
    main()
