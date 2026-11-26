# NHANES 1127 replication package

Stata code and analysis data for dietary sugar intake and depressive symptoms in NHANES 2017–2018 and August 2021–August 2023. This package uses the six files supplied for the 1127 revision. It includes the three processed Stata datasets, two cleaning scripts, and the 1127 statistical analysis. It does not generate typeset manuscript tables. The analysis itself produces machine-readable summaries and estimates.

## Run with the included data

Use Stata 18. Extract the repository, then in Stata change to the folder that contains this README and run the master script. Replace the example location with the folder you actually extracted.

```stata
cd "C:/path/to/NHANES-1127-Replication"
do code/00_master.do
```

The script reads `data/processed/final_two_cycles.dta`. Look for `Entry completed.` at the end of `output/logs/analysis.log`. The analysis exports `estimates`, `bootstrap`, `profile`, `flow`, `selection`, and `cutoffs` as both DTA and CSV files in `output/analysis/`. The individual bootstrap summaries printed by Stata are in the log. In the supplied script, the `bootstrap` export contains the sleep pathway summary. The food-insecurity bootstrap is reported in the log.

The package includes an unmodified copy of Richard Williams's `gologit2` and `gsvy` version 3.2.8 in `vendor/gologit2/`. The master script uses this project-local copy and refreshes cached Stata commands before estimation. A separate installation, internet connection, machine-specific path, and manual `adopath`, `discard`, or `which` commands are unnecessary for this run. Keep the `vendor/` directory when copying or uploading the package. See [dependency attribution](vendor/gologit2/NOTICE.md).

## Rebuild from public NHANES files

Follow [the raw data guide](data/README.md) to download the 18 XPT files read by the cleaning scripts. Then run one of the following commands from the repository root.

| Command | Purpose |
|---|---|
| `do code/00_master.do rebuild` | Rebuilds both cycles and appends them. `do code/00_rebuild.do` is a shortcut. |
| `do code/00_master.do full` | Rebuilds and analyzes the regenerated pooled file. Outputs go to `output/full/`. |

The rebuilt data are written under `work/`. The pooled file is `work/2021_2023/final_two_cycles.dta`. Stata creates the working and output folders during a run. The prebuilt files in `data/processed/` serve as reference data. Raw inputs and generated outputs are local to each run. The cleaning scripts use double precision for newly created numeric data and the entry restores the caller's default storage type on exit from rebuild and full modes.

## Files and checks

- `code/00_master.do` runs the workflow. `code/04_statistical_analysis.do` is the adapted 1127 script.
- `data/processed/` contains the three supplied datasets. `2022final_analysis_data.dta` refers to August 2021–August 2023.
- `data/raw_manifest.csv` lists raw downloads, placement, and reference hashes.
- `vendor/gologit2/` contains the Stata extension required for the fourth robustness check.
- `docs/` contains the run validation, source attribution, upload instructions, and hashes of the supplied sources.

The code uses complete PHQ-9 responses, derives the sleep-excluded score from the same participants, and retains valid Day 1 dietary records for the Day 1 sensitivity analysis. It estimates the fourth robustness check with a survey-weighted partial proportional odds logit and allows the sugar coefficient to vary across PHQ-9 thresholds. See [validation](docs/VALIDATION.md) for the numerical checks and [source and rights](docs/PROVENANCE.md) for the status of the external analysis script.

For an optional file integrity check, run `python tools/verify_package.py` from the repository root. The `--raw` flag also checks the downloaded XPT files. Python is optional and the analysis itself runs in Stata.
