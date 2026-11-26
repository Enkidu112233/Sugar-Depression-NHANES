# Validation

The default analysis, rebuild-only workflow, and full rebuild-and-analysis workflow returned code 0 in Stata/MP 18 on Windows. The tests used repository paths containing spaces. The analysis tests deliberately ran the old installed copy of `gologit2` first, then the entry loaded `gologit2` and `gsvy` 3.2.8 from the repository. Both analysis routes finished the fourth robustness check and both sets of 2,000 bootstrap replications. The executable lines in the distributed scripts match the tested copies after the comment translation.

The supplied cycle files have 9,254 and 11,933 records. The pooled file has 21,187 records and 24 variables. All 18 raw test inputs matched their manifest hashes. Rebuilt records, row order, values, and storage dtypes matched the supplied datasets. The three packaged DTA files also match the supplied files byte-for-byte. File metadata and display formats were outside the rebuilt-data comparison.

The six output datasets agreed across the two analysis routes to numerical tolerance and each produced its CSV counterpart. The main analysis subpopulations were 1,340, 988, and 2,328. The fourth model used 2,328 records in the analytic subpopulation. The four sugar coefficients are shown below as a check against the exported estimates.

| PHQ-9 threshold | Log-odds coefficient | Standard error | p-value |
|---|---:|---:|---:|
| ≥5 | 0.0018569 | 0.0015023 | 0.2260 |
| ≥10 | 0.0025507 | 0.0015196 | 0.1036 |
| ≥15 | 0.0032011 | 0.0017622 | 0.0793 |
| ≥20 | 0.0025958 | 0.0027333 | 0.3499 |

The result checks establish agreement between these execution routes. They do not evaluate the scientific specifications or compare against typeset manuscript tables.
