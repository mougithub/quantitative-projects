-- =====================================================================
-- 01_schema_and_data.sql
-- Credit-risk scoring model: tables, persona inputs, model parameters
-- Dialect: SQLite 3.25+ (window functions). Portable to PostgreSQL with
-- minor changes (noted where relevant).
--
-- Source of persona inputs: fictional client profiles from the Goldman
-- Sachs Risk Virtual Experience on Forage. Persona 4 income is shown in
-- the task brief as "$150,00"; it is assumed to be $150,000 here.
-- =====================================================================

DROP TABLE IF EXISTS personas;
CREATE TABLE personas (
    persona_id     INTEGER PRIMARY KEY,
    persona_name   TEXT    NOT NULL,
    annual_income  INTEGER NOT NULL,   -- USD per year
    credit_score   INTEGER NOT NULL,   -- 300-850 scale
    debt           INTEGER NOT NULL,   -- USD
    savings        INTEGER NOT NULL,   -- USD
    late_payments  INTEGER NOT NULL,   -- count
    profile        TEXT                -- one-line summary (own wording)
);

INSERT INTO personas VALUES
    (1, 'Persona 1', 280000, 760, 150000, 450000, 0, 'Entrepreneur diversifying after a business exit'),
    (2, 'Persona 2', 180000, 700, 100000, 120000, 1, 'Mid-career professional planning a home purchase'),
    (3, 'Persona 3', 100000, 660,  90000,  20000, 2, 'IT consultant consolidating debt after setbacks'),
    (4, 'Persona 4', 150000, 720, 200000,  80000, 1, 'Seasonal-income business owner with expansion debt');

-- ---------------------------------------------------------------------
-- Model parameters (one row). Change a value here and every view updates.
--   w_*        : factor weights (should sum to 1.0)
--   *_cap      : value at which a factor is treated as "maxed out" (100)
--   high_max   : score <= this  -> High Risk
--   medium_max : score <= this  -> Medium Risk, otherwise Low Risk
-- Score direction: HIGHER SCORE = SAFER BORROWER.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS model_params;
CREATE TABLE model_params (
    w_credit REAL, w_income REAL, w_debt REAL, w_savings REAL, w_late REAL,
    credit_min REAL, credit_max REAL,
    income_cap REAL, debt_cap REAL, savings_cap REAL, late_cap REAL,
    high_max REAL, medium_max REAL
);

INSERT INTO model_params VALUES
    (0.25, 0.20, 0.20, 0.25, 0.10,
     300, 850,
     300000, 300000, 500000, 5,
     33, 66);
