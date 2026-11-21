# Methodology — HIES 2022 Household Yearly Income

This note explains every choice made in [`code/HIES2022_INCOME.do`](../code/HIES2022_INCOME.do):
which questionnaire item feeds each variable, what recall period it covers, what arithmetic is applied, and why.
Every variable name, item code and identity cited here was checked against the raw HIES 2022 files and the
English questionnaire.

---

## 1. Definition of income

BBS defines household income as the sum of the earnings of all household members, in cash or in kind, over a
given period (HIES 2022 Report, Glossary). Three rules follow and are applied throughout:

| Principle | Consequence |
|---|---|
| **Cash and in-kind both count** | In-kind wages, own-consumed crops/livestock/fish, in-kind gifts and in-kind safety-net goods are valued and included. |
| **Income ≠ receipts** | Turning existing wealth into cash (selling land, selling a cow, drawing down savings, taking a loan) is **not** income. |
| **Reference period = last 12 months** | Every component ends up on a 12-month basis; any other recall period is converted explicitly. |

```
HH yearly income = A. Wage & salary employment       (Section 4)
                 + B. Net agricultural income         (Sections 7B–7E)
                 + C. Net non-farm enterprise income  (Section 5)
                 + D. Property, transfer & other      (Sections 8B, 8C, 1C)
```

---

## 2. Universe, identifiers and weights

| Item | Decision | Why |
|---|---|---|
| Unit | One row = one household | — |
| Key | `PSU` + `HHID` | Unique in `HH_SEC_1A` (14,395 rows). No string `uid` is needed. |
| Universe | All 14,395 households in `HH_SEC_1A` | Every module is merged **onto** this roster. A household with no farm gets `agri_income = 0`, not a missing value or a dropped row. (`HH_SEC_8B` alone has only 14,265 rows.) |
| Household size | `MEMBER` in `HH_SEC_1A` | Already the member count. |
| Weights | `hh_wgt` (household means), `pop_wgt` (per-capita means), from `weight_final_2022.dta` | `svyset PSU [pw=hh_wgt], strata(stratum16)` |
| Urban/rural | `urbrural`: **1 = Rural, 2 = Urban** | Verified against `domain16` parity (odd = rural). |
| Missing → 0 | Only after the roster merge, only for money columns | A blank means the skip pattern never asked the question, i.e. the household had no such income. |
| Blank key rows | Dropped in every module | `HH_SEC_7D.dta` ends in two fully blank records that would otherwise create a phantom household. |

---

## 3. Component A — Wage and salary (Section 4)

**File:** `HH_SEC_4A.dta` — one row per economic activity of one person.

### 3.1 Which activities count here
Employment status is Q7 (agriculture) or Q8 (non-agriculture), same code list:

```
1 Day labourer  -> Part B wage questions   (counted here)
2 Self employed -> Section 5 / Section 7   (counted there)
3 Employer      -> Section 5 / Section 7   (counted there)
4 Employee      -> Part B wage questions   (counted here)
```
Counting status 2 and 3 here would double-count income measured in Sections 5 and 7.

### 3.2 Annualisation
Q9 (*paid on a daily basis?*) splits workers into two exclusive branches.

**Daily-rated (`s4bq09 == 1`)** — a chain of unit conversions, Tk/day × days/month × months:
```
wage_cash   = s4bq10c × s4aq03 × s4aq02
wage_inkind = s4bq13b × s4aq03 × s4aq02      if s4bq11 == 1
```
`s4bq10c` is the reported **average** daily wage (never missing in the kept sample). `s4aq02` is months worked
in the last 12, so seasonal work is handled by construction.

**Salaried (`s4bq09 == 2`)**
```
salary_cash   = s4bq15 × s4aq02      (gross monthly pay × months actually worked)
salary_inkind = s4bq17               (already a 12-month total — not multiplied again)
```
- Multiply by months worked, **not by 12**, or every partial-year job is inflated.
- `s4bq17` (bonuses, tips, transport for the year) is already annual.
- **Gross** (`s4bq15`) rather than net (`s4bq16`): tax and provident-fund deductions are a use of income.

Activities are summed straight to household level with one `collapse (sum) …, by(PSU HHID)`.

---

## 4. Component B — Net agriculture (Sections 7B–7E)

```
agri_income = crop + livestock + animal products + fish + forestry + asset rental − input costs
```

### 4.1 Crops — `HH_SEC_7B`
`s7bq04a` = kg produced, `s7bq04b` = **price per kg** (e.g. Boro paddy median Tk 25/kg), so value = quantity × price.
The form's identity **4 = 5 + 6 + 7 + 8** holds in 100% of rows, which allows a clean split of uses:

| Column | Use | Counted? |
|---|---|---|
| `s7bq05` | consumed by household | ✔ in-kind income |
| `s7bq06` | sold | ✔ |
| `s7bq07` | stored | ✔ produced this year |
| `s7bq08a` | given to landlord | ✘ land rent paid in kind (a cost) |
| `s7bq08b` | given as wages | ✘ labour paid in kind (a cost) |
| `s7bq08c` | seed | ✘ intermediate input |
| `s7bq08d` | animal feed | ✘ reappears as livestock output |
| `s7bq08e` | waste | ✘ never realised |
| `s7bq08f` | other | ✔ |

```
crop_income_net   = (s7bq05 + s7bq06 + s7bq07 + s7bq08f) × s7bq04b     <- headline
crop_income_gross =  s7bq04a × s7bq04b                                  <- sensitivity
```

### 4.2 Livestock — `HH_SEC_7C1` (all columns are total Taka values)
```
livestock_income = S7C1Q04B (died/sold) + S7C1Q05B (consumed) − S7C1Q03B (born/bought)
```
`S7C1Q02B` (animals owned now) is wealth and excluded. **Limitation:** the questionnaire merges born with bought
and died with sold, so births are netted like purchases and deaths counted like sales. The two biases run in
opposite directions and cannot be separated in this data.

### 4.3 Livestock products — `HH_SEC_7C2`
`S7C2Q06B` (value produced) only. Q7 (sold) and Q8 (consumed) split the same output; adding them would triple-count.

Meat codes 211/212/213 may duplicate live-animal disposals in 7C1 (median ratio of the two values is 1.00 across
1,636 households). The headline keeps both (closer to BBS practice); `hh_income_annual_altD3` drops meat for
households that also report animal disposals.

### 4.4 Fish — `HH_SEC_7C3`: `S7C3Q10B` (value produced/caught) only.
### 4.5 Forestry — `HH_SEC_7C4`: `S7C4Q15` (sold) + `S7C4Q16` (consumed). Trees owned = wealth, excluded.
### 4.6 Farm asset rental — `HH_SEC_7E`: `S7EQ04` (rental earnings). Asset values, purchases and sales excluded.

### 4.7 Input costs — `HH_SEC_7D`
`agri_input_costs = Σ S7DQ03B` over all items (seed, fertiliser, feed, irrigation, land rent, hired labour, …).
Section 7D never says which crop or animal a cost belongs to, so costs are netted **once, at household level**.

The questionnaire's "total" summary rows (codes 210, 220, 230, 240, 330) are **not stored** in the data — the code
checks this — so `collapse (sum)` does not double-count.

**Negative farm income.** Genuine losses are kept. Households that report costs but **no output at all** are a
reporting gap rather than a real loss, so only those (flag `flag_agri_costs_no_output`) are set to zero.

---

## 5. Component C — Non-farm enterprise (Section 5)

The form prints the arithmetic under column 20: **net revenue = 13 − (14 + 15 + 16 + 17 + 18 + 19)**.
`s5q20` reproduces this in 99.93% of enterprises and is already a 12-month figure, so it is used directly.

Household share of profit: `s5q07` (profit share), else `s5q06` (ownership share), else 100%, with an
`inrange(1,100)` guard because out-of-range zeros exist.
```
enterprise_income = s5q20 × share / 100
```
**Losses are kept.** Excluded: `s5q21` (capital spending), `s5q22` (asset sales), `s5q23` (what the business would sell
for — a valuation, not income).

---

## 6. Component D — Property, transfers, remittances, safety net

### 6.1 Section 8B (all items already "past 12 months")
| Variable | Item | Group |
|---|---|---|
| `S8BQ01`, `S8BQ02` | rent from land / other property | property |
| `S8BQ08`, `S8BQ09` | remittances, domestic / abroad | remittances |
| `S8BQ03A–C`, `S8BQ04`–`S8BQ07`, `S8BQ11`–`S8BQ13` | insurance, dividends, lottery, gifts/zakat (cash & kind), gratuity, interest, other | other transfers |

`S8BQ10` is a code (where money was spent), not an amount — excluded. The form instructs respondents not to repeat
income already reported elsewhere, so 8B can be added on top of Sections 4, 5 and 7.

### 6.2 Section 1C — social safety net
Use **Q10** (`S1CQ10A + S1CQ101D + S1CQ102D`), the amount received in the **last 12 months**. Q5 is the last payment and
Q9 the entitlement for the last payment; Q10 averages 4.7× Q9 where both exist, as expected.

### 6.3 Remittances — reconciling 8B and 8C
Section 8C records per-migrant cash (`S8CQ15`) and goods (`S8CQ18`) over **two years**, so they are divided by 2.
(`S8CQ17A/B/C` are goods codes, not Taka.)

| Households reporting remittances | n |
|---|---:|
| 8B only | 1,704 |
| 8C only | 945 |
| both | 1,056 |

Rule: **use 8B; fall back to 8C only where 8B is zero.** Adding both double-counts 1,056 households; ignoring 8C
loses 945. `flag_remit_source` records the source used.

### 6.4 Excluded
- `HH_SEC_8A` — asset values, purchases and asset-sale proceeds (wealth, not income).
- `HH_SEC_8D1/8D2` — loans are liabilities.
- `S8CQ19*` — how remittances were spent.

---

## 7. Sections reviewed and found to carry no income

1A/1B/1R (roster, migration), 2 (education — stipends are already in 1C), 3 (health), 6A (housing: tenure only),
6B (shocks), 7A (land area), 9 (consumption), 10 (food security).

**Known gaps of the instrument:** there is no question on the rental value of owner-occupied housing (so no imputed
rent) and no dedicated question on regular pensions. Both push this estimate slightly below BBS's published figure.

---

## 8. Judgement calls

| # | Decision | Headline choice | Alternative (reported in log, part F8) |
|---|---|---|---|
| D1 | Crop output | net of in-kind rent/wages, seed, feed, waste | full production × price |
| D2 | Costs but no farm output | set to zero for those households only | leave negative |
| D3 | Meat (7C2) vs live animals (7C1) | keep both | de-duplicate |
| D4 | Salary | gross | net take-home |

---

## 9. Common pitfalls in HIES 2022 income code

Mistakes that are easy to make with this dataset, all avoided here:

1. Treating `s5q23` (sale value of the enterprise) as enterprise income.
2. Using safety-net Q9 (one payment) instead of Q10 (12 months).
3. Summing `S8CQ17A` (a goods code) as remittance Taka.
4. Multiplying salary by 12 instead of months worked, or multiplying the annual `s4bq17` again.
5. Counting only sold + consumed crops (misses ~22% of output).
6. Setting enterprise or farm losses to zero.
7. Labelling `urbrural` as 1 = Urban (it is **1 = Rural**).
8. Adding livestock-product Q6 + Q7 + Q8 (same output three times).
9. Using `HH_SEC_8B` as the base file (130 households drop out).

---

## 10. Final aggregation

```stata
hh_income_annual     = wage_salary + agriculture + enterprise + property_transfer
hh_income_monthly    = hh_income_annual / 12
hh_income_pc_annual  = hh_income_annual / MEMBER
hh_income_pc_monthly = hh_income_annual / (12 * MEMBER)
```
Dividing by 12 is presentation only; the measure is the 12-month total.
