from pathlib import Path

import numpy as np
import pandas as pd


BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "outputs" / "data"
TABLE_DIR = BASE_DIR / "code" / "tables"
MIN_PERSONAS = 5

MODEL_ORDER = [
    "Llama-3.1 8B",
    "Mistral 7B",
    "Qwen2.5 7B",
    "Llama-3.1 70B AWQ",
    "Qwen2.5 72B AWQ",
]
ATTRIBUTE_ORDER = [
    "Race/ethnicity",
    "Vote choice",
    "Age group",
    "Education",
    "Religion",
    "Region",
    "Gender",
]
CATEGORY_ORDER = {
    "Race/ethnicity": ["black", "hispanic", "white", "ethnic minority"],
    "Vote choice": ["Democrat", "Republican", "didn't vote", "Independent"],
    "Age group": ["18-29", "30-44", "45-59", "60-74", "75+"],
    "Education": [
        "less than high school",
        "high school graduate",
        "vocational tech school",
        "bachelor's degree",
        "postgraduate",
    ],
    "Religion": [
        "Protestant",
        "Roman Catholic",
        "just Christian",
        "not religious",
        "atheist",
        "agnostic",
        "believer in a minority religion",
    ],
    "Region": ["Northeast", "Midwest", "South", "West"],
    "Gender": ["female", "male"],
}


def standard_error(values):
    values = pd.to_numeric(values, errors="coerce").dropna()
    return values.std(ddof=1) / np.sqrt(len(values)) if len(values) > 1 else np.nan


def build_vote_configuration_summary():
    exposure_columns = [
        "network_view",
        "model_label",
        "temperature",
        "method",
        "attr_label",
        "party",
        "run_id",
        "caseid",
        "llm_cat",
        "survey_cat",
    ]
    exposure = pd.read_csv(
        DATA_DIR / "local_evaluation_exposure_long_sample_100_v3_by_network_view.csv",
        usecols=exposure_columns,
    )
    exposure = exposure[exposure["network_view"].eq("directed_out")].copy()
    survey = pd.read_csv(
        BASE_DIR / "data" / "anes_100.csv",
        encoding="mac_roman",
        usecols=["caseid", "w2presvtwho"],
    )
    vote = exposure.merge(survey, on="caseid", how="left", validate="many_to_one")
    vote["signed_error"] = vote["llm_cat"] - vote["survey_cat"]
    vote["valid_pair"] = vote[["llm_cat", "survey_cat"]].notna().all(axis=1)

    run_keys = [
        "model_label",
        "temperature",
        "method",
        "attr_label",
        "party",
        "w2presvtwho",
        "run_id",
    ]
    run_level = (
        vote.groupby(run_keys, observed=True, dropna=False)
        .agg(
            run_n_valid_personas=("valid_pair", "sum"),
            run_mean_signed_error=("signed_error", "mean"),
            n_personas_total=("caseid", "nunique"),
        )
        .reset_index()
    )
    config_keys = [
        "model_label",
        "temperature",
        "method",
        "attr_label",
        "party",
        "w2presvtwho",
    ]
    vote_config = (
        run_level.groupby(config_keys, observed=True, dropna=False)
        .agg(
            mean_valid_personas=("run_n_valid_personas", "mean"),
            mean_signed_error=("run_mean_signed_error", "mean"),
            n_personas_total=("n_personas_total", "max"),
        )
        .reset_index()
        .rename(columns={"w2presvtwho": "category"})
    )
    vote_config["attribute_label"] = "Vote choice"
    return vote_config


def latex_escape(value):
    return str(value).replace("&", r"\&").replace("%", r"\%")


def main():
    demographic = pd.read_csv(
        DATA_DIR / "demographic_exposure_error_by_category_sample_100_v3_by_network_view.csv"
    )
    demographic = demographic[demographic["network_view"].eq("directed_out")].copy()
    config_columns = [
        "model_label",
        "temperature",
        "method",
        "attr_label",
        "party",
        "attribute_label",
        "category",
        "mean_valid_personas",
        "mean_signed_error",
        "n_personas_total",
    ]
    signed_config = pd.concat(
        [demographic[config_columns], build_vote_configuration_summary()[config_columns]],
        ignore_index=True,
    )
    signed_config = signed_config[
        signed_config["mean_valid_personas"].ge(MIN_PERSONAS)
    ].copy()

    group_keys = [
        "model_label",
        "temperature",
        "attribute_label",
        "category",
        "party",
    ]
    summary = (
        signed_config.groupby(group_keys, observed=True)
        .agg(
            n_personas=("n_personas_total", "max"),
            mean_msd=("mean_signed_error", "mean"),
            se_msd=("mean_signed_error", standard_error),
            n_configurations=("mean_signed_error", "count"),
        )
        .reset_index()
    )
    assert summary["n_personas"].ge(MIN_PERSONAS).all()
    assert summary["n_configurations"].eq(10).all()

    index_columns = ["model_label", "temperature", "attribute_label", "category"]
    dem = summary[summary["party"].eq("dem")][
        index_columns + ["n_personas", "mean_msd", "se_msd"]
    ].rename(columns={"mean_msd": "dem_msd", "se_msd": "dem_se"})
    rep = summary[summary["party"].eq("rep")][
        index_columns + ["mean_msd", "se_msd"]
    ].rename(columns={"mean_msd": "rep_msd", "se_msd": "rep_se"})
    table = dem.merge(rep, on=index_columns, how="inner", validate="one_to_one")

    attribute_rank = {value: index for index, value in enumerate(ATTRIBUTE_ORDER)}
    category_rank = {
        (attribute, category): index
        for attribute, categories in CATEGORY_ORDER.items()
        for index, category in enumerate(categories)
    }
    model_rank = {value: index for index, value in enumerate(MODEL_ORDER)}
    table["_attribute"] = table["attribute_label"].map(attribute_rank)
    table["_category"] = [
        category_rank.get((attribute, category), 999)
        for attribute, category in zip(table["attribute_label"], table["category"])
    ]
    table["_model"] = table["model_label"].map(model_rank)
    table = table.sort_values(
        ["_attribute", "_category", "_model", "temperature"]
    ).drop(columns=["_attribute", "_category", "_model"])

    csv_path = DATA_DIR / "table_S11_group_specific_exposure_errors_nomination.csv"
    table.to_csv(csv_path, index=False)

    caption = (
        r"\textbf{Complete group-specific errors in LLM-generated partisan exposure.} "
        r"Mean Signed Deviation (MSD) between LLM-generated and survey-reported exposure "
        r"to Democrats and Republicans in nomination networks for all demographic and "
        r"political groups with at least five personas. Values report model averages across "
        r"prompting methods and attribute orderings separately for each temperature, with "
        r"standard errors across configurations in parentheses. Positive values indicate "
        r"overestimation relative to the ANES survey, while negative values indicate "
        r"underestimation."
    )
    lines = [
        r"\begingroup",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\renewcommand{\arraystretch}{0.95}",
        r"\begin{longtable}{@{}lllp{2.8cm}rrr@{}}",
        rf"\caption{{{caption}}}\label{{tab:group_specific_exposure_errors}}\\",
        r"\toprule",
        "Model & $T$ & Attribute & Group & $N$ & Dem. exposure & Rep. exposure \\\\",
        r"\midrule",
        r"\endfirsthead",
        r"\multicolumn{7}{c}{\textbf{Table \thetable\ continued}}\\",
        r"\toprule",
        "Model & $T$ & Attribute & Group & $N$ & Dem. exposure & Rep. exposure \\\\",
        r"\midrule",
        r"\endhead",
        r"\midrule",
        r"\multicolumn{7}{r}{Continued on next page}\\",
        r"\endfoot",
        r"\bottomrule",
        r"\endlastfoot",
    ]
    for row in table.itertuples(index=False):
        dem_value = f"{row.dem_msd:.3f} ({row.dem_se:.3f})"
        rep_value = f"{row.rep_msd:.3f} ({row.rep_se:.3f})"
        lines.append(
            f"{latex_escape(row.model_label)} & {row.temperature:.1f} & "
            f"{latex_escape(row.attribute_label)} & {latex_escape(row.category)} & "
            f"{int(row.n_personas)} & {dem_value} & {rep_value} \\\\" 
        )
    lines.extend([r"\end{longtable}", r"\endgroup"])

    tex_path = TABLE_DIR / "table_S11_group_specific_exposure_errors.tex"
    tex_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Saved {tex_path.relative_to(BASE_DIR)} ({len(table)} rows)")
    print(f"Saved {csv_path.relative_to(BASE_DIR)}")


if __name__ == "__main__":
    main()
