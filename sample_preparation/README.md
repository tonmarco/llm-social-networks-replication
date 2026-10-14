# Sample preparation and EDA

These notebooks were copied from the project root and their stored execution
outputs were cleared.

1. `anes_downsampling.ipynb` loads
   `data/anes_specialstudy_2020-2022_socialmedia_csv_20230705.csv`, cleans the
   ANES fields, and draws the weighted stratified sample of 100 personas.
   It uses gender, age, race/ethnicity, and education strata and a fixed base
   seed of 42. It writes `data/anes_100.csv`.
2. `00_sample_eda.ipynb` describes the unweighted and weighted composition of
   the 100-person network sample and its composition by ego political
   affiliation. It reads `data/anes_100.csv`.

Run the notebooks from the replication-package root so their relative paths
resolve correctly.

The output naming reflects the original workflow: the stratified sample was
renamed to `anes_100.csv` before network generation. The packaged notebook writes
that downstream filename directly inside `data/`.
