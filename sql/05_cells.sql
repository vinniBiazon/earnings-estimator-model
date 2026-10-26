-- Quartile bands (P25 / P50 / P75) of monthly earnings by profession x market.
-- Cells with too few panelists borrow the profession-wide bands, so nobody sees
-- a range computed from a handful of people.
CREATE OR REPLACE TABLE cell_bands AS
WITH cell AS (
    SELECT profession, market, COUNT(*) AS panelists,
           QUANTILE_CONT(usd_per_month, 0.25) AS q25,
           QUANTILE_CONT(usd_per_month, 0.50) AS q50,
           QUANTILE_CONT(usd_per_month, 0.75) AS q75
    FROM base_sample
    GROUP BY 1, 2
), prof AS (
    SELECT profession,
           QUANTILE_CONT(usd_per_month, 0.25) AS q25,
           QUANTILE_CONT(usd_per_month, 0.50) AS q50,
           QUANTILE_CONT(usd_per_month, 0.75) AS q75
    FROM base_sample
    GROUP BY 1
)
SELECT
    cell.profession,
    cell.market,
    cell.panelists,
    cell.panelists < st.min_cell_size                                    AS borrowed,
    CASE WHEN cell.panelists < st.min_cell_size THEN prof.q25 ELSE cell.q25 END AS q25,
    CASE WHEN cell.panelists < st.min_cell_size THEN prof.q50 ELSE cell.q50 END AS q50,
    CASE WHEN cell.panelists < st.min_cell_size THEN prof.q75 ELSE cell.q75 END AS q75
FROM cell
JOIN prof USING (profession), settings st;
