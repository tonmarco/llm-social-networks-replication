# Data

This directory contains the input datasets needed to reproduce the paper:

- `anes_specialstudy_2020-2022_socialmedia_csv_20230705.csv` — source ANES special-study file read by `sample_preparation/anes_downsampling.ipynb`.
- `anes_100.csv` — the 100-person ANES-derived persona sample used to generate and evaluate networks.
- `sample_100_v3/` — the generated LLM-network files used in the paper. They can also be regenerated with `network_generation/`.
- `real_networks_datasets/` — empirical comparison-network source files.

Expected layout:

```text
replication_package/
├── data/
│   ├── anes_specialstudy_2020-2022_socialmedia_csv_20230705.csv
│   ├── anes_100.csv
│   ├── sample_100_v3/
│   └── real_networks_datasets/
├── code/
├── font/
├── network_generation/
└── sample_preparation/
```

The analysis notebooks read these inputs from `data/` and write derived data to `outputs/data/`. The included sampling notebook deterministically recreates `data/anes_100.csv` from the source ANES file using random seed 42.

Progress logs, notebook checkpoints, operating-system metadata, and raw model response logs are not part of the analysis datasets and are excluded.
