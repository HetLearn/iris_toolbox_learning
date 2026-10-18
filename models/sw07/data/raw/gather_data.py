"""
canova_data.py
===============
Gathers and constructs the U.S. macro data needed to replicate

    Fabio Canova (2014), "Bridging DSGE Models and the Raw Data,"
    Journal of Monetary Economics, 67, 1-15.
    (working-paper / online-appendix version: dsge_trend_2014_1.pdf)

The paper states only that "the data comes from the FRED database at the
Federal Reserve Bank of St. Louis" and does not print FRED mnemonics, so
this script uses the standard, widely-documented construction for the two
datasets the paper actually uses:

  DATASET A - small-scale New Keynesian model (paper Sections 2 and 5.1)
      Observables: output, real wage, inflation, nominal interest rate.
      Used for Table 2 (sample 1980Q1-2007Q4) and the policy-activism
      exercise in Section 5.1 (sub-samples 1964Q1-1979Q4 and 1984Q1-2007Q4).

  DATASET B - medium-scale (Smets-Wouters-style) model (paper Section 5.2)
      Observables: output, consumption, investment, hours, real wage,
      inflation, nominal interest rate - "the same data set used in
      Smets and Wouters (2007)". Built here with the standard SW(2007)
      FRED-based construction (real, per-capita, log levels for the
      "levels" observables; the model is estimated on growth rates /
      demeaned levels depending on which transformation you replicate).

IMPORTANT
---------
Canova's paper does not give exact FRED series IDs in the printed text I
was able to retrieve, only the source ("FRED") and a verbal description of
each observable. The series chosen below are the standard ones used
throughout the DSGE literature (Smets & Wouters 2007; An & Schorfheide 2007;
etc.) for exactly these observables. If you have access to Canova's actual
online-appendix Matlab/data files, cross-check the series list there and
adjust FRED_SERIES below accordingly - the rest of the pipeline (per-capita
scaling, log transforms, filters) will still apply unchanged.

Requires: pandas, numpy, pandas_datareader, statsmodels (no FRED API key
needed - pandas_datareader pulls the public FRED CSV endpoint directly).
    pip install pandas numpy pandas_datareader statsmodels
"""

import numpy as np
import pandas as pd
from pandas_datareader import data as web

# ----------------------------------------------------------------------
# 0. Configuration
# ----------------------------------------------------------------------

START = "1947-01-01"
END = None                # None -> pandas_datareader defaults to today: always pull the latest data

# Sub-samples actually used in the paper
SAMPLE_TABLE2 = ("1980-01-01", "2007-10-01")          # Table 2 / controlled experiment
SAMPLE_EARLY = ("1964-01-01", "1979-10-01")           # policy-activism: "Great Inflation"
SAMPLE_LATE = ("1984-01-01", "2007-10-01")            # policy-activism: "Great Moderation"
SAMPLE_SW = ("1966-01-01", "2025-10-01")              # standard Smets-Wouters (2007) sample

# --- covid treatment ---------------------------------------------------
# The 2020 lockdown quarters are extreme outliers in a linear model: left in,
# they dominate the estimated shock variances. With EXCLUDE_COVID the rows are
# kept (so the quarterly time index stays unbroken) but the observables are set
# to NaN, which Dynare's Kalman filter treats as unobserved and simply skips.
# Set to False to estimate on the raw data instead.
EXCLUDE_COVID = False
COVID_QUARTERS = ("2020Q1", "2020Q2", "2020Q3")

# FRED mnemonics -- see the IMPORTANT note above.
FRED_SERIES = {
    # --- national accounts (nominal & real, quarterly, SAAR) ---
    "GDPC1":    "real_gdp",            # Real GDP, chained $, SAAR
    "GDP":      "nom_gdp",             # Nominal GDP, SAAR
    "PCEC":     "nom_pce",             # Nominal personal consumption expenditures
    "PCECC96":  "real_pce",            # Real PCE
    "GPDI":     "nom_gpdi",            # Nominal gross private domestic investment
    "GPDIC1":   "real_gpdi",           # Real gross private domestic investment
    "GDPDEF":   "gdp_deflator",        # GDP (implicit price) deflator, index
    # --- consumer prices ---
    "CPIAUCSL": "cpi",                 # CPI, all urban consumers, all items (monthly, SA)
    "CPILFESL": "cpi_core",            # CPI less food and energy = core (monthly, SA, from 1957)
    "FPI":      "nom_fpi",             # Nominal fixed private investment (SW07 investment concept)
    # --- labor market ---
    "HOANBS":   "hours_nfb",           # Nonfarm business hours of all persons, index
    "COMPNFB":  "comp_nfb",            # Nonfarm business compensation per hour, index
    "PRS85006023": "hours_weekly_nfb", # Nonfarm business avg weekly hours, index (SW07 hours concept)
    "CE16OV":   "civ_emp",             # Civilian employment, 16+ (monthly)
    "CNP16OV":  "civ_pop",             # Civilian noninstitutional population, 16+
    # --- interest rate ---
    "FEDFUNDS": "fedfunds",            # Effective federal funds rate, % (monthly)
}


def fetch_fred(series_ids, start=START, end=END):
    """Download a dict of {fred_code: friendly_name} series from FRED."""
    frames = {}
    for code, name in series_ids.items():
        print(f"Fetching {code} ({name}) from FRED ...")
        s = web.DataReader(code, "fred", start, end)[code]
        s.name = name
        frames[name] = s
    return frames


def to_quarterly(series, how="mean"):
    """Resample a (possibly monthly) series to quarterly frequency."""
    s = series.copy()
    s.index = pd.to_datetime(s.index)
    if how == "mean":
        return s.resample("QS").mean()
    elif how == "last":
        return s.resample("QS").last()
    else:
        raise ValueError(how)


# ----------------------------------------------------------------------
# 1. Download raw series
# ----------------------------------------------------------------------

def download_raw():
    raw = fetch_fred(FRED_SERIES)

    # Fed funds is monthly -> quarterly average, matches quarterly obs. rate
    raw["fedfunds"] = to_quarterly(raw["fedfunds"], how="mean")

    # Force EVERY series (including the ones FRED already reports as
    # quarterly) onto a common quarter-start ("QS") index. FRED's own
    # quarterly series are normally already QS-stamped, but silently
    # relying on that is what let inflation go missing before: if any one
    # series comes back on a slightly different stamp, a plain
    # pd.concat(axis=1) introduces NaNs at the join, and a log-difference
    # computed downstream on a mis-aligned column is NaN everywhere.
    for name in raw:
        raw[name].index = pd.to_datetime(raw[name].index)
        raw[name] = raw[name].resample("QS").mean()

    df = pd.concat(raw.values(), axis=1)
    df.index.name = "date"

    # --- Inflation, computed once here so it's available directly in the
    # raw data file rather than only inside build_dataset_a/b. ---
    log_p = np.log(df["gdp_deflator"])
    df["inflation_q"] = 100 * (log_p - log_p.shift(1))          # quarterly rate, %
    df["inflation_ann"] = 400 * (log_p - log_p.shift(1))        # annualized, %

    # CPI headline and core inflation, same conventions as the deflator rates
    for src, tag in (("cpi", "cpi"), ("cpi_core", "core")):
        log_cpi = np.log(df[src])
        df[f"inflation_{tag}_q"] = 100 * (log_cpi - log_cpi.shift(1))
        df[f"inflation_{tag}_ann"] = 400 * (log_cpi - log_cpi.shift(1))

    n_missing = df["inflation_q"].isna().sum()
    print(f"Inflation series built from gdp_deflator: "
          f"{df['inflation_q'].notna().sum()} valid obs, {n_missing} NaN "
          f"(the first observation is always NaN because it's a first difference).")

    return df


# ----------------------------------------------------------------------
# 2. Dataset A: small-scale NK model observables
#    (output, real wage, inflation, nominal interest rate)
# ----------------------------------------------------------------------

def build_dataset_a(raw):
    df = pd.DataFrame(index=raw.index)

    # Output: log real GDP per capita
    df["log_output"] = np.log(raw["real_gdp"] / raw["civ_pop"])

    # Real wage: nonfarm business compensation per hour deflated by the
    # GDP deflator, in logs (Canova's "real wage" observable, wt).
    df["log_real_wage"] = np.log(raw["comp_nfb"] / raw["gdp_deflator"])

    # Inflation: quarterly log-difference of the GDP deflator (computed once
    # in download_raw() and carried through here). Both conventions are
    # included - use whichever matches the units of the rest of your model.
    df["inflation_q"] = raw["inflation_q"]      # quarterly rate, %
    df["inflation_ann"] = raw["inflation_ann"]  # annualized, %

    # CPI headline and core (ex food and energy) inflation
    for c in ("inflation_cpi_q", "inflation_cpi_ann",
              "inflation_core_q", "inflation_core_ann"):
        df[c] = raw[c]

    # Nominal interest rate: quarterly average Fed funds rate, in percent,
    # divided by 4 to express as a quarterly rate (standard convention).
    df["nominal_rate"] = raw["fedfunds"] / 4

    return df.dropna(how="all")


# ----------------------------------------------------------------------
# 3. Dataset B: medium-scale (Smets-Wouters-style) model observables
#    (output, consumption, investment, hours, real wage, inflation, rate)
# ----------------------------------------------------------------------

def build_dataset_b(raw):
    df = pd.DataFrame(index=raw.index)
    pop = raw["civ_pop"]

    df["log_output"] = np.log(raw["real_gdp"] / pop)
    df["log_consumption"] = np.log(raw["real_pce"] / pop)
    df["log_investment"] = np.log(raw["real_gpdi"] / pop)
    df["log_hours"] = np.log(raw["hours_nfb"] / pop)
    df["log_real_wage"] = np.log(raw["comp_nfb"] / raw["gdp_deflator"])

    df["inflation_q"] = raw["inflation_q"]
    df["inflation_ann"] = raw["inflation_ann"]
    for c in ("inflation_cpi_q", "inflation_cpi_ann",
              "inflation_core_q", "inflation_core_ann"):
        df[c] = raw[c]
    df["nominal_rate"] = raw["fedfunds"] / 4

    return df.dropna(how="all")


# ----------------------------------------------------------------------
# 3b. Dataset SW: Smets-Wouters (2007) observables, transformed for
#     estimation with the sw07-codes-original model files
#     (varobs: dy dc dinve labobs pinfobs dw robs).
#
#     Follows the original SW(2007) appendix construction: consumption
#     and investment are NOMINAL series deflated by the GDP deflator
#     (one-good model convention), investment is FIXED private
#     investment (no inventories), and hours are avg weekly hours x
#     civilian employment per capita. Current-vintage FRED data, so
#     revisions still imply small differences from usmodel_data.mat.
# ----------------------------------------------------------------------

def build_dataset_sw(raw):
    df = pd.DataFrame(index=raw.index)
    pop = raw["civ_pop"]
    pdef = raw["gdp_deflator"]

    # growth-rate observables: 100 x first difference of logs
    df["dy"] = 100 * np.log(raw["real_gdp"] / pop).diff()
    df["dc"] = 100 * np.log(raw["nom_pce"] / pdef / pop).diff()
    df["dinve"] = 100 * np.log(raw["nom_fpi"] / pdef / pop).diff()
    df["dw"] = 100 * np.log(raw["comp_nfb"] / pdef).diff()

    # hours: 100 x log(avg weekly hours x employment / population),
    # demeaned over the full sample (the residual mean is absorbed by
    # the estimated constant constelab)
    log_hours = 100 * np.log(raw["hours_weekly_nfb"] * raw["civ_emp"] / pop)
    df["labobs"] = log_hours - log_hours.mean()

    df["pinfobs"] = raw["inflation_q"]      # 100 x dlog(GDP deflator)
    df["robs"] = raw["fedfunds"] / 4        # quarterly fed funds rate, %

    return df.dropna(how="all")


# ----------------------------------------------------------------------
# 4. Data transformations the paper compares (Section 2):
#    LT (linear detrend), HP filter, FOD (growth rate / first difference
#    of logs), BP (band-pass filter)
# ----------------------------------------------------------------------

def linear_detrend(x):
    """Residual from OLS regression of x on a constant and linear trend."""
    x = x.dropna()
    t = np.arange(len(x))
    X = np.column_stack([np.ones_like(t), t])
    beta, *_ = np.linalg.lstsq(X, x.values, rcond=None)
    resid = x.values - X @ beta
    return pd.Series(resid, index=x.index)


def hp_filter(x, lam=1600):
    """Hodrick-Prescott filter; returns (trend, cycle)."""
    from statsmodels.tsa.filters.hp_filter import hpfilter
    cycle, trend = hpfilter(x.dropna(), lamb=lam)
    return trend, cycle


def first_diff(x):
    """FOD: first difference of logs (i.e. approximate growth rate)."""
    return x.diff().dropna()


def bandpass_filter(x, low=6, high=32, K=12):
    """Christiano-Fitzgerald band-pass filter, business-cycle band."""
    from statsmodels.tsa.filters.cf_filter import cffilter
    cycle, trend = cffilter(x.dropna(), low=low, high=high, drift=True)
    return cycle


# ----------------------------------------------------------------------
# 5. Saving in a Dynare-readable form
# ----------------------------------------------------------------------

def blank_covid(df, quarters=COVID_QUARTERS):
    """Set the observables to NaN in the given quarters, keeping the rows.

    Deleting the rows instead would leave a hole in the quarterly index and
    silently shift every later date; writing NaN marks the quarters as
    unobserved, which is what the Kalman filter wants. my_dummy stays at 1:
    it is a constant regressor, not data, and the trend-growth constant is
    still identified in those quarters.
    """
    out = df.copy()
    stamps = [pd.Period(q, freq="Q").to_timestamp() for q in quarters]
    hit = out.index.intersection(stamps)
    cols = [c for c in out.columns if c != "my_dummy"]
    out.loc[hit, cols] = np.nan
    return out


def to_dynare_csv(df, filename, obs_prefix=False):
    """Write df to CSV so that Dynare's dseries can read it.

    Two things Dynare needs that pandas does not do by default:
      - dates as Dynare quarterly strings (1980Q1); the ISO dates pandas
        writes raise "The input cannot be interpreted as a date"
      - with obs_prefix, observable columns renamed to obs_<name>, which
        is what varobs in univariate_model.mod and the column filter in
        create_lfm_scalars.py both expect (my_dummy keeps its name)
    """
    out = df.copy()
    if obs_prefix:
        out.columns = [c if c == "my_dummy" else f"obs_{c}" for c in out.columns]
    out.index = pd.Index([f"{d.year}Q{d.quarter}" for d in out.index], name="date")
    out.to_csv(filename)
    return out


# ----------------------------------------------------------------------
# 6. Main
# ----------------------------------------------------------------------

if __name__ == "__main__":
    raw = download_raw()

    # Add a constant/dummy column of ones to the original dataset
    raw["my_dummy"] = 1

    raw.to_csv("canova_raw_fred_data.csv")
    print(f"Saved raw FRED series -> canova_raw_fred_data.csv  ({raw.shape[0]} rows)")

    if EXCLUDE_COVID:
        print(f"Covid quarters marked unobserved (NaN): {', '.join(COVID_QUARTERS)}")

    dataset_a = build_dataset_a(raw)
    dataset_a["my_dummy"] = 1
    assert dataset_a["inflation_q"].notna().sum() > 0, "inflation_q is empty in Dataset A!"
    if EXCLUDE_COVID:
        dataset_a = blank_covid(dataset_a)
    # full range, one row per quarter from 1947 to the latest observation;
    # this is what univariate_model.mod estimates on
    to_dynare_csv(dataset_a, "canova_dataset_A_small_NK.csv", obs_prefix=True)
    print(f"Saved Dataset A (small NK model observables) -> canova_dataset_A_small_NK.csv "
          f"({dataset_a.shape[0]} rows, {dataset_a.index[0]:%YQ}{dataset_a.index[0].quarter} to "
          f"{dataset_a.index[-1]:%YQ}{dataset_a.index[-1].quarter})")

    dataset_b = build_dataset_b(raw)
    dataset_b["my_dummy"] = 1
    assert dataset_b["inflation_q"].notna().sum() > 0, "inflation_q is empty in Dataset B!"
    if EXCLUDE_COVID:
        dataset_b = blank_covid(dataset_b)
    to_dynare_csv(dataset_b, "canova_dataset_B_medium_scale.csv", obs_prefix=True)
    print(f"Saved Dataset B (medium-scale model observables) -> canova_dataset_B_medium_scale.csv")

    # Sub-samples used in the paper's applications
    for name, (s, e) in {
        "table2_1980_2007": SAMPLE_TABLE2,
        "policy_activism_early_1964_1979": SAMPLE_EARLY,
        "policy_activism_late_1984_2007": SAMPLE_LATE,
    }.items():
        sub = dataset_a.loc[s:e]
        fname = f"canova_dataset_A_{name}.csv"
        to_dynare_csv(sub, fname, obs_prefix=True)
        print(f"Saved sub-sample -> {fname}  ({sub.shape[0]} obs)")

    sw_sub = dataset_b.loc[SAMPLE_SW[0]:SAMPLE_SW[1]]
    to_dynare_csv(sw_sub, "canova_dataset_B_SW_sample_1966_2004.csv", obs_prefix=True)
    print("Saved Dataset B SW(2007) sample -> canova_dataset_B_SW_sample_1966_2004.csv "
          f"({sw_sub.shape[0]} obs)")

    # Dataset SW: the seven SW(2007) observables, ready for Dynare
    # estimation with the sw07-codes-original model files.
    # NB: no obs_ prefix here -- the SW07 mod files declare the observables
    # under their own names (varobs dy dc dinve labobs pinfobs dw robs)
    dataset_sw = build_dataset_sw(raw)
    dataset_sw["my_dummy"] = 1
    # fix the balanced row set before blanking, so the covid quarters stay in
    # the panel as unobserved rows instead of being dropped by dropna()
    balanced_rows = dataset_sw.dropna().index
    if EXCLUDE_COVID:
        dataset_sw = blank_covid(dataset_sw)
    to_dynare_csv(dataset_sw, "canova_dataset_SW_observables.csv")
    print(f"Saved Dataset SW (SW07 observables) -> canova_dataset_SW_observables.csv "
          f"({dataset_sw.shape[0]} rows)")

    # balanced panel (no missing values in any observable): starts when the
    # fed funds rate becomes available (1954Q3), ends at the latest quarter
    # covered by all series -- this is the estimation-ready database
    sw_balanced = dataset_sw.loc[balanced_rows]
    to_dynare_csv(sw_balanced, "canova_dataset_SW_observables_balanced.csv")
    print(f"Saved Dataset SW balanced panel -> "
          f"canova_dataset_SW_observables_balanced.csv "
          f"({sw_balanced.shape[0]} obs, {sw_balanced.index[0]:%Y-%m} to "
          f"{sw_balanced.index[-1]:%Y-%m})")

    # original SW(2007) estimation sample, kept as a replication benchmark
    sw_est = dataset_sw.loc[SAMPLE_SW[0]:SAMPLE_SW[1]]
    to_dynare_csv(sw_est, "canova_dataset_SW_observables_1966_2004.csv")
    print(f"Saved Dataset SW replication benchmark sample -> "
          f"canova_dataset_SW_observables_1966_2004.csv ({sw_est.shape[0]} obs)")

    # Example: apply the four statistical transformations Table 2 compares,
    # for output in Dataset A over the 1980-2007 sample.
    y = dataset_a.loc[SAMPLE_TABLE2[0]:SAMPLE_TABLE2[1], "log_output"]
    lt = linear_detrend(y)
    trend, hp_cycle = hp_filter(y)
    fod = first_diff(y)
    bp_cycle = bandpass_filter(y)
    transformed = pd.concat(
        {"LT": lt, "HP": hp_cycle, "FOD": fod, "BP": bp_cycle}, axis=1
    )
    transformed.to_csv("canova_output_transformations_example.csv")
    print("Saved example LT/HP/FOD/BP transformations of output -> "
          "canova_output_transformations_example.csv")