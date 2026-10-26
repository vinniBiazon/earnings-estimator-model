-- Cut the tails before computing the bands: the bottom 15% barely take part,
-- the top 3% carry one-off bonuses and data entry errors.
-- (DuckDB needs constant quantiles, so the cut-offs are written here.)
CREATE OR REPLACE TABLE trim_limits AS
SELECT
    QUANTILE_CONT(usd_per_month, 0.15) AS lower_limit,
    QUANTILE_CONT(usd_per_month, 0.97) AS upper_limit
FROM panelist_earnings;

CREATE OR REPLACE TABLE base_sample AS
SELECT pe.*
FROM panelist_earnings pe, trim_limits lim
WHERE pe.usd_per_month BETWEEN lim.lower_limit AND lim.upper_limit;
