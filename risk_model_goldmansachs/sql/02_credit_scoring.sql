-- =====================================================================
-- 02_credit_scoring.sql
-- Two versions of the weighted scoring model, built as views:
--
--   ORIGINAL  : every factor is added as-is, so MORE debt and MORE late
--               payments push the score UP (safer). This mirrors the
--               behaviour of the simplified calculator in the task.
--   CORRECTED : debt and late payments are inverted (100 - x) so they
--               push the score DOWN, as they should.
--
-- Score direction: HIGHER SCORE = SAFER BORROWER.
-- Categories: <= high_max = High Risk, <= medium_max = Medium, else Low.
-- Requires: 01_schema_and_data.sql
-- =====================================================================

-- Step 1: scale every factor to 0-100 ----------------------------------
-- n_debt and n_late are "raw": 100 = maximum debt / maximum late payments.
DROP VIEW IF EXISTS v_normalized;
CREATE VIEW v_normalized AS
SELECT
    p.persona_id,
    p.persona_name,
    CASE WHEN p.credit_score <= m.credit_min THEN 0.0
         WHEN p.credit_score >= m.credit_max THEN 100.0
         ELSE (p.credit_score - m.credit_min) * 100.0 / (m.credit_max - m.credit_min)
    END AS n_credit,
    CASE WHEN p.annual_income >= m.income_cap THEN 100.0
         ELSE p.annual_income * 100.0 / m.income_cap END AS n_income,
    CASE WHEN p.debt >= m.debt_cap THEN 100.0
         ELSE p.debt * 100.0 / m.debt_cap END AS n_debt,
    CASE WHEN p.savings >= m.savings_cap THEN 100.0
         ELSE p.savings * 100.0 / m.savings_cap END AS n_savings,
    CASE WHEN p.late_payments >= m.late_cap THEN 100.0
         ELSE p.late_payments * 100.0 / m.late_cap END AS n_late
FROM personas p
CROSS JOIN model_params m;

-- Step 2: weighted scores under both models ----------------------------
DROP VIEW IF EXISTS v_credit_scores;
CREATE VIEW v_credit_scores AS
SELECT
    n.persona_id,
    n.persona_name,
    n.n_credit, n.n_income, n.n_debt, n.n_savings, n.n_late,
    -- original: debt and late payments added as-is
    n.n_credit  * m.w_credit
  + n.n_income  * m.w_income
  + n.n_debt    * m.w_debt
  + n.n_savings * m.w_savings
  + n.n_late    * m.w_late                     AS score_original,
    -- corrected: debt and late payments inverted
    n.n_credit  * m.w_credit
  + n.n_income  * m.w_income
  + (100 - n.n_debt) * m.w_debt
  + n.n_savings * m.w_savings
  + (100 - n.n_late) * m.w_late                AS score_corrected
FROM v_normalized n
CROSS JOIN model_params m;

-- Step 3: categories, comparison, ranking ------------------------------
DROP VIEW IF EXISTS v_credit_results;
CREATE VIEW v_credit_results AS
SELECT
    s.persona_id,
    s.persona_name,
    p.annual_income, p.credit_score, p.debt, p.savings, p.late_payments,
    ROUND(s.n_credit, 2)  AS n_credit,
    ROUND(s.n_income, 2)  AS n_income,
    ROUND(s.n_debt, 2)    AS n_debt_raw,
    ROUND(s.n_savings, 2) AS n_savings,
    ROUND(s.n_late, 2)    AS n_late_raw,
    ROUND(s.score_original, 2)  AS score_original,
    CASE WHEN s.score_original <= m.high_max   THEN 'High Risk'
         WHEN s.score_original <= m.medium_max THEN 'Medium Risk'
         ELSE 'Low Risk' END                   AS category_original,
    ROUND(s.score_corrected, 2) AS score_corrected,
    CASE WHEN s.score_corrected <= m.high_max   THEN 'High Risk'
         WHEN s.score_corrected <= m.medium_max THEN 'Medium Risk'
         ELSE 'Low Risk' END                   AS category_corrected,
    ROUND(s.score_corrected - s.score_original, 2) AS score_change,
    -- distance to the nearest category boundary (corrected model)
    ROUND(CASE WHEN s.score_corrected <= m.high_max   THEN m.high_max - s.score_corrected
               WHEN s.score_corrected <= m.medium_max
                    THEN CASE WHEN s.score_corrected - m.high_max < m.medium_max - s.score_corrected
                              THEN s.score_corrected - m.high_max
                              ELSE m.medium_max - s.score_corrected END
               ELSE s.score_corrected - m.medium_max END, 2) AS points_to_boundary,
    RANK() OVER (ORDER BY s.score_corrected DESC)  AS rank_safest_first
FROM v_credit_scores s
JOIN personas p USING (persona_id)
CROSS JOIN model_params m;

-- Step 4: long format - which factors drive the corrected score? -------
-- One row per persona per factor. weighted_points sum to score_corrected.
DROP VIEW IF EXISTS v_score_components;
CREATE VIEW v_score_components AS
SELECT persona_id, persona_name, 'Credit score' AS factor, m.w_credit AS weight,
       ROUND(n_credit, 2) AS factor_score, ROUND(n_credit * m.w_credit, 2) AS weighted_points
FROM v_normalized CROSS JOIN model_params m
UNION ALL
SELECT persona_id, persona_name, 'Annual income', m.w_income,
       ROUND(n_income, 2), ROUND(n_income * m.w_income, 2)
FROM v_normalized CROSS JOIN model_params m
UNION ALL
SELECT persona_id, persona_name, 'Debt (inverted)', m.w_debt,
       ROUND(100 - n_debt, 2), ROUND((100 - n_debt) * m.w_debt, 2)
FROM v_normalized CROSS JOIN model_params m
UNION ALL
SELECT persona_id, persona_name, 'Savings', m.w_savings,
       ROUND(n_savings, 2), ROUND(n_savings * m.w_savings, 2)
FROM v_normalized CROSS JOIN model_params m
UNION ALL
SELECT persona_id, persona_name, 'Late payments (inverted)', m.w_late,
       ROUND(100 - n_late, 2), ROUND((100 - n_late) * m.w_late, 2)
FROM v_normalized CROSS JOIN model_params m;

-- Quick look -------------------------------------------------------------
-- SELECT persona_name, score_original, category_original,
--        score_corrected, category_corrected, points_to_boundary
-- FROM v_credit_results ORDER BY persona_id;
