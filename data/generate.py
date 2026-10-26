"""Generate a synthetic research-panel dataset for the earnings estimator case study.

Everything here is invented: panelists, professions, rewards and rates.
The data deliberately carries four classic data traps:

1. Reward history older than the window the model is supposed to use
2. A role history table with several rows per panelist, which duplicates
   rewards when joined naively
3. A legacy `account_flag` column that is NULL for older accounts, so
   filtering on account_flag = 'ok' silently drops eligible panelists
4. A long tail of extreme reward months

Run:  python data/generate.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 7
N_PANELISTS = 150_000
AS_OF = pd.Timestamp("2026-09-30")
HISTORY_MONTHS = 30
WINDOW_MONTHS = 18

OUT = Path(__file__).resolve().parent / "raw"

PROFESSIONS = {
    # profession: (share of panel, relative reward level)
    "Software Engineering": (0.16, 1.30),
    "Data & Analytics": (0.08, 1.35),
    "Finance": (0.12, 1.25),
    "Legal": (0.06, 1.45),
    "Healthcare": (0.10, 1.20),
    "Marketing": (0.10, 0.95),
    "Sales": (0.10, 0.85),
    "Education": (0.09, 0.75),
    "Operations": (0.11, 0.90),
    "Other": (0.08, 0.80),
}
MARKETS = {
    # market: (share, relative reward level, reward currency)
    "United States": (0.42, 1.00, "USD"),
    "Canada": (0.08, 0.80, "CAD"),
    "United Kingdom": (0.11, 0.85, "GBP"),
    "Europe": (0.19, 0.75, "EUR"),
    "Latin America": (0.12, 0.30, "BRL"),
    "Asia-Pacific": (0.08, 0.50, "USD"),
}
TO_USD = {"USD": 1.0, "CAD": 0.72, "GBP": 1.30, "EUR": 1.10, "BRL": 0.18}


def main() -> None:
    rng = np.random.default_rng(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    rate_of = np.vectorize(TO_USD.get)

    # ------------------------------------------------------------- panelists
    prof_names = list(PROFESSIONS)
    prof_p = np.array([PROFESSIONS[p][0] for p in prof_names])
    mk_names = list(MARKETS)
    mk_p = np.array([MARKETS[c][0] for c in mk_names])

    panelists = pd.DataFrame(
        {
            "panelist_id": np.arange(500_001, 500_001 + N_PANELISTS),
            "market": rng.choice(mk_names, N_PANELISTS, p=mk_p),
            "joined_on": AS_OF - pd.to_timedelta(rng.integers(20, 365 * 7, N_PANELISTS), unit="D"),
            "life_stage": rng.choice(["Working", "Student", "Retired"], N_PANELISTS, p=[0.83, 0.11, 0.06]),
        }
    )
    profession = rng.choice(prof_names, N_PANELISTS, p=prof_p / prof_p.sum())

    # Accounts created before 2022 never got a flag value
    legacy = panelists["joined_on"] < pd.Timestamp("2022-01-01")
    panelists["account_flag"] = np.where(legacy, None, "ok")
    panelists.loc[rng.random(N_PANELISTS) < 0.03, "account_flag"] = "blocked"

    # ------------------------------------------------- role history (1..4 rows)
    n_rows = rng.choice([1, 2, 3, 4], N_PANELISTS, p=[0.68, 0.20, 0.08, 0.04])
    h_id = np.repeat(panelists["panelist_id"].to_numpy(), n_rows)
    h_rank = np.concatenate([np.arange(k) for k in n_rows])
    h_prof = np.repeat(profession, n_rows)
    changed = (h_rank < np.repeat(n_rows - 1, n_rows)) & (rng.random(len(h_id)) < 0.5)
    h_prof = np.where(changed, rng.choice(prof_names, len(h_id)), h_prof)
    role_history = pd.DataFrame(
        {
            "panelist_id": h_id,
            "profession": h_prof,
            "effective_date": pd.Timestamp("2019-01-01")
            + pd.to_timedelta(h_rank * 380 + rng.integers(0, 300, len(h_id)), unit="D"),
        }
    )

    # ------------------------------------------------------- latent traits
    prof_level = np.array([PROFESSIONS[p][1] for p in profession])
    mk_level = panelists["market"].map({c: v[1] for c, v in MARKETS.items()}).to_numpy()
    appetite = rng.lognormal(mean=0.0, sigma=0.8, size=N_PANELISTS)
    active = rng.random(N_PANELISTS) < np.clip(0.22 + 0.26 * np.log1p(appetite), 0.05, 0.95)
    active &= panelists["life_stage"].to_numpy() != "Retired"
    ccy = panelists["market"].map({c: v[2] for c, v in MARKETS.items()}).to_numpy()

    # ------------------------------------------------------- visits (6 months)
    visits_6m = rng.poisson(np.where(active, 2.2 * appetite, 0.2) * 3)
    v_id = np.repeat(panelists["panelist_id"].to_numpy(), visits_6m)
    visits = pd.DataFrame(
        {"panelist_id": v_id, "visit_date": AS_OF - pd.to_timedelta(rng.integers(0, 182, len(v_id)), unit="D")}
    )

    # ------------------------------------------------ completed studies (6 months)
    studies_6m = rng.poisson(np.where(active, 1.5 * appetite**0.9, 0.05) * 3)
    s_idx = np.repeat(np.arange(N_PANELISTS), studies_6m)
    minutes = np.clip(rng.gamma(2.0, 8.0, len(s_idx)), 4, 80).round()
    usd_value = minutes * 1.7 * prof_level[s_idx] * mk_level[s_idx] * rng.lognormal(0, 0.25, len(s_idx))
    s_ccy = ccy[s_idx]
    studies = pd.DataFrame(
        {
            "panelist_id": panelists["panelist_id"].to_numpy()[s_idx],
            "finished_at": AS_OF - pd.to_timedelta(rng.integers(0, 182, len(s_idx)), unit="D"),
            "minutes_spent": minutes,
            "reward_value": (usd_value / rate_of(s_ccy)).round(2),
            "reward_ccy": s_ccy,
        }
    )

    # ------------------------------------------------------- monthly rewards
    months = pd.date_range(end=AS_OF.normalize().replace(day=1), periods=HISTORY_MONTHS, freq="MS")
    base_usd = 110 * prof_level * mk_level * appetite**0.9
    parts = []
    for i, m in enumerate(months):
        before_window = i < HISTORY_MONTHS - WINDOW_MONTHS
        uplift = 1.30 if before_window else 1.0  # an older, more generous reward scheme
        joined = panelists["joined_on"].to_numpy() <= m.to_datetime64()
        paid = joined & active & (rng.random(N_PANELISTS) < 0.55)
        value = base_usd[paid] * uplift * rng.lognormal(0, 0.45, paid.sum())
        parts.append(
            pd.DataFrame(
                {
                    "panelist_id": panelists["panelist_id"].to_numpy()[paid],
                    "reward_month": m,
                    "value": (value / rate_of(ccy[paid])).round(2),
                    "ccy": ccy[paid],
                }
            )
        )
    rewards = pd.concat(parts, ignore_index=True)

    # A long tail of extreme months (one-off bonuses, data entry errors)
    tail = rng.choice(len(rewards), size=int(len(rewards) * 0.002), replace=False)
    rewards.loc[tail, "value"] = (rewards.loc[tail, "value"] * rng.uniform(15, 60, len(tail))).round(2)

    currency_rates = pd.DataFrame({"ccy": list(TO_USD), "to_usd": list(TO_USD.values())})

    # ----------------------------------------------------------------- write
    panelists.to_csv(OUT / "panelists.csv", index=False)
    role_history.to_csv(OUT / "role_history.csv", index=False)
    visits.to_csv(OUT / "visits.csv", index=False)
    studies.to_csv(OUT / "studies.csv", index=False)
    rewards.to_csv(OUT / "rewards.csv", index=False)
    currency_rates.to_csv(OUT / "currency_rates.csv", index=False)

    for name, df in [("panelists", panelists), ("role_history", role_history), ("visits", visits),
                     ("studies", studies), ("rewards", rewards)]:
        print(f"{name:<14}{len(df):>11,}")


if __name__ == "__main__":
    main()
