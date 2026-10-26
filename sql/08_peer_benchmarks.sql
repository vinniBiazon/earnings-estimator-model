-- Peer benchmarks shown next to the estimate: where the middle panelist of the
-- profession lands, and how much they do to get there.
CREATE OR REPLACE TABLE peer_benchmarks AS
SELECT
    profession,
    COUNT(*)                                       AS panelists,
    ROUND(MEDIAN(usd_per_month), 0)                AS median_usd_month,
    ROUND(AVG(usd_per_month), 0)                   AS mean_usd_month,
    ROUND(MEDIAN(visits_90d) / 13.0, 1)            AS median_visits_week,
    ROUND(MEDIAN(study_minutes_6m) / 26.0, 0)      AS median_study_minutes_week
FROM base_sample
GROUP BY 1
ORDER BY median_usd_month DESC;
