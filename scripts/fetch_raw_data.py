import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
YEARS = list(range(2010, 2024))
COUNTRIES = {"UZB": "uzb", "VNM": "vnm"}


def fetch_json(url):
    last_error = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=180) as response:
                return json.loads(response.read().decode("utf-8-sig"))
        except Exception as error:
            last_error = error
            time.sleep(2 + attempt)
    raise last_error


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def world_bank_indicator(indicator, countries, start, end, source=None):
    rows = []
    for country in countries:
        url = (
            f"https://api.worldbank.org/v2/country/{country}/indicator/{indicator}"
            f"?format=json&date={start}:{end}&per_page=20000"
        )
        if source:
            url += f"&source={source}"
        data = fetch_json(url)
        if not isinstance(data, list) or len(data) < 2:
            continue
        for item in data[1]:
            rows.append(
                {
                    "country_code": item["countryiso3code"],
                    "country": item["country"]["value"],
                    "year": item["date"],
                    "indicator_code": indicator,
                    "indicator": item["indicator"]["value"],
                    "value": item["value"],
                    "source_url": url,
                }
            )
    return rows


def oec_query(cube, drilldowns, measures, filters):
    params = {
        "cube": cube,
        "drilldowns": ",".join(drilldowns),
        "measures": ",".join(measures),
    }
    params.update(filters)
    return fetch_json(
        "https://api.oec.world/tesseract/data.jsonrecords?"
        + urllib.parse.urlencode(params)
    )


def fetch_eci():
    rows = []
    for iso3, oec_id in COUNTRIES.items():
        data = oec_query(
            "complexity_eci_a_hs92_hs4",
            ["Country Official", "Year"],
            ["ECI"],
            {"Country Official": oec_id, "Year": ",".join(map(str, YEARS))},
        )
        for item in data.get("data", []):
            rows.append(
                {
                    "country_code": iso3,
                    "country": item["Country Official"],
                    "year": item["Year"],
                    "eci": item["ECI"],
                    "source": "OEC Economic Complexity Indicators, HS4 REV. 1992",
                    "source_url": "https://api.oec.world/tesseract/data.jsonrecords",
                }
            )
    return rows


def fetch_exports():
    rows = []
    for iso3, oec_id in COUNTRIES.items():
        data = oec_query(
            "trade_i_baci_a_92",
            ["Year", "Exporter Country Official", "Section Official"],
            ["Trade Value"],
            {"Exporter Country Official": oec_id, "Year": ",".join(map(str, YEARS))},
        )
        for item in data.get("data", []):
            rows.append(
                {
                    "country_code": iso3,
                    "country": item["Exporter Country Official"],
                    "year": item["Year"],
                    "hs_section_code": item["Section Official ID"],
                    "hs_section": item["Section Official"],
                    "trade_value_usd": item["Trade Value"],
                    "source": "OEC/BACI HS6 REV. 1992, derived from international merchandise trade data",
                    "source_url": "https://api.oec.world/tesseract/data.jsonrecords",
                }
            )
        time.sleep(0.5)
    return rows


def fetch_uzbekstat_available():
    url = "https://api.siat.stat.uz/media/uploads/sdmx/sdmx_data_1336.json"
    data = fetch_json(url)
    metadata = data[0].get("metadata", [])
    indicator_name = next(
        (
            item.get("value_en")
            for item in metadata
            if item.get("name_en") == "Indicator name"
        ),
        "Share of foreign investments and loans in investments in fixed assets",
    )
    rows = []
    for item in data[0].get("data", []):
        for year in YEARS:
            value = item.get(str(year))
            if value is not None:
                rows.append(
                    {
                        "country_or_region_code": item.get("Code"),
                        "country_or_region": item.get("Klassifikator_en"),
                        "year": year,
                        "indicator": indicator_name,
                        "value_percent": value,
                        "source": "National Statistics Committee of Uzbekistan / SIAT",
                        "source_url": url,
                        "note": "Official SIAT table available via API; this is by territory, not the requested sector breakdown.",
                    }
                )
    return rows


def main():
    RAW.mkdir(parents=True, exist_ok=True)

    gdp_rows = []
    for indicator in ["NY.GDP.MKTP.CD", "NV.IND.MANF.ZS"]:
        gdp_rows.extend(world_bank_indicator(indicator, ["UZB", "VNM"], 2010, 2023))
    write_csv(
        RAW / "gdp_worldbank.csv",
        ["country_code", "country", "year", "indicator_code", "indicator", "value", "source_url"],
        sorted(gdp_rows, key=lambda row: (row["country_code"], row["indicator_code"], row["year"])),
    )

    lpi_rows = world_bank_indicator("LP.LPI.OVRL.XQ", ["UZB", "VNM"], 2010, 2023)
    write_csv(
        RAW / "lpi_worldbank.csv",
        ["country_code", "country", "year", "indicator_code", "indicator", "value", "source_url"],
        sorted(lpi_rows, key=lambda row: (row["country_code"], row["year"])),
    )

    db_rows = []
    for indicator in ["IC.BUS.EASE.XQ", "IC.BUS.EASE.DFRN.XQ.DB1719"]:
        db_rows.extend(world_bank_indicator(indicator, ["UZB", "VNM"], 2016, 2023, source=1))
    write_csv(
        RAW / "doing_business_worldbank.csv",
        ["country_code", "country", "year", "indicator_code", "indicator", "value", "source_url"],
        sorted(db_rows, key=lambda row: (row["country_code"], row["indicator_code"], row["year"])),
    )

    fdi_rows = world_bank_indicator("BX.KLT.DINV.CD.WD", ["UZB", "VNM"], 2010, 2023)
    write_csv(
        RAW / "fdi_unctad.csv",
        ["country_code", "country", "year", "indicator_code", "indicator", "value", "source_url"],
        sorted(fdi_rows, key=lambda row: (row["country_code"], row["year"])),
    )

    eci_rows = fetch_eci()
    write_csv(
        RAW / "eci_mit.csv",
        ["country_code", "country", "year", "eci", "source", "source_url"],
        sorted(eci_rows, key=lambda row: (row["country_code"], row["year"])),
    )

    export_rows = fetch_exports()
    uzb_exports = [row for row in export_rows if row["country_code"] == "UZB"]
    write_csv(
        RAW / "exports_comtrade.csv",
        ["country_code", "country", "year", "hs_section_code", "hs_section", "trade_value_usd", "source", "source_url"],
        sorted(uzb_exports, key=lambda row: (row["year"], row["hs_section_code"])),
    )

    vnm_exports = [row for row in export_rows if row["country_code"] == "VNM"]
    comparison_rows = [
        {
            "dataset": "exports_by_hs_section",
            "country_code": row["country_code"],
            "country": row["country"],
            "year": row["year"],
            "variable": row["hs_section"],
            "value": row["trade_value_usd"],
            "source": row["source"],
        }
        for row in vnm_exports
    ]
    for row in gdp_rows + lpi_rows + db_rows + fdi_rows:
        if row["country_code"] == "VNM":
            comparison_rows.append(
                {
                    "dataset": "world_bank_indicator",
                    "country_code": row["country_code"],
                    "country": row["country"],
                    "year": row["year"],
                    "variable": row["indicator_code"],
                    "value": row["value"],
                    "source": row["indicator"],
                }
            )
    for row in eci_rows:
        if row["country_code"] == "VNM":
            comparison_rows.append(
                {
                    "dataset": "economic_complexity",
                    "country_code": row["country_code"],
                    "country": row["country"],
                    "year": row["year"],
                    "variable": "ECI",
                    "value": row["eci"],
                    "source": row["source"],
                }
            )
    write_csv(
        RAW / "vietnam_comparison.csv",
        ["dataset", "country_code", "country", "year", "variable", "value", "source"],
        sorted(comparison_rows, key=lambda row: (row["dataset"], row["year"], row["variable"])),
    )

    uzbekstat_rows = fetch_uzbekstat_available()
    write_csv(
        RAW / "fdi_uzbekstat.csv",
        ["country_or_region_code", "country_or_region", "year", "indicator", "value_percent", "source", "source_url", "note"],
        sorted(uzbekstat_rows, key=lambda row: (row["country_or_region_code"], row["year"])),
    )

    manifest_rows = [
        {
            "file": "gdp_worldbank.csv",
            "status": "fetched",
            "source": "World Bank API",
            "note": "GDP current US dollars and manufacturing value added share for UZB and VNM, 2010-2023.",
        },
        {
            "file": "lpi_worldbank.csv",
            "status": "fetched",
            "source": "World Bank API",
            "note": "LPI score for available survey years in 2010-2023.",
        },
        {
            "file": "doing_business_worldbank.csv",
            "status": "fetched",
            "source": "World Bank API / Doing Business archive indicators",
            "note": "Doing Business rank and DB17-20 methodology score where available; series discontinued after 2020.",
        },
        {
            "file": "fdi_unctad.csv",
            "status": "fetched_proxy",
            "source": "World Bank API indicator BX.KLT.DINV.CD.WD",
            "note": "Aggregate FDI net inflows, not source-country breakdown. World Bank metadata cites IMF, UNCTAD, and official sources.",
        },
        {
            "file": "fdi_uzbekstat.csv",
            "status": "fetched_partial",
            "source": "Uzbekistan SIAT/stat.uz API",
            "note": "Official available table is foreign investments and loans share by territory, not sector inflows in USD.",
        },
        {
            "file": "exports_comtrade.csv",
            "status": "fetched_proxy",
            "source": "OEC/BACI public API",
            "note": "Uzbekistan exports by HS section in USD. UN Comtrade direct API returned 401 without an API key.",
        },
        {
            "file": "eci_mit.csv",
            "status": "fetched",
            "source": "OEC Economic Complexity Indicators",
            "note": "ECI for UZB and VNM, HS4 REV. 1992, 2010-2023.",
        },
        {
            "file": "vietnam_comparison.csv",
            "status": "fetched",
            "source": "Same APIs as above",
            "note": "Vietnam comparison extract for indicators and exports.",
        },
    ]
    write_csv(RAW / "source_manifest.csv", ["file", "status", "source", "note"], manifest_rows)


if __name__ == "__main__":
    main()
