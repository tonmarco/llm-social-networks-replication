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
# ARGPARSE / CONFIGURATION
# =====================================================

parser = argparse.ArgumentParser()

parser.add_argument(
    "--model_name",
    type=str,
    default=None,
    help="Model to run (if set, overrides full list)"
)

parser.add_argument(
    "--batch_size",
    type=int,
    default=256,
    help="vLLM batch size"
)

parser.add_argument(
    "--sample_size",
    type=str,
    default="100",
    choices=["100", "200", "300"]
)

parser.add_argument(
    "--max_egos",
    type=int,
    default=None,
    help="Limit number of egos/personas for smoke testing"
)

parser.add_argument(
    "--n_runs",
    type=int,
    default=10,
    help="Number of repeated runs per condition"
)

args = parser.parse_args()

SAMPLE_FOLDER = f"sample_{args.sample_size}_v3"

# =====================================================
# CONFIG
# =====================================================

MODELS = [
    # "hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4",
    # "Qwen/Qwen2.5-32B-Instruct-AWQ",
    "Qwen/Qwen2.5-72B-Instruct-AWQ"
]

if args.model_name is not None:
    MODELS = [args.model_name]

LLM_BATCH_SIZE = args.batch_size

TEMPERATURES = [0.1, 0.7]

N_RUNS = args.n_runs

DATASETS = {
    "100": "/app/data/anes_100.csv",
    # "200": "/app/data/anes_200.csv",
    # "300": "/app/data/anes_300.csv"
}

TRAIT_COMBOS = [
    ["vote", "religion", "age", "location", "education", "race", "gender"],
    ["gender", "race", "education", "location", "age", "religion", "vote"]
]

# =====================================================
# LOGGING
# =====================================================

def log(msg, log_file):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    full_msg = f"[{timestamp}] {msg}"
    print(full_msg)

    with open(log_file, "a") as f:
        f.write(full_msg + "\n")

# =====================================================
# RESPONSE PARSING
# =====================================================

def parse_binary(resp):
    """
    Parse the binary friendship decision.

    Returns
    -------
    parsed : int or None
        1 = friendship
        0 = no friendship
        None = invalid / ambiguous

    status : str
        valid
        recoverable
        empty
        malformed
    """

    if not resp or not resp.strip():
        return None, "empty"

    r = resp.strip()

    # Exact requested output
    if r == "1":
        return 1, "valid"

    if r == "0":
        return 0, "valid"

    # Very conservative fallback
    r_lower = r.lower()

    if r_lower in {"yes", "yes."}:
        return 1, "recoverable"

    if r_lower in {"no", "no."}:
        return 0, "recoverable"

    # Do not use startswith("1") or startswith("0"),
    # because "1 because..." is a malformed response.
    return None, "malformed"

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

T = {
    "age": lambda p: f"{p['profile_age']}-year-old",
    "gender": lambda p: p["profile_gender"],
    "race": lambda p: p["profile_racethnicity"],
    "location": lambda p: f"living in {p['profile_state']}",
    "education": lambda p: p["profile_educ5"],
    "religion": lambda p: p["profile_relig"],
    "vote": lambda p: p["w2presvtwho"]
}

def get_description_ego(p, traits):
    return "You are " + ", ".join(T[t](p) for t in traits) + "."

def get_description_alter(p, traits):
    return ", ".join(T[t](p) for t in traits)

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
        output.outputs[0].text.strip()
        if output.outputs
        else ""
        for output in outputs
    ]

# =====================================================
# LLM LOADER
# =====================================================

def load_llm(model_name, llm_batch_size):
    is_awq = "awq" in model_name.lower()

    if is_awq:
        return LLM(
            model=model_name,
            tensor_parallel_size=1,
            gpu_memory_utilization=0.95,
            max_model_len=512,
            max_num_seqs=llm_batch_size,
            max_num_batched_tokens=llm_batch_size * 256,
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
        max_model_len=1024,
        max_num_seqs=llm_batch_size,
        max_num_batched_tokens=llm_batch_size * 512,
        enforce_eager=False,
        swap_space=16,
        trust_remote_code=True
    )

# =====================================================
# PROCESS BATCH
# =====================================================

def process_batch(
    prompts,
    pairs,
    sampling_params,
    llm,
    raw_path,
    run_id,
    model_name,
    temp,
    run,
    traits,
    adj,
    resp_counter,
    parse_counter
):
    responses = vllm_chat(
        prompts,
        sampling_params,
        llm
    )

    with open(raw_path, "a") as raw_f:
        for prompt_text, resp, (e_id, a_id) in zip(
            prompts,
            responses,
            pairs
        ):
            parsed, parse_status = parse_binary(resp)

            parse_counter[parse_status] += 1

            if parsed is not None:
                resp_counter[parsed] += 1

            if parsed == 1:
                adj[e_id].add(a_id)

            raw_record = {
                "run_id": run_id,
                "model": model_name,
                "temperature": temp,
                "run": run,
                "attribute_order": "_".join(traits),
                "ego_id": int(e_id),
                "alter_id": int(a_id),
                "raw_response": resp,
                "parsed_response": parsed,
                "parse_status": parse_status,
                "prompt": prompt_text
            }

            raw_f.write(
                json.dumps(
                    raw_record,
                    ensure_ascii=False
                ) + "\n"
            )

# =====================================================
# NETWORK GENERATION
# =====================================================

def run_llm_network_pairwise(
    personas,
    base_save_path,
    raw_base_path,
    llm_batch_size=256
):
    os.makedirs(base_save_path, exist_ok=True)
    os.makedirs(raw_base_path, exist_ok=True)

    log_file = os.path.join(
        base_save_path,
        "progress.log"
    )

    with open(log_file, "w") as f:
        f.write("=== LLM NETWORK RUN START ===\n")

    N = len(personas)

    log(
        f"Total personas: {N}",
        log_file
    )

    total_runs = (
        len(MODELS)
        * len(TEMPERATURES)
        * len(TRAIT_COMBOS)
        * N_RUNS
    )

    current_run = 0

    log(
        f"Total runs: {total_runs}",
        log_file
    )

    for model_name in MODELS:
        model_tag = (
            model_name.split("/")[-1]
            .replace(".", "")
            .replace("-", "_")
            .lower()
        )

        model_dir = os.path.join(
            base_save_path,
            model_tag
        )

        raw_model_dir = os.path.join(
            raw_base_path,
            model_tag
        )

        os.makedirs(
            model_dir,
            exist_ok=True
        )

        os.makedirs(
            raw_model_dir,
            exist_ok=True
        )

        model_log = os.path.join(
            model_dir,
            "progress.log"
        )

        with open(model_log, "w") as f:
            f.write("=== MODEL RUN START ===\n")

        log(
            f"Loading model: {model_name}",
            model_log
        )

        llm = load_llm(
            model_name,
            llm_batch_size
        )

        for temp in TEMPERATURES:
            for traits in TRAIT_COMBOS:
                for run in range(N_RUNS):
                    sampling_params = SamplingParams(
                        temperature=temp,
                        max_tokens=3,
                        top_p=1.0,
                        seed=run
                    )

                    current_run += 1

                    run_id = (
                        f"{model_tag}"
                        f"_temp{temp}"
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

                    # Start fresh raw JSONL file
                    with open(raw_path, "w"):
                        pass

                    log(
                        f"RUN {current_run}/{total_runs} | {run_id}",
                        model_log
                    )

                    start_time = time.time()

                    total_pairs = N * (N - 1)
                    processed_pairs = 0

                    prompts = []
                    pairs = []

                    adj = defaultdict(set)
                    resp_counter = Counter()
                    parse_counter = Counter()

                    for i, ego in enumerate(personas):
                        if i % 200 == 0:
                            log(
                                f"Ego {i}/{N}",
                                model_log
                            )

                        ego_id = ego["caseid"]

                        ego_desc = get_description_ego(
                            ego,
                            traits
                        )

                        for j, alter in enumerate(personas):
                            if i == j:
                                continue

                            alter_id = alter["caseid"]

                            alter_desc = get_description_alter(
                                alter,
                                traits
                            )

                            prompt = (
                                f"{ego_desc}\n\n"
                                "You meet this person:\n\n"
                                f"{alter_desc}\n\n"
                                "Would you become friends with this person? "
                                "Answer only 1 if yes or 0 if no. "
                                "Do not provide any other text."
                            )

                            prompts.append(
                                prompt
                            )

                            pairs.append(
                                (
                                    ego_id,
                                    alter_id
                                )
                            )

                            processed_pairs += 1

                            if processed_pairs % 100000 == 0:
                                elapsed = (
                                    time.time()
                                    - start_time
                                )

                                rate = (
                                    processed_pairs / elapsed
                                    if elapsed > 0
                                    else 0
                                )

                                remaining = (
                                    (total_pairs - processed_pairs) / rate
                                    if rate > 0
                                    else 0
                                )

                                log(
                                    f"{run_id} | "
                                    f"{processed_pairs}/{total_pairs} | "
                                    f"ETA {remaining / 60:.1f}m",
                                    model_log
                                )

                            if len(prompts) == llm_batch_size:
                                process_batch(
                                    prompts=prompts,
                                    pairs=pairs,
                                    sampling_params=sampling_params,
                                    llm=llm,
                                    raw_path=raw_path,
                                    run_id=run_id,
                                    model_name=model_name,
                                    temp=temp,
                                    run=run,
                                    traits=traits,
                                    adj=adj,
                                    resp_counter=resp_counter,
                                    parse_counter=parse_counter
                                )

                                prompts = []
                                pairs = []

                    # Flush remaining prompts
                    if prompts:
                        process_batch(
                            prompts=prompts,
                            pairs=pairs,
                            sampling_params=sampling_params,
                            llm=llm,
                            raw_path=raw_path,
                            run_id=run_id,
                            model_name=model_name,
                            temp=temp,
                            run=run,
                            traits=traits,
                            adj=adj,
                            resp_counter=resp_counter,
                            parse_counter=parse_counter
                        )

                    # Save network
                    with open(out_path, "w") as f:
                        for ego_id in sorted(
                            p["caseid"]
                            for p in personas
                        ):
                            neighbors = (
                                sorted(adj[ego_id])
                                if ego_id in adj
                                else []
                            )

                            f.write(
                                f"{ego_id}: "
                                f"{','.join(map(str, neighbors))}\n"
                            )

                    elapsed = (
                        time.time()
                        - start_time
                    )

                    log(
                        f"Saved: {out_path} | "
                        f"{elapsed / 60:.1f} min",
                        model_log
                    )

                    log(
                        f"Saved raw outputs: {raw_path}",
                        model_log
                    )

                    log(
                        f"Binary responses: {dict(resp_counter)}",
                        model_log
                    )

                    log(
                        f"Parse status counts: {dict(parse_counter)}",
                        model_log
                    )

        log(
            f"Finished model: {model_name}",
            model_log
        )

        del llm
        gc.collect()

# =====================================================
# MAIN
# =====================================================

if __name__ == "__main__":
    data_path = DATASETS[
        args.sample_size
    ]

    base_save_path = os.path.join(
        "results",
        SAMPLE_FOLDER
    )

    raw_base_path = os.path.join(
        "raw_outputs",
        SAMPLE_FOLDER
    )

    personas = get_personas(
        data_path
    )

    if args.max_egos is not None:
        personas = personas[
            :args.max_egos
        ]

    run_llm_network_pairwise(
        personas,
        base_save_path=base_save_path,
        raw_base_path=raw_base_path,
        llm_batch_size=LLM_BATCH_SIZE
    )
