# HIES 2022 Household Yearly Income (Bangladesh)

Stata code that rebuilds **household yearly income** from the raw microdata of the Bangladesh
**Household Income and Expenditure Survey (HIES) 2022**, carried out by the Bangladesh Bureau of Statistics (BBS).
Every income question in the questionnaire was read, matched to its variable, and checked against the data
before it went into the code.

**Headline result:** mean household income **Tk 30,040 per month** (Tk 360,478 per year). BBS publishes
Tk 32,422, which falls inside this estimate's 95% confidence interval. Per capita, the gap is 2.3%.

## What the code does

```
Household yearly income = A. Wage & salary            (Section 4)
                        + B. Net agriculture          (Sections 7B–7E)
                        + C. Non-farm enterprise      (Section 5)
                        + D. Property, transfers,     (Sections 8B, 8C, 1C)
                             remittances, safety net
```

- Everything is on a 12-month basis and merged onto the full roster of 14,395 households.
- Cash and in-kind income both count. Asset sales, asset values and loans do not, because they are not income.
- Built-in checks: unique keys, no missing components, accounting identities in the questionnaire, and a
  side-by-side comparison with the published BBS figures.
- Four judgement calls (crop measure, farm costs with no output, meat vs live animals, gross vs net salary)
  use a fixed headline choice, and every alternative is printed in the log.

Full reasoning, item by item: **[docs/METHODOLOGY.md](docs/METHODOLOGY.md)** · Numbers: **[docs/RESULTS.md](docs/RESULTS.md)**

## Repository layout

```
.
├── code/
│   └── HIES2022_INCOME.do     # the whole estimation in one file (parts A–F)
├── docs/
│   ├── METHODOLOGY.md         # variable-by-variable justification
│   └── RESULTS.md             # headline, composition, regions, BBS comparison
├── CITATION.cff
├── LICENSE
└── README.md
```

## How to run

1. **Get the data.** The HIES 2022 microdata are **not** included here. They belong to BBS and can be
   requested from BBS. You need these files in one folder:
   `HH_SEC_1A, 1C, 4A, 05, 7B, 7C1, 7C2, 7C3, 7C4, 7D, 7E, 8B, 8C` (`.dta`) and `weight_final_2022.dta`.
2. **Set two paths** at the top of `code/HIES2022_INCOME.do`:
   ```stata
   global raw  "C:/path/to/HIES-2022"             // folder with the .dta files
   global out  "C:/path/to/hies2022-income-output" // where results go
   ```
3. **Run** `do code/HIES2022_INCOME.do` in Stata 14 or newer (tested on StataMP 16.1). No user-written packages
   are needed.

### Outputs (written to `$out`)

| File | Contents |
|---|---|
| `hies2022_household_income.dta` / `.csv` | one row per household: every component, totals, per capita, quintile, decile, flags |
| `summary_composition.csv` | weighted mean of each income source |
| `summary_by_urbrural.csv`, `summary_by_division.csv` | regional means |
| `hies2022_income.log` | full log with every check |
| `work/` | intermediate file for each part, for inspection |

Key variables: `hh_income_annual`, `hh_income_monthly`, `hh_income_pc_annual`, `hh_income_pc_monthly`,
`wage_salary_income_annual`, `agri_income_annual`, `enterprise_income_annual`,
`property_transfer_income_annual`. In the CSV, `urbrural` is 1 = Rural, 2 = Urban.

## Known limitations

- No imputed rent for owner-occupied housing: the questionnaire never asks what the dwelling would rent for.
- No dedicated question on regular pensions.
- Livestock: births are grouped with purchases and deaths with sales in the questionnaire, so the two cannot
  be separated.

## Citation

If you use this code, please cite it. GitHub shows a "Cite this repository" button based on `CITATION.cff`.

> Rahman, A. (2026). *HIES 2022 Household Yearly Income: Stata code* [Computer software]. White Globe Initiative.

## Author

**Atikur Rahman**, Research Associate, White Globe Initiative ·
ORCID [0009-0000-2936-819X](https://orcid.org/0009-0000-2936-819X) · atik@whiteglobeinitiative.org

## License

The code is under the [MIT License](LICENSE). The HIES 2022 data remain the property of the Bangladesh Bureau of Statistics.
