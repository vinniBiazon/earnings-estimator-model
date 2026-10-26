-- Data checks: each one compares the naive version of a step with the one the
-- model uses. Run after steps 00 to 08.
CREATE OR REPLACE TABLE data_checks AS

-- 1. Join fan-out: role_history has several rows per panelist
WITH recent_rewards AS (
    SELECT r.*
    FROM rewards r, settings
    WHERE r.reward_month > reference_date - TO_MONTHS(lookback_months)
)
SELECT
    1 AS check_id,
    'Reward rows after adding profession' AS check_name,
    (SELECT COUNT(*) FROM recent_rewards JOIN role_history USING (panelist_id))::DOUBLE AS naive_value,
    (SELECT COUNT(*) FROM recent_rewards JOIN current_role USING (panelist_id))::DOUBLE AS model_value,
    'Joining the full role history repeats each reward once per past profession' AS note

UNION ALL

-- 2. Legacy NULL flag silently removes panelists
SELECT
    2,
    'Eligible panelists',
    (SELECT COUNT(*) FROM eligible_panelists WHERE account_flag = 'ok'),
    (SELECT COUNT(*) FROM eligible_panelists),
    'Filtering on account_flag = ''ok'' drops every legacy account, where the flag is NULL'

UNION ALL

-- 3. Lookback window not applied
SELECT
    3,
    'P75 monthly earnings, all eligible (USD)',
    (SELECT QUANTILE_CONT(usd, 0.75) FROM (
        SELECT e.panelist_id,
               SUM(r.value * cr.to_usd)
               / GREATEST(1, DATE_DIFF('month', MIN(r.reward_month), (SELECT reference_date FROM settings))) AS usd
        FROM eligible_panelists e
        JOIN rewards r USING (panelist_id)
        JOIN currency_rates cr USING (ccy)
        GROUP BY 1)),
    (SELECT QUANTILE_CONT(usd_per_month, 0.75) FROM panelist_earnings),
    'Without the lookback window, an older and more generous reward scheme inflates the bands'

UNION ALL

-- 4. Cell size with and without a third split
SELECT
    4,
    'Cells below the minimum size (%)',
    (SELECT 100.0 * AVG((n < (SELECT min_cell_size FROM settings))::INT) FROM (
        SELECT profession, market,
               CASE WHEN visits_90d >= 26 THEN 'Several a week'
                    WHEN visits_90d >= 10 THEN 'About weekly'
                    ELSE 'Less often' END AS visit_cadence,
               COUNT(*) AS n
        FROM base_sample
        GROUP BY 1, 2, 3)),
    (SELECT 100.0 * AVG(borrowed::INT) FROM cell_bands),
    'Splitting cells by visit cadence leaves most of them too small; visits already work as a lever'

UNION ALL

-- 5. Tails
SELECT
    5,
    'Mean / median monthly earnings',
    (SELECT AVG(usd_per_month) / MEDIAN(usd_per_month) FROM panelist_earnings),
    (SELECT AVG(usd_per_month) / MEDIAN(usd_per_month) FROM base_sample),
    'Before trimming, a few extreme months pull the mean away from the median';
