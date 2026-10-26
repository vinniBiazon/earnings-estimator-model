-- Who the estimate should describe: panelists who are actually taking part.
-- account_flag is NULL for legacy accounts, so the rule is "not blocked",
-- never "account_flag = 'ok'" (see checks.sql, check 2).
CREATE OR REPLACE TABLE recent_activity AS
WITH v AS (
    SELECT panelist_id,
           COUNT(*)                                                               AS visits_6m,
           COUNT(*) FILTER (WHERE visit_date > reference_date - INTERVAL 90 DAY)  AS visits_90d
    FROM visits, settings
    WHERE visit_date > reference_date - INTERVAL 6 MONTH
    GROUP BY 1
), s AS (
    SELECT panelist_id, COUNT(*) AS studies_6m, SUM(minutes_spent) AS study_minutes_6m
    FROM studies, settings
    WHERE finished_at > reference_date - INTERVAL 6 MONTH
    GROUP BY 1
)
SELECT
    cr.panelist_id,
    COALESCE(v.visits_6m, 0)        AS visits_6m,
    COALESCE(v.visits_90d, 0)       AS visits_90d,
    COALESCE(s.studies_6m, 0)       AS studies_6m,
    COALESCE(s.study_minutes_6m, 0) AS study_minutes_6m
FROM current_role cr
LEFT JOIN v USING (panelist_id)
LEFT JOIN s USING (panelist_id);

CREATE OR REPLACE TABLE eligible_panelists AS
SELECT cr.*, ra.visits_6m, ra.visits_90d, ra.studies_6m, ra.study_minutes_6m
FROM current_role cr
JOIN recent_activity ra USING (panelist_id), settings st
WHERE cr.life_stage <> 'Retired'
  AND cr.account_flag IS DISTINCT FROM 'blocked'
  AND (ra.visits_6m >= st.min_visits OR ra.studies_6m >= st.min_studies);
