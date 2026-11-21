# Results

Run on StataMP 16.1. Weighted with `hh_wgt`; design `svyset PSU [pw=hh_wgt], strata(stratum16)`
(720 PSUs, 16 strata). Households: 14,395, representing about 39.2 million households.

## Headline

| | Annual (Tk) | Monthly (Tk) |
|---|---:|---:|
| **Mean household income** | **360,478** | **30,040** |
| Mean per capita income | 89,308 | 7,442 |
| Median household income | 210,552 | 17,546 |
| Median per capita income | 50,196 | 4,183 |

95% CI on mean monthly household income: Tk 27,360 – 32,720.

## Composition

| Source | Tk/year | Share |
|---|---:|---:|
| Wage & salary employment | 158,001 | 43.8% |
| Non-farm enterprise | 85,331 | 23.7% |
| Net agriculture | 52,323 | 14.5% |
| Remittances | 36,578 | 10.1% |
| Property rent | 15,346 | 4.3% |
| Other transfers | 8,301 | 2.3% |
| Social safety net | 4,599 | 1.3% |
| **Total** | **360,478** | **100%** |

## Urban / rural and division (monthly, Tk)

| | Household | Per capita |
|---|---:|---:|
| Rural | 23,689 | 5,826 |
| Urban | 43,537 | 10,877 |

| Division | Household | Per capita |
|---|---:|---:|
| Dhaka | 40,286 | 10,464 |
| Rajshahi | 32,197 | 7,893 |
| Chattogram | 31,311 | 7,183 |
| Barishal | 23,792 | 5,729 |
| Khulna | 23,773 | 6,085 |
| Sylhet | 20,825 | 4,425 |
| Mymensingh | 20,249 | 4,799 |
| Rangpur | 17,884 | 4,602 |

## Comparison with BBS (HIES 2022 Report, Key Findings)

| | This code | BBS | Diff |
|---|---:|---:|---:|
| National, monthly household | 30,040 | 32,422 | −7.3% |
| Rural, monthly household | 23,689 | 26,163 | −9.5% |
| Urban, monthly household | 43,537 | 45,757 | −4.9% |
| Monthly per capita | 7,442 | 7,614 | −2.3% |

The BBS national figure lies inside this estimate's 95% confidence interval. The remaining gap matches what the
questionnaire does not measure: imputed rent on owner-occupied housing and regular pensions.

## Sensitivity to the judgement calls (monthly mean, Tk)

| Specification | Mean | vs headline |
|---|---:|---:|
| **Headline** (D1 net, D2 floor, D3 keep, D4 gross) | **30,040** | — |
| D1: full production × price | 30,593 | +553 |
| D2: no floor for costs-without-output | 29,858 | −182 |
| D3: meat de-duplicated | 29,517 | −523 |
| D4: net salary | 29,409 | −631 |

## Data-quality flags

| Check | Count |
|---|---:|
| Duplicate `PSU`×`HHID` | 0 |
| Missing component after merge | 0 |
| Zero total income | 117 |
| Negative total income | 203 |
| Negative net agriculture | 1,196 |
| Farm costs but no output (set to 0) | 753 |
| Remittance from 8C fallback | 945 |

The whole specification was also re-implemented independently in Python from the same raw files; every
component matched the Stata output to the Taka.
