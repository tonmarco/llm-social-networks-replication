#!/bin/bash
set -e

export VLLM_WORKER_MULTIPROC_METHOD=spawn
export PYTORCH_MULTIPROCESSING_START_METHOD=spawn

echo "Starting vLLM network runs for all models..."

if [ -z "$HUGGING_FACE_HUB_TOKEN" ]; then
  echo "Error: HUGGING_FACE_HUB_TOKEN not set!"
  exit 1
fi

MODELS=(
    "meta-llama/Llama-3.1-8B-Instruct"
    "Qwen/Qwen2.5-7B-Instruct"
    "mistralai/Mistral-7B-Instruct-v0.3"
)

BATCH_SIZE=${BATCH_SIZE:-192}

for MODEL in "${MODELS[@]}"; do
    echo "======================================"
    echo "Running model: $MODEL"
    echo "======================================"

    python3 -u scripts/networks/run_llm_pair_strata.py \
        --model_name "$MODEL" \
        --batch_size $BATCH_SIZE

    echo "Finished model: $MODEL"
done

echo "All models completed."