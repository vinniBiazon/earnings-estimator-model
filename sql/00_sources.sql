-- Raw CSVs exposed as views. Paths are relative to the repository root.
CREATE OR REPLACE VIEW panelists      AS SELECT * FROM read_csv_auto('data/raw/panelists.csv');
CREATE OR REPLACE VIEW role_history   AS SELECT * FROM read_csv_auto('data/raw/role_history.csv');
CREATE OR REPLACE VIEW visits         AS SELECT * FROM read_csv_auto('data/raw/visits.csv');
CREATE OR REPLACE VIEW studies        AS SELECT * FROM read_csv_auto('data/raw/studies.csv');
CREATE OR REPLACE VIEW rewards        AS SELECT * FROM read_csv_auto('data/raw/rewards.csv');
CREATE OR REPLACE VIEW currency_rates AS SELECT * FROM read_csv_auto('data/raw/currency_rates.csv');

-- Model settings in one place
CREATE OR REPLACE TABLE settings AS
SELECT
    DATE '2026-09-30' AS reference_date,
    18                AS lookback_months,   -- reward history used by the model
    5                 AS min_visits,        -- eligibility: 5+ visits in the last 6 months
    4                 AS min_studies,       -- ...or 4+ completed studies
    80                AS min_cell_size,     -- smaller cells fall back to the profession-wide figures
    0.60              AS damping,           -- levers keep 60% of their observed distance from 1.0
    40.0              AS min_low_band,      -- lowest P25 ever shown, in USD per month
    1.10              AS band_gap;          -- each band is at least 10% above the one below
