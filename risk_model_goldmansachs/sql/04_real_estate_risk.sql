-- =====================================================================
-- 04_real_estate_risk.sql
-- Quantitative extension of the Florida apartment-complex scenario.
-- Each qualitative risk from the task is given a probability, a dollar
-- impact estimate, and a mitigation strategy, then scored by expected
-- annual loss (EAL = probability x impact) so risks can be ranked and
-- mitigation cost can be judged against the exposure it reduces.
--
-- All probabilities and impacts are illustrative assumptions made for
-- this project, not real market data. See README for sourcing notes.
-- Requires: 01_schema_and_data.sql (for model_params' high_max/medium_max
-- reuse is optional here; real estate risk uses its own thresholds below)
-- =====================================================================

DROP TABLE IF EXISTS re_risk_params;
CREATE TABLE re_risk_params (
    low_max REAL, medium_max REAL   -- risk_score <= low_max -> Low; <= medium_max -> Medium; else High
);
INSERT INTO re_risk_params VALUES (10, 25);
-- risk_score is expressed as EAL / 10,000, i.e. "risk points per $10k of
-- expected annual loss" -- keeps the scale readable (0-50ish) rather than
-- raw dollars. See README for the full explanation.

DROP TABLE IF EXISTS real_estate_risks;
CREATE TABLE real_estate_risks (
    risk_id            INTEGER PRIMARY KEY,
    risk_name          TEXT NOT NULL,
    probability        REAL NOT NULL,   -- annual probability, 0-1
    impact_usd         INTEGER NOT NULL,-- estimated $ impact if it occurs
    mitigation_strategy TEXT NOT NULL,
    mitigation_cost_usd INTEGER NOT NULL, -- annualized cost of the strategy
    rationale          TEXT
);

INSERT INTO real_estate_risks VALUES
(1, 'Hurricane / storm damage', 0.15, 900000,
   'Carry windstorm insurance rider + annual roof/drainage inspection',
   45000,
   'Florida coastal exposure; low-frequency, very high-severity event'),
(2, 'Property tax increase', 0.40, 120000,
   'Annual reassessment review with a property tax attorney',
   8000,
   'Moderately likely given rising FL property valuations; moderate impact'),
(3, 'Occupancy drop from new competing complexes', 0.35, 250000,
   'Tenant retention incentives + accelerate amenity upgrades',
   60000,
   'New supply is visible in the pipeline; direct hit to rental income'),
(4, 'Seasonal occupancy swings', 0.60, 90000,
   'Flexible/short-term lease mix to smooth off-season vacancy',
   15000,
   'Near-certain annually in FL rental markets; impact is comparatively small'),
(5, 'Major unplanned repair (non-storm)', 0.25, 150000,
   'Capital reserve fund funded from NOI + preventive maintenance plan',
   20000,
   'Aging-building risk; reserve funding is cheaper than reactive repair');

DROP VIEW IF EXISTS v_real_estate_results;
CREATE VIEW v_real_estate_results AS
SELECT
    r.risk_id,
    r.risk_name,
    r.probability,
    r.impact_usd,
    ROUND(r.probability * r.impact_usd, 0) AS expected_annual_loss,
    ROUND(r.probability * r.impact_usd / 10000.0, 2) AS risk_score,
    CASE WHEN r.probability * r.impact_usd / 10000.0 <= p.low_max THEN 'Low Risk'
         WHEN r.probability * r.impact_usd / 10000.0 <= p.medium_max THEN 'Medium Risk'
         ELSE 'High Risk' END AS risk_category,
    r.mitigation_strategy,
    r.mitigation_cost_usd,
    ROUND(r.probability * r.impact_usd - r.mitigation_cost_usd, 0) AS net_exposure_before_effectiveness,
    ROUND(r.mitigation_cost_usd * 100.0 / NULLIF(r.probability * r.impact_usd, 0), 1) AS mitigation_cost_pct_of_eal,
    r.rationale,
    RANK() OVER (ORDER BY r.probability * r.impact_usd DESC) AS rank_by_exposure
FROM real_estate_risks r
CROSS JOIN re_risk_params p;

-- Portfolio-level summary -------------------------------------------------
DROP VIEW IF EXISTS v_real_estate_summary;
CREATE VIEW v_real_estate_summary AS
SELECT
    COUNT(*) AS num_risks,
    ROUND(SUM(expected_annual_loss), 0) AS total_expected_annual_loss,
    ROUND(SUM(mitigation_cost_usd), 0) AS total_mitigation_cost,
    ROUND(SUM(expected_annual_loss) - SUM(mitigation_cost_usd), 0) AS net_exposure,
    SUM(CASE WHEN risk_category = 'High Risk' THEN 1 ELSE 0 END) AS high_risk_count,
    SUM(CASE WHEN risk_category = 'Medium Risk' THEN 1 ELSE 0 END) AS medium_risk_count,
    SUM(CASE WHEN risk_category = 'Low Risk' THEN 1 ELSE 0 END) AS low_risk_count
FROM v_real_estate_results;

-- Quick look ---------------------------------------------------------------
-- SELECT risk_name, probability, impact_usd, expected_annual_loss,
--        risk_category, mitigation_strategy, mitigation_cost_pct_of_eal
-- FROM v_real_estate_results ORDER BY rank_by_exposure;
