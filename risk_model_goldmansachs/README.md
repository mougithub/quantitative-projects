# Client & Real Estate Risk Model

**Live demo:** Tableau Public: https://public.tableau.com/views/riskmodel/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link

Built on top of the Goldman Sachs Risk Virtual Experience (Forage). The original exercise provided a fixed calculator and four fictional personas; this workbook rebuilds the model from scratch, corrects a flaw found in the original scoring logic, and adds sensitivity analysis and a quantified real estate risk register.
An independent extension of the **Goldman Sachs Risk Virtual Experience** on
[Forage](https://www.theforage.com). The original exercise provided a fixed
Excel calculator and four fictional client personas, plus a qualitative Florida
real-estate risk scenario. This project rebuilds and extends that work:

- Corrects a flaw found in the original scoring model
- Adds a SQL version of the model, alongside the Excel version
- Runs a sensitivity analysis across realistic input ranges
- Quantifies the real estate scenario (probability × impact) instead of
  leaving it qualitative
- Visualizes all of it in an interactive dashboard, with a Tableau build guide

> **Credit:** original problem, personas, and scenario design belong to
> Goldman Sachs / Forage. No original Goldman Sachs or Forage files are
> redistributed here — everything in this repo was built from scratch based
> on the published task description.

## What's inside

| Folder | Contents |
|---|---|
| `sql/` | SQLite scripts: schema, credit scoring (original + corrected), sensitivity analysis, real estate risk register |
| `excel/` | `Risk_Model_Extended.xlsx` — the same model, in Excel, with formulas (not hardcoded values) |
| `data/` | CSV exports of every model output, ready to load into Tableau, Excel, or pandas |
| `dashboard/` | `index.html` — a self-contained interactive dashboard (open directly in a browser, or host it) |
| `TABLEAU_GUIDE.md` | Step-by-step instructions for building the Tableau dashboard from `data/*.csv` |

## The core finding: a flaw in the original model

The original calculator scores a client profile on credit score, income,
debt, savings, and late payments, then reads the total as *"higher score =
lower risk."* But it adds every factor the same way — including **debt** and
**late payments**. That means more debt and more missed payments *raise* the
score, which is backwards.

This project's **corrected model** inverts those two factors (`100 - value`)
before weighting them. For the four given personas, categories mostly hold,
but scores, rankings, and distance-to-boundary all shift — see
`sql/02_credit_scoring.sql` and the `Credit Risk` tab in the Excel file for
the side-by-side comparison.

## Sensitivity analysis

Each persona's five inputs were shifted one at a time, holding the others
constant, across a realistic range (±50% on financial values, ±100 credit
score points, 0–5 late payments). **Finding:** within that range, no single
input alone is enough to move any persona into a different risk category —
it takes several inputs moving together. Persona 3 sits closest to a
boundary (11.0 points above the High Risk line) and is the most exposed to a
combined shock. Full 200-scenario grid: `sql/03_sensitivity.sql` →
`data/sensitivity_scenarios.csv`.

## Real estate risk register

The qualitative Florida apartment-complex scenario (hurricane risk, property
tax, competition, seasonality, repairs) is quantified as an **expected
annual loss** (probability × dollar impact) per risk, ranked, and matched to
a mitigation strategy with its own annualized cost — so the cost of
mitigating a risk can be weighed against the exposure it reduces.
Probabilities, impacts, and costs are this project's own estimates for a
fictional scenario, not real market data. See `sql/04_real_estate_risk.sql`.

## Running it yourself

**SQL (SQLite):**
```bash
python3 - <<'PY'
import sqlite3
con = sqlite3.connect("risk_model.db")
for f in ["sql/01_schema_and_data.sql","sql/02_credit_scoring.sql",
          "sql/03_sensitivity.sql","sql/04_real_estate_risk.sql"]:
    con.executescript(open(f).read())
con.commit()
PY
```
(A plain `sqlite3 risk_model.db < sql/01_schema_and_data.sql` etc. works too
if you have the `sqlite3` CLI installed.)

**Excel:** open `excel/Risk_Model_Extended.xlsx` directly — every value is a
live formula, so editing an input or a weight on the `Model Params` tab
recalculates the whole model.

**Dashboard:** open `dashboard/index.html` in any browser. No server or
build step needed.


## Disclaimer

All personas, financial figures, probabilities, and mitigation costs are
fictional and illustrative, built for a learning exercise. This is not
Goldman Sachs data and does not reflect how Goldman Sachs actually performs
credit or real estate risk assessment.
