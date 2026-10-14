# Network-generation code

This directory contains the source files used to generate the paper's
`sample_100_v3` networks, selected from `mtonin_rf4421.tar.gz` (archive root
`mtonin/llm_ties/`). Relative paths are preserved so that each launcher resolves
the Python script it calls. Legacy experiments, unused launchers, generated
results, logs, token-cost summaries, notebook checkpoints, and cache directories
are excluded.

## Included generation scripts

The observed archive outputs correspond to these stratified generators:

- `scripts/networks/run_llm_pair_strata.py` — pairwise prompts for the 7B/8B
  models.
- `scripts/networks/run_llm_batch_strata.py` — list prompts for the 7B/8B
  models.
- `scripts/networks/run_llm_pair_strata_70.py` — Qwen-72B pairwise prompts.
- `scripts/networks/run_llm_pair_strata_70_2.py` — Llama-70B pairwise prompts.
- `scripts/networks/run_llm_batch_strata_70.py` — Qwen-72B list prompts.
- `scripts/networks/run_llm_batch_strata_70_2.py` and
  `run_llm_batch_strata_70_3.py` — Llama-70B list prompts, split by attribute
  ordering.

Only the seven corresponding `start_*strata*.sh` launchers are included. Note
that the archived filename `start_pair_strata_70_llama.sh` launches the Qwen-72B
script despite its name; it is retained unchanged for provenance.

## Runtime

The supplied `Dockerfile` is based on vLLM and installs the packages in
`requirements.txt`. Network generation requires a CUDA-capable GPU with enough
memory for the selected model, access to the model weights, and a
`HUGGING_FACE_HUB_TOKEN` environment variable. The scripts expect the survey
inputs inside the container under `/app/data/` (notably
`/app/data/anes_100.csv`).

Example from this directory:

```bash
docker build -t llm-network-generation .
mkdir -p ../data/sample_100_v3 ../raw_outputs
docker run --gpus all --rm \
  -e HUGGING_FACE_HUB_TOKEN \
  -v "$PWD/../data:/app/data" \
  -v "$PWD/../data/sample_100_v3:/app/sample_100_v3" \
  -v "$PWD/../raw_outputs:/app/raw_outputs" \
  llm-network-generation ./start_pair_strata.sh
```

Before launching a full run, inspect the chosen launcher and use its supported
environment variables (for example `BATCH_SIZE`, `SAMPLE_SIZE`, `N_RUNS`, and
`MAX_EGOS` in the large-model launchers). Model inference can be costly and is
not part of the lightweight analysis validation.
