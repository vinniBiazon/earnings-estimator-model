-- Average monthly earnings in USD over the lookback window.
-- Months without a reward count as zero, and panelists who joined during the
-- window are divided by their own tenure instead of the full window.
CREATE OR REPLACE TABLE panelist_earnings AS
WITH in_window AS (
    SELECT r.panelist_id, SUM(r.value * cr.to_usd) AS usd_in_window
    FROM rewards r
    JOIN currency_rates cr USING (ccy), settings
    WHERE r.reward_month > reference_date - TO_MONTHS(lookback_months)
    GROUP BY 1
), tenure AS (
    SELECT e.panelist_id,
           LEAST(st.lookback_months,
                 GREATEST(1, DATE_DIFF('month', e.joined_on, st.reference_date))) AS months_counted
    FROM eligible_panelists e, settings st
)
SELECT
    e.panelist_id,
    e.profession,
    e.market,
    e.visits_90d,
    e.study_minutes_6m,
    COALESCE(w.usd_in_window, 0)                    AS usd_in_window,
    t.months_counted,
    COALESCE(w.usd_in_window, 0) / t.months_counted AS usd_per_month
FROM eligible_panelists e
JOIN tenure t USING (panelist_id)
LEFT JOIN in_window w USING (panelist_id);
