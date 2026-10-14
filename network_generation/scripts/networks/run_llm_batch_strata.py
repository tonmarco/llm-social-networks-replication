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

parser.add_argument(
    "--model_name",
    type=str,
    default=None
)

parser.add_argument(
    "--batch_size",
    type=int,
    default=128
)

parser.add_argument(
    "--sample_size",
    type=str,
    default="100",
    choices=["100", "200", "300"]
)

args = parser.parse_args()

SAMPLE_FOLDER = f"sample_{args.sample_size}_v3"


# =====================================================
# CONFIG
# =====================================================

if args.model_name:

    MODELS = [
        args.model_name
    ]

else:

    MODELS = [
        "meta-llama/Llama-3.1-8B-Instruct",
        "Qwen/Qwen2.5-7B-Instruct",
        "mistralai/Mistral-7B-Instruct-v0.3"
    ]


LLM_BATCH_SIZE = args.batch_size

TEMPERATURES = [
    0.1,
    0.7
]

CANDIDATE_CHUNKS = [
    5,
    10,
    25,
    50
]


# Maximum generation length according to chunk size.
#
# The expected response contains only comma-separated IDs.
# Smaller chunks therefore require much shorter outputs.
MAX_TOKENS_BY_CHUNK = {
    5: 32,
    10: 48,
    25: 96,
    50: 160
}


N_RUNS = 10


DATASETS = {

    "100":
        "/app/data/anes_100.csv",

    # "200":
    #     "/app/data/anes_200.csv",

    # "300":
    #     "/app/data/anes_300.csv"
}


TRAIT_COMBOS = [

    [
        "vote",
        "religion",
        "age",
        "location",
        "education",
        "race",
        "gender"
    ],

    [
        "gender",
        "race",
        "education",
        "location",
        "age",
        "religion",
        "vote"
    ]

]


# =====================================================
# LOGGING
# =====================================================

def log(msg, log_file):

    timestamp = datetime.now().strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    full = f"[{timestamp}] {msg}"

    print(full)

    with open(
        log_file,
        "a"
    ) as f:

        f.write(
            full + "\n"
        )


# =====================================================
# RESPONSE PARSER
# =====================================================

def extract_ids(
    resp,
    valid_ids
):

    """
    Parse selected candidate IDs conservatively.

    Returns
    -------
    ids : set[str]

        Candidate IDs interpreted as selected.

    status : str

        valid
            Response exactly follows the requested format.

        recoverable
            Response contains a clearly identifiable selection,
            for example:
            "IDs should be 4255, 471"

        empty
            Empty response.

        malformed
            Response is ambiguous. No ties are added.
    """


    # -------------------------------------------------
    # EMPTY RESPONSE
    # -------------------------------------------------

    if not resp:

        return (
            set(),
            "empty"
        )


    resp = resp.strip()


    if not resp:

        return (
            set(),
            "empty"
        )


    # -------------------------------------------------
    # VALID FORMAT
    #
    # Examples:
    #
    # 4255
    #
    # 4255,471
    #
    # 4255, 471, 3012
    # -------------------------------------------------

    if re.fullmatch(
        r"\d+(?:\s*,\s*\d+)*",
        resp
    ):

        ids = (
            set(
                re.findall(
                    r"\d+",
                    resp
                )
            )
            & valid_ids
        )

        return (
            ids,
            "valid"
        )


    # -------------------------------------------------
    # RECOVERABLE FORMAT
    #
    # Example:
    #
    # IDs should be 4255, 471 - 3012 is excluded...
    #
    # IDs must be 2500, 4684, 5134.
    #
    # Only the IDs immediately following
    # "IDs should/must/would be" are extracted.
    # -------------------------------------------------

    match = re.search(

        r"\bIDs?\s+"
        r"(?:should|must|would)\s+"
        r"be\s*[:\-]?\s*"
        r"(\d+(?:\s*,\s*\d+)*)",

        resp,

        flags=re.IGNORECASE
    )


    if match:

        ids = (
            set(
                re.findall(
                    r"\d+",
                    match.group(1)
                )
            )
            & valid_ids
        )

        return (
            ids,
            "recoverable"
        )


    # -------------------------------------------------
    # MALFORMED RESPONSE
    #
    # Do NOT extract all numbers appearing anywhere
    # in the response.
    #
    # Otherwise:
    #
    # "4255 selected, 3012 excluded"
    #
    # would incorrectly create both ties.
    # -------------------------------------------------

    return (
        set(),
        "malformed"
    )


# =====================================================
# LOAD PERSONAS
# =====================================================

def get_personas(
    csv_file
):

    df = pd.read_csv(
        csv_file
    )


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


    df = (
        df[
            required
        ]
        .dropna()
        .reset_index(
            drop=True
        )
    )


    return df.to_dict(
        orient="records"
    )


# =====================================================
# DESCRIPTION HELPERS
# =====================================================

T_ALTER = {

    "age":
        lambda p:
        f"{p['profile_age']}-year-old",

    "gender":
        lambda p:
        p["profile_gender"],

    "race":
        lambda p:
        p["profile_racethnicity"],

    "location":
        lambda p:
        f"living in {p['profile_state']}",

    "education":
        lambda p:
        p["profile_educ5"],

    "religion":
        lambda p:
        p["profile_relig"],

    "vote":
        lambda p:
        p["w2presvtwho"]
}


def build_ego(
    p,
    traits
):

    return (
        "You are "
        +
        ", ".join(
            T_ALTER[t](p)
            for t in traits
        )
        +
        "."
    )


def build_alter(
    p,
    traits
):

    return ", ".join(

        T_ALTER[t](p)

        for t in traits
    )


# =====================================================
# LLM CHAT CALL
# =====================================================

def vllm_chat(
    prompts,
    sampling_params,
    llm
):

    """
    Run prompts as proper chat conversations.

    Important:
    These are instruction-tuned models, so we use llm.chat()
    instead of passing raw strings directly to llm.generate().

    vLLM will apply the model's chat template.
    """


    conversations = [

        [
            {
                "role": "user",
                "content": prompt
            }
        ]

        for prompt in prompts
    ]


    outputs = llm.chat(

        messages=conversations,

        sampling_params=sampling_params,

        use_tqdm=False
    )


    responses = []


    for output in outputs:

        if output.outputs:

            responses.append(
                output.outputs[
                    0
                ].text.strip()
            )

        else:

            responses.append(
                ""
            )


    return responses


# =====================================================
# NETWORK GENERATOR
# =====================================================

def run_llm_network_list(

    personas,

    base_save_path,

    raw_base_path,

    llm_batch_size=128
):


    os.makedirs(
        base_save_path,
        exist_ok=True
    )


    os.makedirs(
        raw_base_path,
        exist_ok=True
    )


    global_log = os.path.join(
        base_save_path,
        "progress_batch.log"
    )


    N = len(
        personas
    )


    total_runs = (

        len(MODELS)

        * len(TEMPERATURES)

        * len(TRAIT_COMBOS)

        * len(CANDIDATE_CHUNKS)

        * N_RUNS
    )


    current_run = 0


    log(
        f"Total personas: {N}",
        global_log
    )


    log(
        f"Total runs: {total_runs}",
        global_log
    )


    # =================================================
    # MODELS
    # =================================================

    for model_name in MODELS:


        model_tag = (

            model_name
            .split("/")[-1]
            .replace(".", "")
            .lower()
        )


        model_dir = os.path.join(

            base_save_path,

            model_tag
        )


        os.makedirs(
            model_dir,
            exist_ok=True
        )


        raw_model_dir = os.path.join(

            raw_base_path,

            model_tag
        )


        os.makedirs(
            raw_model_dir,
            exist_ok=True
        )


        model_log = os.path.join(

            model_dir,

            "progress.log"
        )


        log(
            f"Starting model: {model_name}",
            model_log
        )


        llm = LLM(

            model=model_name,

            tensor_parallel_size=1,

            gpu_memory_utilization=0.90,

            max_model_len=2048,

            enforce_eager=False,

            swap_space=16
        )


        # =============================================
        # TEMPERATURE
        # =============================================

        for temp in TEMPERATURES:


            # =========================================
            # ATTRIBUTE ORDER
            # =========================================

            for traits in TRAIT_COMBOS:


                ego_cache = {

                    p["caseid"]:

                        build_ego(
                            p,
                            traits
                        )

                    for p in personas
                }


                # =====================================
                # CHUNK SIZE
                # =====================================

                for chunk_size in CANDIDATE_CHUNKS:


                    # =================================
                    # RUN
                    # =================================

                    for run in range(
                        N_RUNS
                    ):


                        current_run += 1


                        start_time = time.time()


                        # ---------------------------------
                        # SAMPLING PARAMETERS
                        # ---------------------------------

                        sampling_params = SamplingParams(

                            temperature=temp,

                            top_p=1.0,

                            max_tokens=
                                MAX_TOKENS_BY_CHUNK[
                                    chunk_size
                                ],

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


                        # ---------------------------------
                        # START FRESH RAW FILE
                        # ---------------------------------

                        with open(
                            raw_path,
                            "w"
                        ):

                            pass


                        log(

                            f"RUN "
                            f"{current_run}/"
                            f"{total_runs} | "
                            f"{run_id}",

                            model_log
                        )


                        adj = defaultdict(
                            set
                        )


                        resp_counter = Counter()


                        parse_counter = Counter()


                        # =================================
                        # EGOS
                        # =================================

                        for idx, ego in enumerate(
                            personas
                        ):


                            if idx % 50 == 0:

                                log(

                                    f"Ego "
                                    f"{idx}/"
                                    f"{N}",

                                    model_log
                                )


                            ego_id = ego[
                                "caseid"
                            ]


                            ego_desc = ego_cache[
                                ego_id
                            ]


                            prompts = []

                            chunk_meta = []


                            others = (

                                personas[
                                    :idx
                                ]

                                +

                                personas[
                                    idx + 1:
                                ]
                            )


                            # =============================
                            # ALTER CHUNKS
                            # =============================

                            for i in range(

                                0,

                                len(others),

                                chunk_size
                            ):


                                alters = others[
                                    i:
                                    i + chunk_size
                                ]


                                alters_text = "\n".join(

                                    (
                                        f"ID "
                                        f"{a['caseid']}: "
                                        f"{build_alter(a, traits)}"
                                    )

                                    for a in alters
                                )


                                # ---------------------------------
                                # SIMPLIFIED PROMPT
                                #
                                # No bullet list in the output
                                # instructions, because Llama was
                                # continuing the bullet pattern.
                                # ---------------------------------

                                prompt = (

                                    f"{ego_desc}\n\n"

                                    "Here is a list of people:\n\n"

                                    f"{alters_text}\n\n"

                                    "Select who you would befriend. "

                                    "Answer only with the selected "
                                    "IDs separated by commas, "

                                    "for example: 123,456,789. "

                                    "Do not provide explanations, "
                                    "reasoning, names, or any other "
                                    "text."
                                )


                                prompts.append(
                                    prompt
                                )


                                chunk_meta.append(
                                    alters
                                )


                                # =========================
                                # FULL BATCH
                                # =========================

                                if (
                                    len(prompts)
                                    ==
                                    llm_batch_size
                                ):


                                    responses = vllm_chat(

                                        prompts,

                                        sampling_params,

                                        llm
                                    )


                                    with open(
                                        raw_path,
                                        "a"
                                    ) as raw_f:


                                        for (

                                            prompt_text,

                                            resp,

                                            alters_batch

                                        ) in zip(

                                            prompts,

                                            responses,

                                            chunk_meta
                                        ):


                                            valid_ids = {

                                                str(
                                                    a[
                                                        "caseid"
                                                    ]
                                                )

                                                for a
                                                in alters_batch
                                            }


                                            (
                                                ids,
                                                parse_status
                                            ) = extract_ids(

                                                resp,

                                                valid_ids
                                            )


                                            parsed_ids = sorted(

                                                map(
                                                    int,
                                                    ids
                                                )
                                            )


                                            adj[
                                                ego_id
                                            ].update(
                                                parsed_ids
                                            )


                                            resp_counter[
                                                resp
                                            ] += 1


                                            parse_counter[
                                                parse_status
                                            ] += 1


                                            raw_record = {

                                                "run_id":
                                                    run_id,

                                                "model":
                                                    model_name,

                                                "temperature":
                                                    temp,

                                                "chunk_size":
                                                    chunk_size,

                                                "run":
                                                    run,

                                                "attribute_order":
                                                    "_".join(
                                                        traits
                                                    ),

                                                "ego_id":
                                                    int(
                                                        ego_id
                                                    ),

                                                "alter_ids":
                                                    [

                                                        int(
                                                            a[
                                                                "caseid"
                                                            ]
                                                        )

                                                        for a
                                                        in alters_batch
                                                    ],

                                                "raw_response":
                                                    resp,

                                                "parsed_ids":
                                                    parsed_ids,

                                                "parse_status":
                                                    parse_status,

                                                "prompt":
                                                    prompt_text
                                            }


                                            raw_f.write(

                                                json.dumps(

                                                    raw_record,

                                                    ensure_ascii=False
                                                )

                                                + "\n"
                                            )


                                    prompts = []

                                    chunk_meta = []


                            # =============================
                            # REMAINING PARTIAL BATCH
                            # =============================

                            if prompts:


                                responses = vllm_chat(

                                    prompts,

                                    sampling_params,

                                    llm
                                )


                                with open(
                                    raw_path,
                                    "a"
                                ) as raw_f:


                                    for (

                                        prompt_text,

                                        resp,

                                        alters_batch

                                    ) in zip(

                                        prompts,

                                        responses,

                                        chunk_meta
                                    ):


                                        valid_ids = {

                                            str(
                                                a[
                                                    "caseid"
                                                ]
                                            )

                                            for a
                                            in alters_batch
                                        }


                                        (
                                            ids,
                                            parse_status
                                        ) = extract_ids(

                                            resp,

                                            valid_ids
                                        )


                                        parsed_ids = sorted(

                                            map(
                                                int,
                                                ids
                                            )
                                        )


                                        adj[
                                            ego_id
                                        ].update(
                                            parsed_ids
                                        )


                                        resp_counter[
                                            resp
                                        ] += 1


                                        parse_counter[
                                            parse_status
                                        ] += 1


                                        raw_record = {

                                            "run_id":
                                                run_id,

                                            "model":
                                                model_name,

                                            "temperature":
                                                temp,

                                            "chunk_size":
                                                chunk_size,

                                            "run":
                                                run,

                                            "attribute_order":
                                                "_".join(
                                                    traits
                                                ),

                                            "ego_id":
                                                int(
                                                    ego_id
                                                ),

                                            "alter_ids":
                                                [

                                                    int(
                                                        a[
                                                            "caseid"
                                                        ]
                                                    )

                                                    for a
                                                    in alters_batch
                                                ],

                                            "raw_response":
                                                resp,

                                            "parsed_ids":
                                                parsed_ids,

                                            "parse_status":
                                                parse_status,

                                            "prompt":
                                                prompt_text
                                        }


                                        raw_f.write(

                                            json.dumps(

                                                raw_record,

                                                ensure_ascii=False
                                            )

                                            + "\n"
                                        )


                        # =================================
                        # SAVE NETWORK
                        # =================================

                        with open(
                            out_path,
                            "w"
                        ) as f:


                            for p in personas:


                                eid = p[
                                    "caseid"
                                ]


                                neighbors = (

                                    sorted(
                                        adj[eid]
                                    )

                                    if eid in adj

                                    else []
                                )


                                f.write(

                                    f"{eid}: "

                                    f"{','.join(map(str, neighbors))}"

                                    f"\n"
                                )


                        elapsed = (

                            time.time()

                            -

                            start_time
                        )


                        log(

                            f"Saved "
                            f"{out_path} | "
                            f"{elapsed / 60:.1f} min",

                            model_log
                        )


                        log(

                            f"Saved raw outputs: "
                            f"{raw_path}",

                            model_log
                        )


                        log(

                            f"Top responses: "
                            f"{resp_counter.most_common(5)}",

                            model_log
                        )


                        log(

                            f"Parse status counts: "
                            f"{dict(parse_counter)}",

                            model_log
                        )


        log(

            f"Finished model: "
            f"{model_name}",

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


    run_llm_network_list(

        personas,

        base_save_path=
            base_save_path,

        raw_base_path=
            raw_base_path,

        llm_batch_size=
            LLM_BATCH_SIZE
    )