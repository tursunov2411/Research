"""Generate empirical robustness tables from cached dissertation data.

This companion script is intentionally dependency-light: it uses pandas/numpy
because R is not always available in the local build environment. The primary
R workflow remains in scripts/panel_robustness.R and scripts/11_ols_regression.R.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
TABLE_DIR = ROOT / "output" / "tables"
TABLE_DIR.mkdir(parents=True, exist_ok=True)


def _latex_escape(value: object) -> str:
    text = str(value)
    return (
        text.replace("\\", "\\textbackslash{}")
        .replace("&", "\\&")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )


def _norm_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / np.sqrt(2.0)))


def _stars(p: float) -> str:
    if p < 0.01:
        return "$^{***}$"
    if p < 0.05:
        return "$^{**}$"
    if p < 0.10:
        return "$^{*}$"
    return ""


def ols(y: np.ndarray, x: np.ndarray) -> dict[str, np.ndarray | float]:
    beta = np.linalg.lstsq(x, y, rcond=None)[0]
    resid = y - x @ beta
    n, k = x.shape
    xtx_inv = np.linalg.inv(x.T @ x)
    h = np.sum((x @ xtx_inv) * x, axis=1)
    sigma2 = float((resid @ resid) / max(n - k, 1))
    cov = sigma2 * xtx_inv
    return {"beta": beta, "resid": resid, "cov": cov, "h": h, "n": n, "k": k}


def clustered_hc3(model: dict[str, np.ndarray | float], x: np.ndarray, groups: pd.Series) -> np.ndarray:
    resid = model["resid"]
    h = np.clip(model["h"], 0, 0.99)
    adj_resid = resid / (1.0 - h)
    xtx_inv = np.linalg.inv(x.T @ x)
    meat = np.zeros((x.shape[1], x.shape[1]))
    for group in pd.unique(groups):
        idx = np.asarray(groups == group)
        xg = x[idx, :]
        eg = adj_resid[idx]
        score = xg.T @ eg
        meat += np.outer(score, score)
    g = groups.nunique()
    n, k = x.shape
    finite = (g / max(g - 1, 1)) * ((n - 1) / max(n - k, 1))
    return finite * xtx_inv @ meat @ xtx_inv


def vif_table(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    rows = []
    for col in columns:
        y = df[col].to_numpy(float)
        others = [c for c in columns if c != col]
        x = np.column_stack([np.ones(len(df)), df[others].to_numpy(float)])
        fit = ols(y, x)
        ssr = float(fit["resid"] @ fit["resid"])
        sst = float(((y - y.mean()) ** 2).sum())
        r2 = 1 - ssr / sst if sst else np.nan
        vif = 1 / (1 - r2) if r2 < 1 else np.inf
        rows.append({"Regressor": col, "VIF": vif})
    return pd.DataFrame(rows)


def regression_rows(names: list[str], beta: np.ndarray, cov: np.ndarray) -> list[tuple[str, str, str]]:
    rows = []
    se = np.sqrt(np.diag(cov))
    for name, b, s in zip(names, beta, se):
        z = abs(float(b / s)) if s > 0 else np.nan
        p = 2 * (1 - _norm_cdf(z)) if np.isfinite(z) else np.nan
        rows.append((name, f"{b:.3f}{_stars(p)}", f"({s:.3f})"))
    return rows


def make_panel_table() -> None:
    panel = pd.read_csv(ROOT / "data" / "processed" / "comparator_panel.csv")
    panel = panel.sort_values(["iso2c", "year"]).copy()
    panel["fdi_lag1"] = panel.groupby("iso2c")["fdi_pct_gdp"].shift(1)
    panel["post2017"] = (panel["year"] >= 2017).astype(int)
    panel["log_gdp_pc"] = np.log(panel["gdp_pc"])
    panel = panel.dropna(subset=["mfg_va", "fdi_lag1", "trade_open", "log_gdp_pc"])

    countries = sorted(panel["iso2c"].unique())
    dummies = pd.get_dummies(panel["iso2c"], drop_first=True, dtype=float)
    y = panel["mfg_va"].to_numpy(float)

    base = panel[["fdi_lag1", "trade_open", "post2017", "log_gdp_pc"]].to_numpy(float)
    x_pool = np.column_stack([np.ones(len(panel)), base])
    pool = ols(y, x_pool)
    pool_cov = clustered_hc3(pool, x_pool, panel["iso2c"])

    x_fe = np.column_stack([np.ones(len(panel)), base, dummies.to_numpy(float)])
    fe = ols(y, x_fe)
    fe_cov = clustered_hc3(fe, x_fe, panel["iso2c"])

    # Random-effects approximation via quasi-demeaning using FE residual variance.
    t_bar = panel.groupby("iso2c").size().mean()
    sigma_e2 = float((fe["resid"] @ fe["resid"]) / max(len(panel) - x_fe.shape[1], 1))
    country_means = panel.groupby("iso2c")["mfg_va"].mean()
    sigma_u2 = max(float(country_means.var(ddof=1) - sigma_e2 / t_bar), 0.0)
    theta = 1.0 - np.sqrt(sigma_e2 / (sigma_e2 + t_bar * sigma_u2)) if sigma_u2 > 0 else 0.0
    re_df = panel.copy()
    for col in ["mfg_va", "fdi_lag1", "trade_open", "post2017", "log_gdp_pc"]:
        re_df[col + "_bar"] = re_df.groupby("iso2c")[col].transform("mean")
        re_df[col + "_q"] = re_df[col] - theta * re_df[col + "_bar"]
    y_re = re_df["mfg_va_q"].to_numpy(float)
    x_re = np.column_stack(
        [
            np.ones(len(re_df)) * (1 - theta),
            re_df[["fdi_lag1_q", "trade_open_q", "post2017_q", "log_gdp_pc_q"]].to_numpy(float),
        ]
    )
    re = ols(y_re, x_re)
    re_cov = clustered_hc3(re, x_re, panel["iso2c"])

    names = ["Constant", "FDI (t-1)", "Trade openness", "Post-2017 dummy", "Log GDP per capita"]
    pool_rows = regression_rows(names, pool["beta"], pool_cov)
    re_rows = regression_rows(names, re["beta"], re_cov)
    fe_names = names + [f"Country: {c}" for c in dummies.columns]
    fe_map = {name: (coef, se) for name, coef, se in regression_rows(fe_names, fe["beta"], fe_cov)}

    table_rows = []
    for i, name in enumerate(names):
        pool_coef, pool_se = pool_rows[i][1], pool_rows[i][2]
        re_coef, re_se = re_rows[i][1], re_rows[i][2]
        if name == "Constant":
            fe_coef, fe_se = "--", "--"
        else:
            fe_coef, fe_se = fe_map[name]
        table_rows.extend(
            [
                f"{name} & {pool_coef} & {fe_coef} & {re_coef} \\\\",
                f" & {pool_se} & {fe_se} & {re_se} \\\\",
            ]
        )

    # Hausman test on slope coefficients, using conventional covariance matrices.
    b_fe = fe["beta"][1:5]
    b_re = re["beta"][1:5]
    cov_diff = fe["cov"][1:5, 1:5] - re["cov"][1:5, 1:5]
    try:
        h_stat = float((b_fe - b_re).T @ np.linalg.pinv(cov_diff) @ (b_fe - b_re))
        h_note = f"{h_stat:.3f} (df=4)"
    except Exception:
        h_note = "not estimable"

    tex = r"""
\begin{table}[!htbp]\centering
\caption{Panel Robustness Check: Manufacturing Value Added (\% GDP), 2011--2023}
\label{tab:panel_robustness}
\small
\begin{tabular}{lccc}
\hline\hline
 & Pooled OLS & Country FE & Random Effects \\
\hline
""" + "\n".join(table_rows) + rf"""
\hline
Observations & {len(panel)} & {len(panel)} & {len(panel)} \\
Countries & {len(countries)} & {len(countries)} & {len(countries)} \\
Country effects & No & Yes & Partial \\
Hausman FE vs RE & -- & \multicolumn{{2}}{{c}}{{{h_note}}} \\
\hline\hline
\multicolumn{{4}}{{p{{0.92\textwidth}}}}{{\footnotesize Notes: Balanced panel from cached WDI data for Georgia, Kazakhstan, Mongolia, Uzbekistan, and Viet Nam. Standard errors are HC3 robust and clustered by country. The panel starts in 2011 because FDI is lagged one year. The Hausman statistic is reported as a diagnostic; with only five country clusters, inference should be interpreted cautiously, and a wild cluster bootstrap would be preferable in a finalized appendix.}} \\
\end{{tabular}}
\end{{table}}
"""
    (TABLE_DIR / "panel_robustness.tex").write_text(tex, encoding="utf-8")

    summary = (
        "Panel robustness generated from cached WDI comparator panel\n"
        f"Countries: {', '.join(countries)}\n"
        f"Period after lag: {panel['year'].min()}-{panel['year'].max()}\n"
        f"Observations: {len(panel)}\n"
        f"Hausman diagnostic: {h_note}\n"
    )
    (TABLE_DIR / "panel_robustness_summary.txt").write_text(summary, encoding="utf-8")


def make_ols_diagnostic_tables() -> None:
    reg = pd.read_csv(TABLE_DIR / "table_ols_regression_data.csv").sort_values("year")
    reg1 = reg.dropna(subset=["fdi_lag1", "interm_share", "trade_openness", "post_2017", "time_trend"])

    vif_cols = ["fdi_lag1", "interm_share", "trade_openness", "post_2017", "time_trend"]
    vifs = vif_table(reg1, vif_cols)
    vifs["VIF"] = vifs["VIF"].round(2)
    vifs.to_csv(TABLE_DIR / "table_vif_diagnostics.csv", index=False)

    y = reg1["manuf_va_gdp"].to_numpy(float)
    x_trend = np.column_stack([np.ones(len(reg1)), reg1["time_trend"].to_numpy(float)])
    y_resid = ols(y, x_trend)["resid"]
    i_resid = ols(reg1["interm_share"].to_numpy(float), x_trend)["resid"]
    partial_corr = float(np.corrcoef(y_resid, i_resid)[0, 1])

    fd = reg.copy()
    for col in ["manuf_va_gdp", "interm_share", "fdi_gdp", "trade_openness"]:
        fd["d_" + col] = fd[col].diff()
    fd = fd.dropna(subset=["d_manuf_va_gdp", "d_interm_share", "d_fdi_gdp", "d_trade_openness"])
    y_fd = fd["d_manuf_va_gdp"].to_numpy(float)
    x_fd = np.column_stack(
        [
            np.ones(len(fd)),
            fd[["d_interm_share", "d_fdi_gdp", "d_trade_openness"]].to_numpy(float),
        ]
    )
    m_fd = ols(y_fd, x_fd)
    fd_rows = regression_rows(["Constant", "$\\Delta$ Intermediate share", "$\\Delta$ FDI", "$\\Delta$ Trade openness"], m_fd["beta"], m_fd["cov"])

    partner = pd.read_csv(TABLE_DIR / "table_intermediate_goods_share.csv")
    china = partner.loc[partner["partner"] == "China", ["year", "share_intermediate"]].rename(
        columns={"share_intermediate": "china_interm_share"}
    )
    jk = (
        partner.loc[partner["partner"].isin(["Japan", "South Korea"])]
        .groupby("year")
        .apply(lambda g: g["intermediate_imports_usd"].sum() / g["total_imports_usd"].sum(), include_groups=False)
        .reset_index(name="japan_korea_interm_share")
    )
    dec = reg1.merge(china, on="year").merge(jk, on="year")
    y_dec = dec["manuf_va_gdp"].to_numpy(float)
    x_dec = np.column_stack(
        [
            np.ones(len(dec)),
            dec[["china_interm_share", "japan_korea_interm_share", "fdi_lag1", "trade_openness", "time_trend"]].to_numpy(float),
        ]
    )
    m_dec = ols(y_dec, x_dec)
    dec_rows = regression_rows(
        ["Constant", "China intermediate share", "Japan+Korea intermediate share", "FDI (t-1)", "Trade openness", "Time trend"],
        m_dec["beta"],
        m_dec["cov"],
    )

    vif_tex_rows = "\n".join(
        f"{_latex_escape(row.Regressor)} & {row.VIF:.2f} \\\\" for row in vifs.itertuples(index=False)
    )
    fd_tex_rows = "\n".join(f"{name} & {coef} & {se} \\\\" for name, coef, se in fd_rows)
    dec_tex_rows = "\n".join(f"{name} & {coef} & {se} \\\\" for name, coef, se in dec_rows)
    tex = rf"""
\begin{{table}}[!htbp]\centering
\caption{{Diagnostics for the Negative Intermediate-Goods Coefficient}}
\label{{tab:intermediate_diagnostics}}
\small
\begin{{tabular}}{{lc}}
\hline\hline
Regressor & VIF \\
\hline
{vif_tex_rows}
\hline
\multicolumn{{2}}{{l}}{{Partial correlation, controlling for trend: {partial_corr:.3f}}} \\
\hline\hline
\end{{tabular}}
\quad
\begin{{tabular}}{{lcc}}
\hline\hline
First-difference model & Coef. & SE \\
\hline
{fd_tex_rows}
\hline\hline
\end{{tabular}}

\vspace{{0.75em}}
\begin{{tabular}}{{lcc}}
\hline\hline
Partner-decomposed level model & Coef. & SE \\
\hline
{dec_tex_rows}
\hline\hline
\end{{tabular}}
\begin{{minipage}}{{0.92\textwidth}}
\footnotesize Notes: VIFs use the single-country OLS specification in Table~\ref{{tab:ols_mfg}}. The partial correlation residualises both manufacturing VA and the aggregate intermediate-goods share on a linear time trend. First differences use annual changes over 2011--2023. Partner decomposition separates China's intermediate share from the combined Japan+Korea share; estimates are exploratory because the annual sample remains very small.
\end{{minipage}}
\end{{table}}
"""
    (TABLE_DIR / "intermediate_diagnostics.tex").write_text(tex, encoding="utf-8")


def main() -> None:
    make_panel_table()
    make_ols_diagnostic_tables()
    print("Generated panel_robustness.tex and intermediate_diagnostics.tex")


if __name__ == "__main__":
    main()
