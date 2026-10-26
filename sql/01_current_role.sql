-- One row per panelist with their CURRENT profession.
-- role_history keeps every past value, so joining it straight to rewards
-- repeats reward rows (see checks.sql, check 1).
CREATE OR REPLACE TABLE current_role AS
SELECT
    p.panelist_id,
    p.market,
    p.joined_on,
    p.life_stage,
    p.account_flag,
    rh.profession
FROM panelists p
JOIN role_history rh USING (panelist_id)
QUALIFY ROW_NUMBER() OVER (PARTITION BY rh.panelist_id ORDER BY rh.effective_date DESC) = 1;
