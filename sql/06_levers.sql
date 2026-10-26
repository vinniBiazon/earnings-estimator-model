-- Two levers a prospect controls: how often they visit and how long they spend on studies.
-- Observed ratio = average earnings of the level / the middle level.
-- The applied factor keeps 60% of that distance from 1.0 and is rounded, so the
-- calculator stays conservative and does not chase one sample.
CREATE OR REPLACE TABLE panelist_levels AS
WITH cuts AS (
    SELECT QUANTILE_CONT(study_minutes_6m, 1 / 3) AS t1,
           QUANTILE_CONT(study_minutes_6m, 2 / 3) AS t2
    FROM base_sample
)
SELECT
    bs.*,
    CASE WHEN visits_90d <= 3  THEN 'Light'
         WHEN visits_90d <= 10 THEN 'Regular'
         ELSE 'Frequent' END AS visit_level,
    CASE WHEN study_minutes_6m < cuts.t1 THEN 'Short'
         WHEN study_minutes_6m < cuts.t2 THEN 'Medium'
         ELSE 'Long' END AS time_band
FROM base_sample bs, cuts;

CREATE OR REPLACE TABLE levers AS
WITH by_level AS (
    SELECT 'visits' AS lever, visit_level AS level, COUNT(*) AS panelists, AVG(usd_per_month) AS avg_usd
    FROM panelist_levels
    GROUP BY 1, 2
    UNION ALL
    SELECT 'study time', time_band, COUNT(*), AVG(usd_per_month)
    FROM panelist_levels
    GROUP BY 1, 2
), middle AS (
    SELECT lever, avg_usd AS middle_usd
    FROM by_level
    WHERE level IN ('Regular', 'Medium')
)
SELECT
    bl.lever,
    bl.level,
    bl.panelists,
    ROUND(bl.avg_usd, 2)                                             AS avg_usd_per_month,
    ROUND(bl.avg_usd / m.middle_usd, 3)                              AS observed_ratio,
    ROUND(1 + st.damping * (bl.avg_usd / m.middle_usd - 1), 1)       AS applied_factor
FROM by_level bl
JOIN middle m USING (lever), settings st
ORDER BY 1 DESC, CASE WHEN bl.level IN ('Light', 'Short') THEN 1
                      WHEN bl.level IN ('Regular', 'Medium') THEN 2 ELSE 3 END;
