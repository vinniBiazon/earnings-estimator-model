-- Every combination a prospect can choose in the calculator.
-- Bands never cross (each one at least 10% above the one below) and the low band
-- never goes under the minimum.
-- Known limitation: the two levers are applied as if independent, which slightly
-- overstates the combined effect for panelists who are high on both.
CREATE OR REPLACE TABLE estimates AS
WITH grid AS (
    SELECT cb.profession, cb.market, cb.borrowed, cb.q25, cb.q50, cb.q75,
           v.level AS visit_level, v.applied_factor AS f_visits,
           t.level AS time_band,   t.applied_factor AS f_time
    FROM cell_bands cb
    CROSS JOIN (SELECT * FROM levers WHERE lever = 'visits') v
    CROSS JOIN (SELECT * FROM levers WHERE lever = 'study time') t
), scaled AS (
    SELECT *,
           q25 * f_visits * f_time AS s25,
           q50 * f_visits * f_time AS s50,
           q75 * f_visits * f_time AS s75
    FROM grid
), low AS (
    SELECT scaled.*, GREATEST(s25, st.min_low_band) AS b25, st.band_gap
    FROM scaled, settings st
), mid AS (
    SELECT *, GREATEST(s50, b25 * band_gap) AS b50 FROM low
), high AS (
    SELECT *, GREATEST(s75, b50 * band_gap) AS b75 FROM mid
)
SELECT
    profession, market, visit_level, time_band, borrowed,
    ROUND(b25, 0)       AS low_usd_month,
    ROUND(b50, 0)       AS typical_usd_month,
    ROUND(b75, 0)       AS high_usd_month,
    ROUND(b50 * 12, -1) AS typical_usd_year
FROM high;
