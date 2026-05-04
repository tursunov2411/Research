"""Generate 2026 update figures and data tables.

The figures intentionally avoid embedding figure numbers in the image itself;
numbering belongs in the LaTeX captions.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "processed"
FIG_DIR = ROOT / "figures"
TABLE_DIR = ROOT / "output" / "tables"
for path in (DATA_DIR, FIG_DIR, TABLE_DIR):
    path.mkdir(parents=True, exist_ok=True)

COUNTRIES = {
    "UZB": {"name": "Uzbekistan", "oec": "uzb", "reform": 2017, "color": "#1b9aaa"},
    "VNM": {"name": "Vietnam", "oec": "vnm", "reform": 2007, "color": "#ef476f"},
    "KAZ": {"name": "Kazakhstan", "oec": "kaz", "reform": 2014, "color": "#f4a261"},
    "THA": {"name": "Thailand", "oec": "tha", "reform": 1978, "color": "#2a9d8f"},
    "GEO": {"name": "Georgia", "oec": "geo", "reform": 2016, "color": "#6c63ff"},
}

WDI_INDICATORS = {
    "mfg_va": "NV.IND.MANF.ZS",
    "fdi_gdp": "BX.KLT.DINV.WD.GD.ZS",
    "lpi": "LP.LPI.OVRL.XQ",
    "trade_open": "NE.TRD.GNFS.ZS",
    "gdp_pc": "NY.GDP.PCAP.CD",
}


def fetch_json(url: str):
    last_error = None
    for attempt in range(4):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=180) as response:
                return json.loads(response.read().decode("utf-8-sig"))
        except Exception as error:
            last_error = error
            time.sleep(2 + attempt)
    raise last_error


def fetch_wdi(start: int = 1995, end: int = 2024) -> pd.DataFrame:
    rows: list[dict] = []
    country_query = ";".join(COUNTRIES)
    for name, indicator in WDI_INDICATORS.items():
        try:
            url = (
                f"https://api.worldbank.org/v2/country/{country_query}/indicator/{indicator}"
                f"?format=json&date={start}:{end}&per_page=20000"
            )
            data = fetch_json(url)
            if not isinstance(data, list) or len(data) < 2:
                continue
            for item in data[1]:
                rows.append(
                    {
                        "country_code": iso3,
                        "country": item["country"]["value"],
                        "year": int(item["date"]),
                        "series": name,
                        "indicator": indicator,
                        "value": item["value"],
                    }
                )
        except Exception:
            for iso3 in COUNTRIES:
                url = (
                    f"https://api.worldbank.org/v2/country/{iso3}/indicator/{indicator}"
                    f"?format=json&date={start}:{end}&per_page=20000"
                )
                data = fetch_json(url)
                if not isinstance(data, list) or len(data) < 2:
                    continue
                for item in data[1]:
                    rows.append(
                        {
                            "country_code": item["countryiso3code"],
                            "country": item["country"]["value"],
                            "year": int(item["date"]),
                            "series": name,
                            "indicator": indicator,
                            "value": item["value"],
                        }
                    )
                time.sleep(0.1)
    wide = (
        pd.DataFrame(rows)
        .pivot_table(index=["country_code", "country", "year"], columns="series", values="value", aggfunc="first")
        .reset_index()
    )
    wide.to_csv(DATA_DIR / "wdi_1995_2024_update.csv", index=False)
    return wide


def fetch_eci(start: int = 1995, end: int = 2024) -> pd.DataFrame:
    rows: list[dict] = []
    years = ",".join(str(y) for y in range(start, end + 1))
    for iso3, meta in COUNTRIES.items():
        params = {
            "cube": "complexity_eci_a_hs92_hs4",
            "drilldowns": "Country Official,Year",
            "measures": "ECI",
            "Country Official": meta["oec"],
            "Year": years,
        }
        url = "https://api.oec.world/tesseract/data.jsonrecords?" + urllib.parse.urlencode(params)
        data = fetch_json(url)
        for item in data.get("data", []):
            rows.append(
                {
                    "country_code": iso3,
                    "country": item["Country Official"],
                    "year": int(item["Year"]),
                    "eci": item["ECI"],
                }
            )
        time.sleep(0.2)
    eci = pd.DataFrame(rows)
    eci.to_csv(DATA_DIR / "eci_1995_2024_update.csv", index=False)
    return eci


def style_axes(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(True, axis="y", color="#d9e0e6", linewidth=0.8)
    ax.tick_params(labelsize=9)


def plot_structural_break(wdi: pd.DataFrame) -> None:
    uz = wdi[(wdi.country_code == "UZB") & wdi.mfg_va.notna()].sort_values("year")
    fig, ax = plt.subplots(figsize=(9, 5.4), dpi=180)
    hist = uz[uz.year <= 2024]
    ax.plot(hist.year, hist.mfg_va, color="#1b9aaa", marker="o", linewidth=2, label="WDI historical")

    pre = hist[hist.year <= 2016]
    post = hist[hist.year >= 2017]
    for frame, color, label in [(pre, "#6b7280", "Pre-2017 linear fit"), (post, "#ef476f", "Post-2017 linear fit")]:
        if len(frame) >= 3:
            fit = np.polyfit(frame.year, frame.mfg_va, 1)
            years = np.arange(frame.year.min(), frame.year.max() + 1)
            ax.plot(years, np.polyval(fit, years), color=color, linestyle="--", linewidth=1.8, label=label)

    if len(post) >= 3:
        fit = np.polyfit(post.year, post.mfg_va, 1)
        proj_years = np.array([2025, 2026])
        proj_vals = np.polyval(fit, proj_years)
        ax.axvspan(2024.5, 2026.5, color="#f4a261", alpha=0.16, label="Projection window")
        ax.plot(proj_years, proj_vals, color="#ef476f", marker="o", linestyle=":", linewidth=2, label="Author trend projection")
        pd.DataFrame({"year": proj_years, "mfg_va_projected": proj_vals}).to_csv(
            TABLE_DIR / "table_fig1r_mfg_projection.csv", index=False
        )

    ax.axvline(2017, color="#102a43", linestyle="-", linewidth=1)
    ax.text(2017.2, ax.get_ylim()[0] + 0.15, "2017 reform", fontsize=9, color="#102a43")
    ax.set_xlabel("Year")
    ax.set_ylabel("Manufacturing VA (% GDP)")
    ax.set_title("Manufacturing value added, Uzbekistan, 1995-2026", fontsize=13, weight="bold")
    ax.legend(frameon=False, fontsize=8, loc="best")
    style_axes(ax)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "fig1R_extended_structural_break.png", bbox_inches="tight")
    plt.close(fig)


def plot_comparative(wdi: pd.DataFrame, eci: pd.DataFrame) -> None:
    data = wdi.merge(eci[["country_code", "year", "eci"]], on=["country_code", "year"], how="left")
    data["reform_year"] = data.apply(lambda row: row.year - COUNTRIES[row.country_code]["reform"], axis=1)
    fig, axes = plt.subplots(2, 2, figsize=(12, 8), dpi=180)
    panels = [
        ("mfg_va", "Manufacturing VA (% GDP)"),
        ("fdi_gdp", "FDI net inflows (% GDP)"),
        ("lpi", "LPI score"),
        ("eci", "Economic Complexity Index"),
    ]
    for ax, (col, ylabel) in zip(axes.ravel(), panels):
        for iso3 in ["UZB", "VNM", "KAZ", "THA"]:
            frame = data[(data.country_code == iso3) & data[col].notna()].sort_values("reform_year")
            if frame.empty:
                continue
            frame = frame[(frame.reform_year >= -5) & (frame.reform_year <= 12)]
            if frame.empty and iso3 == "THA":
                frame = data[(data.country_code == iso3) & data[col].notna()].sort_values("reform_year")
            ax.plot(
                frame.reform_year,
                frame[col],
                marker="o",
                linewidth=1.8,
                markersize=3.5,
                color=COUNTRIES[iso3]["color"],
                label=COUNTRIES[iso3]["name"],
            )
        ax.axvline(0, color="#102a43", linewidth=1, linestyle="--")
        ax.set_xlabel("Years since reform")
        ax.set_ylabel(ylabel)
        style_axes(ax)
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, ncol=4, frameon=False, loc="lower center")
    fig.suptitle("Comparative reform trajectories", fontsize=14, weight="bold")
    fig.tight_layout(rect=[0, 0.05, 1, 0.96])
    fig.savefig(FIG_DIR / "fig12R_comparative_trajectory.png", bbox_inches="tight")
    plt.close(fig)


def plot_middle_corridor() -> None:
    cargo = pd.DataFrame(
        {
            "year": [2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025],
            "tonnes_m": [0.8, 0.8, 0.8, 0.84, 1.5, 2.76, 4.48, 4.12],
        }
    )
    teu = pd.DataFrame({"year": [2023, 2024, 2025], "teu": [20500, 55000, 77000]})
    cargo.to_csv(TABLE_DIR / "table_middle_corridor_cargo.csv", index=False)
    teu.to_csv(TABLE_DIR / "table_middle_corridor_teu.csv", index=False)

    fig, ax1 = plt.subplots(figsize=(9, 5.2), dpi=180)
    ax1.bar(cargo.year, cargo.tonnes_m, color="#1b9aaa", alpha=0.82, label="Cargo volume (m tonnes)")
    ax1.set_ylabel("Cargo volume (million tonnes)")
    ax1.set_xlabel("Year")
    ax2 = ax1.twinx()
    ax2.plot(teu.year, teu.teu, color="#ef476f", marker="o", linewidth=2, label="Container traffic (TEU)")
    ax2.set_ylabel("Container traffic (TEU)")
    for x, label in [(2022, "Russia invasion"), (2024, "Coordination push")]:
        ax1.axvline(x, color="#6b7280", linestyle="--", linewidth=0.9)
        ax1.text(x + 0.05, ax1.get_ylim()[1] * 0.88, label, rotation=90, fontsize=8, color="#4b5563")
    ax1.set_title("Middle Corridor freight growth, 2018-2025", fontsize=13, weight="bold")
    style_axes(ax1)
    ax2.spines["top"].set_visible(False)
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, frameon=False, fontsize=8, loc="upper left")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "fig_newB_middle_corridor.png", bbox_inches="tight")
    plt.close(fig)


def plot_wto_tracker() -> None:
    milestones = pd.DataFrame(
        [
            ("2020-07-07", "WTO talks restart after long pause"),
            ("2024-05-01", "7th Working Party meeting"),
            ("2024-12-01", "8th Working Party meeting"),
            ("2025-06-01", "9th Working Party meeting"),
            ("2025-10-24", "EU EPCA signed"),
            ("2025-11-05", "10th Working Party meeting"),
            ("2025-12-21", "Russia bilateral protocol"),
            ("2026-03-26", "MC14 target window"),
        ],
        columns=["date", "label"],
    )
    milestones["date"] = pd.to_datetime(milestones["date"])
    milestones.to_csv(TABLE_DIR / "table_wto_tracker.csv", index=False)
    fig, ax = plt.subplots(figsize=(10, 4.8), dpi=180)
    y = np.arange(len(milestones))
    ax.scatter(milestones.date, y, color="#1b9aaa", s=70, zorder=3)
    ax.hlines(y, milestones.date.min(), milestones.date, color="#b7c3d0", linewidth=2)
    for yi, row in zip(y, milestones.itertuples()):
        ax.text(row.date, yi + 0.18, row.label, fontsize=8.5, ha="left")
    ax.set_yticks([])
    ax.set_xlabel("Date")
    ax.set_title("Uzbekistan WTO accession progress, 2020-2026", fontsize=13, weight="bold")
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.grid(True, axis="x", color="#d9e0e6")
    fig.autofmt_xdate()
    fig.tight_layout()
    fig.savefig(FIG_DIR / "fig_newA_wto_tracker.png", bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    wdi = fetch_wdi()
    eci = fetch_eci()
    plot_structural_break(wdi)
    plot_comparative(wdi, eci)
    plot_middle_corridor()
    plot_wto_tracker()
    print("Generated 2026 update figures and tables.")


if __name__ == "__main__":
    main()
