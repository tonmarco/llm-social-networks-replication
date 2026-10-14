# Analysis code

Clean notebooks for the `sample_100_v3` network analysis. 

## Run

From the replication-package root, after installing `requirements.txt` in an active Python environment:

```bash
python code/run_pipeline.py
```

To inspect or run only some stages:

```bash
python code/run_pipeline.py --list
python code/run_pipeline.py --only 00 01 02
```

## Notebooks

1. `00_build_graphs.ipynb` — build directed and reciprocal LLM networks.
2. `01_real_network_benchmark.ipynb` — load and evaluate real networks.
3. `02_structural_metrics.ipynb` — observed structural metrics, empirical plausibility, attribute mixing, and degree comparisons. Density is descriptive; no simulated null networks are generated.
4. `03_local_exposure.ipynb` — directed-out and mutual partisan exposure.
5. `04_exposure_diagnostics.ipynb` — group-specific nomination-network MSD for main-text Fig. 5, SI Fig. S5, and SI Table S11. Stage 04 also builds the complete SI group-results table with `generate_si_s5_table.py`.
6. `05_matched_assortativity_exposure.ipynb` — within-model comparisons of paired-persona exposure among networks with similar vote assortativity. It produces main-text Fig. 4, SI Fig. S4, and SI Table S10 using the 0.02 and 0.05 matching thresholds.

## Inputs and outputs

Inputs are under `data/`:

- `data/anes_100.csv`
- `data/sample_100_v3/`
- `data/real_networks_datasets/`

Generated files go to:

- `outputs/data/`
- `outputs/figures/`
- `outputs/tables/`
- `outputs/notebooks/`

