-- =====================================================================
-- 03_sensitivity.sql
-- One-at-a-time sensitivity analysis on the CORRECTED scoring model.
-- Each persona is re-scored while ONE input is changed and the other four
-- are held at their baseline values.
--
--   credit_score   : -100 to +100 points in steps of 20 (clamped 300-850)
--   annual_income  : -50% to +50% in steps of 10%
--   debt           : -50% to +50% in steps of 10%
--   savings        : -50% to +50% in steps of 10%
--   late_payments  : every count from 0 to 5
--
-- 4 personas x (11 + 11 + 11 + 11 + 6) = 200 scenarios.
-- Requires: 01_schema_and_data.sql, 02_credit_scoring.sql
-- =====================================================================

DROP TABLE IF EXISTS sens_pct;
CREATE TABLE sens_pct (step INTEGER);
INSERT INTO sens_pct VALUES (-50),(-40),(-30),(-20),(-10),(0),(10),(20),(30),(40),(50);

DROP TABLE IF EXISTS sens_pts;
CREATE TABLE sens_pts (step INTEGER);
INSERT INTO sens_pts VALUES (-100),(-80),(-60),(-40),(-20),(0),(20),(40),(60),(80),(100);

DROP TABLE IF EXISTS sens_late;
CREATE TABLE sens_late (late_count INTEGER);
INSERT INTO sens_late VALUES (0),(1),(2),(3),(4),(5);

-- Scenario table: every row is a full set of five inputs ---------------
-- step_value : what is shown on a chart axis (points, %, or a count)
-- delta      : signed size of the change vs. baseline (same unit as step_value,
--              except late_payments where it is late_count - baseline count)
DROP TABLE IF EXISTS scenario_inputs;
CREATE TABLE scenario_inputs (
    persona_id     INTEGER,
    input_order    INTEGER,
    input_changed  TEXT,
    step_unit      TEXT,
    step_value     REAL,
    delta          REAL,
    credit_score   REAL,
    annual_income  REAL,
    debt           REAL,
    savings        REAL,
    late_payments  REAL
);

-- credit score: +/- points, clamped to the 300-850 scale
INSERT INTO scenario_inputs
SELECT p.persona_id, 1, 'credit_score', 'points', s.step, s.step,
       CASE WHEN p.credit_score + s.step > 850 THEN 850
            WHEN p.credit_score + s.step < 300 THEN 300
            ELSE p.credit_score + s.step END,
       p.annual_income, p.debt, p.savings, p.late_payments
FROM personas p CROSS JOIN sens_pts s;

-- annual income: +/- %
INSERT INTO scenario_inputs
SELECT p.persona_id, 2, 'annual_income', '%', s.step, s.step,
       p.credit_score, p.annual_income * (1 + s.step / 100.0),
       p.debt, p.savings, p.late_payments
FROM personas p CROSS JOIN sens_pct s;

-- debt: +/- %
INSERT INTO scenario_inputs
SELECT p.persona_id, 3, 'debt', '%', s.step, s.step,
       p.credit_score, p.annual_income, p.debt * (1 + s.step / 100.0),
       p.savings, p.late_payments
FROM personas p CROSS JOIN sens_pct s;

-- savings: +/- %
INSERT INTO scenario_inputs
SELECT p.persona_id, 4, 'savings', '%', s.step, s.step,
       p.credit_score, p.annual_income, p.debt,
       p.savings * (1 + s.step / 100.0), p.late_payments
FROM personas p CROSS JOIN sens_pct s;

-- late payments: every count from 0 to 5
INSERT INTO scenario_inputs
SELECT p.persona_id, 5, 'late_payments', 'count', s.late_count,
       s.late_count - p.late_payments,
       p.credit_score, p.annual_income, p.debt, p.savings, s.late_count
FROM personas p CROSS JOIN sens_late s;

-- Score every scenario with both models --------------------------------
DROP VIEW IF EXISTS v_scenario_scores;
CREATE VIEW v_scenario_scores AS
WITH n AS (
    SELECT s.*,
        CASE WHEN s.credit_score <= m.credit_min THEN 0.0
             WHEN s.credit_score >= m.credit_max THEN 100.0
             ELSE (s.credit_score - m.credit_min) * 100.0 / (m.credit_max - m.credit_min)
        END AS n_credit,
        CASE WHEN s.annual_income >= m.income_cap THEN 100.0
             ELSE s.annual_income * 100.0 / m.income_cap END AS n_income,
        CASE WHEN s.debt >= m.debt_cap THEN 100.0
             ELSE s.debt * 100.0 / m.debt_cap END AS n_debt,
        CASE WHEN s.savings >= m.savings_cap THEN 100.0
             ELSE s.savings * 100.0 / m.savings_cap END AS n_savings,
        CASE WHEN s.late_payments >= m.late_cap THEN 100.0
             ELSE s.late_payments * 100.0 / m.late_cap END AS n_late
    FROM scenario_inputs s CROSS JOIN model_params m
),
sc AS (
    SELECT n.*,
        n.n_credit * m.w_credit + n.n_income * m.w_income + n.n_debt * m.w_debt
          + n.n_savings * m.w_savings + n.n_late * m.w_late                AS s_orig,
        n.n_credit * m.w_credit + n.n_income * m.w_income + (100 - n.n_debt) * m.w_debt
          + n.n_savings * m.w_savings + (100 - n.n_late) * m.w_late        AS s_corr
    FROM n CROSS JOIN model_params m
)
SELECT
    sc.persona_id,
    p.persona_name,
    sc.input_order,
    sc.input_changed,
    sc.step_unit,
    sc.step_value,
    sc.delta,
    CASE WHEN sc.delta = 0 THEN 1 ELSE 0 END AS is_baseline,
    sc.credit_score, sc.annual_income, sc.debt, sc.savings, sc.late_payments,
    ROUND(sc.s_orig, 4) AS score_original,
    ROUND(sc.s_corr, 4) AS score_corrected,
    CASE WHEN sc.s_corr <= m.high_max   THEN 'High Risk'
         WHEN sc.s_corr <= m.medium_max THEN 'Medium Risk'
         ELSE 'Low Risk' END AS category_corrected
FROM sc
JOIN personas p USING (persona_id)
CROSS JOIN model_params m;

-- Flip points ------------------------------------------------------------
-- For every persona x input x direction: the SMALLEST change that moves the
-- persona into a different risk category. NULL = no flip within the range
-- tested. input_direction refers to the INPUT (e.g. debt 'up' = more debt),
-- not to the score.
DROP VIEW IF EXISTS v_flip_points;
CREATE VIEW v_flip_points AS
WITH base AS (
    SELECT persona_id, category_corrected AS base_category, score_corrected AS base_score
    FROM v_credit_results
),
flipped AS (
    SELECT v.persona_id, v.input_changed, v.step_unit, v.step_value, v.delta,
           v.score_corrected AS score_after, v.category_corrected AS category_after,
           CASE WHEN v.delta < 0 THEN 'down' ELSE 'up' END AS input_direction,
           ROW_NUMBER() OVER (
               PARTITION BY v.persona_id, v.input_changed,
                            CASE WHEN v.delta < 0 THEN 'down' ELSE 'up' END
               ORDER BY ABS(v.delta)
           ) AS rn
    FROM v_scenario_scores v
    JOIN base b USING (persona_id)
    WHERE v.delta <> 0
      AND v.category_corrected <> b.base_category
),
grid AS (
    SELECT p.persona_id, p.persona_name, i.input_changed, i.input_order, d.input_direction
    FROM personas p
    CROSS JOIN (SELECT 'credit_score' AS input_changed, 1 AS input_order UNION ALL
                SELECT 'annual_income', 2 UNION ALL SELECT 'debt', 3 UNION ALL
                SELECT 'savings', 4 UNION ALL SELECT 'late_payments', 5) i
    CROSS JOIN (SELECT 'down' AS input_direction UNION ALL SELECT 'up') d
)
SELECT g.persona_id, g.persona_name, g.input_changed, g.input_direction,
       b.base_score, b.base_category,
       f.step_unit, f.step_value AS flip_step_value, f.delta AS flip_delta,
       ROUND(f.score_after, 2) AS score_after_flip, f.category_after AS category_after_flip,
       CASE WHEN f.persona_id IS NULL THEN 0 ELSE 1 END AS flips_within_range
FROM grid g
JOIN base b USING (persona_id)
LEFT JOIN flipped f
       ON f.persona_id = g.persona_id AND f.input_changed = g.input_changed
      AND f.input_direction = g.input_direction AND f.rn = 1
ORDER BY g.persona_id, g.input_order, g.input_direction;

-- Sanity check: baseline scenarios must equal the persona-level scores.
-- Expect ZERO rows back.
-- SELECT s.persona_id, s.input_changed, s.score_corrected, r.score_corrected
-- FROM v_scenario_scores s JOIN v_credit_results r USING (persona_id)
-- WHERE s.is_baseline = 1 AND ABS(s.score_corrected - r.score_corrected) > 0.01;
