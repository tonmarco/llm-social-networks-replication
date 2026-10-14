# Replication package

This directory contains the code needed to generate the LLM networks and reproduce the paper's analyses. Generated networks, empirical-network source data, and derived outputs are not bundled at this stage.

## Contents

- `network_generation/` — the vLLM/Docker scripts associated with the paper's `sample_100_v3` runs, selected from `mtonin_rf4421.tar.gz`. Legacy and unused generation scripts are excluded.
- `sample_preparation/` — the root-level sampling and sample-EDA notebooks. The sampling notebook writes the filenames consumed downstream.
- `code/` — ordered analysis notebooks and the pipeline runner. Notebook outputs have been cleared to keep the package source-only.
- `font/` — Barlow fonts used by the figures.
- `data/` — the raw ANES file, final persona sample, generated LLM-network files, empirical comparison networks, and a data inventory.

## Replication workflow

1. Inspect the ANES source file described in `data/README.md` and run `sample_preparation/anes_downsampling.ipynb` from this directory. It creates`data/anes_100.csv`.
2. Run `sample_preparation/00_sample_eda.ipynb` to reproduce the sample EDA.
3. To regenerate the LLM networks, use the scripts in `network_generation/`;the archived networks used in the paper are in `data/sample_100_v3/`.
4. The empirical comparison networks are in `data/real_networks_datasets/`.
5. Create a Python environment and install the analysis dependencies:

   ```bash
   python -m venv .venv
   source .venv/bin/activate
   pip install -r code/requirements.txt
   ```

6. Inspect the ordered stages and run the analysis from this directory:

   ```bash
   python code/run_pipeline.py --list
   python code/run_pipeline.py
   ```

Executed notebooks and generated data, figures, and tables are written under `outputs/`. The network-generation stage has separate GPU-heavy dependencies; see `network_generation/README.md`.

## Scope

The package excludes caches, execution logs, notebook checkpoints, raw model responses, and previously generated tables and figures. The final parsed network files used by the analysis are included under `data/sample_100_v3/`.
