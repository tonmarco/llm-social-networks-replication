import os
import time
import gc
import re
import json
from datetime import datetime
import pandas as pd
from vllm import LLM, SamplingParams
from collections import defaultdict, Counter
import argparse

# =====================================================
# ARGPARSE
# =====================================================

parser = argparse.ArgumentParser()
parser.add_argument("--model_name", type=str, default=None)
parser.add_argument("--batch_size", type=int, default=128)
parser.add_argument("--sample_size", type=str, default="100", choices=["100", "200", "300"])
parser.add_argument("--n_runs", type=int, default=10, help="Number of repeated runs per condition")
parser.add_argument("--max_egos", type=int, default=None, help="Limit number of egos/personas for smoke testing")
args = parser.parse_args()

SAMPLE_FOLDER = f"sample_{args.sample_size}_v3"

# =====================================================
# CONFIG
# =====================================================

if args.model_name:
    MODELS = [args.model_name]
else:
    MODELS = [
        # "meta-llama/Llama-3.1-8B-Instruct",
        # "Qwen/Qwen2.5-7B-Instruct",
        # "mistralai/Mistral-7B-Instruct-v0.3",
        "hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4",
        # "Qwen/Qwen2.5-32B-Instruct-AWQ",
        #"Qwen/Qwen2.5-72B-Instruct-AWQ"
    ]

LLM_BATCH_SIZE = args.batch_size

TEMPERATURES = [0.1, 0.7]

CANDIDATE_CHUNKS = [5, 10, 25, 50]

MAX_TOKENS_BY_CHUNK = {
    5: 32,
    10: 48,
    25: 96,
    50: 160
}

N_RUNS = args.n_runs

DATASETS = {
    "100": "/app/data/anes_100.csv",
    # "200": "/app/data/anes_200.csv",
    # "300": "/app/data/anes_300.csv"
}

TRAIT_COMBOS = [
    #["vote", "religion", "age", "location", "education", "race", "gender"],
    ["gender", "race", "education", "location", "age", "religion", "vote"]
]

# =====================================================
# LOGGING
# =====================================================

def log(msg, log_file):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    full = f"[{timestamp}] {msg}"
    print(full)
    with open(log_file, "a") as f:
        f.write(full + "\n")

# =====================================================
# RESPONSE PARSER
# =====================================================

def extract_ids(resp, valid_ids):
    if not resp or not resp.strip():
        return set(), "empty"

    resp = resp.strip()

    # Expected format: 123,456,789
    if re.fullmatch(r"\d+(?:\s*,\s*\d+)*", resp):
        ids = set(re.findall(r"\d+", resp)) & valid_ids
        return ids, "valid"

    # Recover responses such as:
    # "IDs should be 4255, 471 - ..."
    # "IDs must be 2500, 4684, 5134."
    match = re.search(
        r"\bIDs?\s+(?:should|must|would)\s+be\s*[:\-]?\s*"
        r"(\d+(?:\s*,\s*\d+)*)",
        resp,
        flags=re.IGNORECASE
    )

    if match:
        ids = set(re.findall(r"\d+", match.group(1))) & valid_ids
        return ids, "recoverable"

    return set(), "malformed"

# =====================================================
# LOAD PERSONAS
# =====================================================

def get_personas(csv_file):
    df = pd.read_csv(csv_file)

    required = [
        "caseid",
        "profile_gender",
        "profile_age",
        "profile_age_bucket",
        "profile_racethnicity",
        "profile_educ5",
        "profile_state",
        "profile_region4",
        "profile_relig",
        "w2presvtwho",
        "weight_post"
    ]

    df = df[required].dropna().reset_index(drop=True)
    return df.to_dict(orient="records")

# =====================================================
# DESCRIPTION HELPERS
# =====================================================

T_ALTER = {
    "age": lambda p: f"{p['profile_age']}-year-old",
    "gender": lambda p: p["profile_gender"],
    "race": lambda p: p["profile_racethnicity"],
    "location": lambda p: f"living in {p['profile_state']}",
    "education": lambda p: p["profile_educ5"],
    "religion": lambda p: p["profile_relig"],
    "vote": lambda p: p["w2presvtwho"]
}

def build_ego(p, traits):
    return "You are " + ", ".join(T_ALTER[t](p) for t in traits) + "."

def build_alter(p, traits):
    return ", ".join(T_ALTER[t](p) for t in traits)

# =====================================================
# LLM CHAT CALL
# =====================================================

def vllm_chat(prompts, sampling_params, llm):
    conversations = [
        [{"role": "user", "content": prompt}]
        for prompt in prompts
    ]

    outputs = llm.chat(
        messages=conversations,
        sampling_params=sampling_params,
        use_tqdm=False
    )

    return [
        output.outputs[0].text.strip() if output.outputs else ""
        for output in outputs
    ]

# =====================================================
# LLM LOADER
# =====================================================

def load_llm(model_name):
    name = model_name.lower()
    is_awq = "awq" in name
    is_72b = "72b" in name

    if is_awq and is_72b:
        return LLM(
            model=model_name,
            tensor_parallel_size=1,
            gpu_memory_utilization=0.98,
            max_model_len=2048,
            max_num_seqs=LLM_BATCH_SIZE,
            max_num_batched_tokens=LLM_BATCH_SIZE * 512,
            quantization="awq",
            dtype="float16",
            enforce_eager=True,
            swap_space=32,
            trust_remote_code=True
        )

    if is_awq:
        return LLM(
            model=model_name,
            tensor_parallel_size=1,
            gpu_memory_utilization=0.95,
            max_model_len=2048,
            max_num_seqs=LLM_BATCH_SIZE,
            max_num_batched_tokens=LLM_BATCH_SIZE * 2048,
            quantization="awq",
            dtype="float16",
            enforce_eager=True,
            swap_space=32,
            trust_remote_code=True
        )

    return LLM(
        model=model_name,
        tensor_parallel_size=1,
        gpu_memory_utilization=0.90,
        max_model_len=2048,
        max_num_seqs=LLM_BATCH_SIZE,
        max_num_batched_tokens=LLM_BATCH_SIZE * 2048,
        enforce_eager=False,
        swap_space=16,
        trust_remote_code=True
    )

# =====================================================
# PROCESS ONE BATCH
# =====================================================

def process_batch(
    prompts,
    chunk_meta,
    ego_id,
    sampling_params,
    llm,
    raw_path,
    run_id,
    model_name,
    temp,
    chunk_size,
    run,
    traits,
    adj,
    resp_counter,
    parse_counter
):
    responses = vllm_chat(prompts, sampling_params, llm)

    with open(raw_path, "a") as raw_f:
        for prompt_text, resp, alters_batch in zip(prompts, responses, chunk_meta):
            valid_ids = {str(a["caseid"]) for a in alters_batch}

            ids, parse_status = extract_ids(resp, valid_ids)
            parsed_ids = sorted(map(int, ids))

            adj[ego_id].update(parsed_ids)
            resp_counter[resp] += 1
            parse_counter[parse_status] += 1

            raw_record = {
                "run_id": run_id,
                "model": model_name,
                "temperature": temp,
                "chunk_size": chunk_size,
                "run": run,
                "attribute_order": "_".join(traits),
                "ego_id": int(ego_id),
                "alter_ids": [int(a["caseid"]) for a in alters_batch],
                "raw_response": resp,
                "parsed_ids": parsed_ids,
                "parse_status": parse_status,
                "prompt": prompt_text
            }

            raw_f.write(json.dumps(raw_record, ensure_ascii=False) + "\n")

# =====================================================
# NETWORK GENERATOR
# =====================================================

def run_llm_network_list(personas, base_save_path, raw_base_path, llm_batch_size=128):
    os.makedirs(base_save_path, exist_ok=True)
    os.makedirs(raw_base_path, exist_ok=True)

    global_log = os.path.join(base_save_path, "progress_batch.log")

    N = len(personas)

    total_runs = (
        len(MODELS)
        * len(TEMPERATURES)
        * len(TRAIT_COMBOS)
        * len(CANDIDATE_CHUNKS)
        * N_RUNS
    )

    current_run = 0

    log(f"Total personas: {N}", global_log)
    log(f"Total runs: {total_runs}", global_log)

    for model_name in MODELS:
        model_tag = (
            model_name.split("/")[-1]
            .replace(".", "")
            .replace("-", "_")
            .lower()
        )

        model_dir = os.path.join(base_save_path, model_tag)
        raw_model_dir = os.path.join(raw_base_path, model_tag)

        os.makedirs(model_dir, exist_ok=True)
        os.makedirs(raw_model_dir, exist_ok=True)

        model_log = os.path.join(model_dir, "progress.log")

        log(f"Starting model: {model_name}", model_log)

        llm = load_llm(model_name)

        for temp in TEMPERATURES:
            for traits in TRAIT_COMBOS:
                ego_cache = {
                    p["caseid"]: build_ego(p, traits)
                    for p in personas
                }

                for chunk_size in CANDIDATE_CHUNKS:
                    for run in range(N_RUNS):
                        current_run += 1
                        start_time = time.time()

                        sampling_params = SamplingParams(
                            temperature=temp,
                            top_p=1.0,
                            max_tokens=MAX_TOKENS_BY_CHUNK[chunk_size],
                            seed=run
                        )

                        run_id = (
                            f"{model_tag}"
                            f"_temp{temp}"
                            f"_chunk{chunk_size}"
                            f"_run{run}"
                            f"_{'_'.join(traits)}"
                        )

                        out_path = os.path.join(
                            model_dir,
                            f"{run_id}.txt"
                        )

                        raw_path = os.path.join(
                            raw_model_dir,
                            f"{run_id}_raw.jsonl"
                        )

                        with open(raw_path, "w"):
                            pass

                        log(
                            f"RUN {current_run}/{total_runs} | {run_id}",
                            model_log
                        )

                        adj = defaultdict(set)
                        resp_counter = Counter()
                        parse_counter = Counter()

                        for idx, ego in enumerate(personas):
                            if idx % 50 == 0:
                                log(f"Ego {idx}/{N}", model_log)

                            ego_id = ego["caseid"]
                            ego_desc = ego_cache[ego_id]

                            prompts = []
                            chunk_meta = []

                            others = personas[:idx] + personas[idx + 1:]

                            for i in range(0, len(others), chunk_size):
                                alters = others[i:i + chunk_size]

                                alters_text = "\n".join(
                                    f"ID {a['caseid']}: {build_alter(a, traits)}"
                                    for a in alters
                                )

                                prompt = (
                                    f"{ego_desc}\n\n"
                                    "Here is a list of people:\n\n"
                                    f"{alters_text}\n\n"
                                    "Select who you would befriend. "
                                    "Answer only with the selected IDs separated by commas, "
                                    "for example: 123,456,789. "
                                    "Do not provide explanations, reasoning, names, or any other text."
                                )

                                prompts.append(prompt)
                                chunk_meta.append(alters)

                                if len(prompts) == llm_batch_size:
                                    process_batch(
                                        prompts=prompts,
                                        chunk_meta=chunk_meta,
                                        ego_id=ego_id,
                                        sampling_params=sampling_params,
                                        llm=llm,
                                        raw_path=raw_path,
                                        run_id=run_id,
                                        model_name=model_name,
                                        temp=temp,
                                        chunk_size=chunk_size,
                                        run=run,
                                        traits=traits,
                                        adj=adj,
                                        resp_counter=resp_counter,
                                        parse_counter=parse_counter
                                    )

                                    prompts = []
                                    chunk_meta = []

                            if prompts:
                                process_batch(
                                    prompts=prompts,
                                    chunk_meta=chunk_meta,
                                    ego_id=ego_id,
                                    sampling_params=sampling_params,
                                    llm=llm,
                                    raw_path=raw_path,
                                    run_id=run_id,
                                    model_name=model_name,
                                    temp=temp,
                                    chunk_size=chunk_size,
                                    run=run,
                                    traits=traits,
                                    adj=adj,
                                    resp_counter=resp_counter,
                                    parse_counter=parse_counter
                                )

                        with open(out_path, "w") as f:
                            for p in personas:
                                eid = p["caseid"]
                                neighbors = sorted(adj[eid]) if eid in adj else []
                                f.write(
                                    f"{eid}: {','.join(map(str, neighbors))}\n"
                                )

                        elapsed = time.time() - start_time

                        log(
                            f"Saved {out_path} | {elapsed / 60:.1f} min",
                            model_log
                        )

                        log(
                            f"Saved raw outputs: {raw_path}",
                            model_log
                        )

                        log(
                            f"Top responses: {resp_counter.most_common(5)}",
                            model_log
                        )

                        log(
                            f"Parse status counts: {dict(parse_counter)}",
                            model_log
                        )

        log(f"Finished model: {model_name}", model_log)

        del llm
        gc.collect()

# =====================================================
# MAIN
# =====================================================

if __name__ == "__main__":
    data_path = DATASETS[args.sample_size]

    base_save_path = os.path.join(
        "results",
        SAMPLE_FOLDER
    )

    raw_base_path = os.path.join(
        "raw_outputs",
        SAMPLE_FOLDER
    )

    personas = get_personas(data_path)

    if args.max_egos is not None:
        personas = personas[:args.max_egos]

    run_llm_network_list(
        personas,
        base_save_path=base_save_path,
        raw_base_path=raw_base_path,
        llm_batch_size=LLM_BATCH_SIZE
    )