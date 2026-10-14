#!/bin/bash
set -e

export VLLM_WORKER_MULTIPROC_METHOD=spawn
export PYTORCH_MULTIPROCESSING_START_METHOD=spawn
export HF_HUB_ENABLE_HF_TRANSFER=1

echo "Starting vLLM network run..."

if [ -z "$HUGGING_FACE_HUB_TOKEN" ]; then
  echo "Error: HUGGING_FACE_HUB_TOKEN not set!"
  exit 1
fi

#MODEL=${MODEL:-"hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4"}
#MODEL=${MODEL:-"Qwen/Qwen2.5-32B-Instruct-AWQ"}
MODEL=${MODEL:-"Qwen/Qwen2.5-72B-Instruct-AWQ"}
BATCH_SIZE=${BATCH_SIZE:-8}
SAMPLE_SIZE=${SAMPLE_SIZE:-100}
N_RUNS=${N_RUNS:-10}
MAX_EGOS=${MAX_EGOS:-}

echo "======================================"
echo "Model: $MODEL"
echo "Batch size: $BATCH_SIZE"
echo "Sample size: $SAMPLE_SIZE"
echo "N runs: $N_RUNS"
echo "Max egos: $MAX_EGOS"
echo "======================================"

CMD_ARGS=(
    --model_name "$MODEL"
    --batch_size "$BATCH_SIZE"
    --sample_size "$SAMPLE_SIZE"
    --n_runs "$N_RUNS"
)

if [ -n "$MAX_EGOS" ]; then
    CMD_ARGS+=(--max_egos "$MAX_EGOS")
fi

python3 -u scripts/networks/run_llm_pair_strata_70.py "${CMD_ARGS[@]}"

echo "Run completed."