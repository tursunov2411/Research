import requests
import csv
import os

indicators = {
    "NE.TRD.GNFS.ZS": "trade_pct_gdp",
    "NV.IND.MANF.ZS": "mfg_va_pct_gdp",
    "NY.GDP.MKTP.CD": "gdp_usd"
}

data_rows = []
for ind, name in indicators.items():
    url = f"https://api.worldbank.org/v2/country/UZ/indicator/{ind}?format=json&date=2010:2025&per_page=100"
    try:
        resp = requests.get(url)
        if resp.status_code == 200:
            data = resp.json()
            if len(data) > 1 and data[1]:
                for item in data[1]:
                    year = item["date"]
                    val = item["value"]
                    data_rows.append({"year": int(year), "indicator": name, "value": val})
    except Exception as e:
        print(f"Error fetching {ind}: {e}")

# Pivot data
pivoted = {}
for row in data_rows:
    y = row["year"]
    if y not in pivoted:
        pivoted[y] = {"year": y}
    pivoted[y][row["indicator"]] = row["value"]

# Add dummy ECI as original R script
eci_map = {
    2010: -0.65, 2012: -0.70, 2014: -0.60, 2016: -0.55, 2017: -0.48,
    2018: -0.40, 2019: -0.35, 2020: -0.42, 2021: -0.30, 2022: -0.18, 2023: -0.10
}
for y in pivoted:
    pivoted[y]["eci"] = eci_map.get(y, None)

# Add trade openness idx
base_trade = pivoted.get(2010, {}).get("trade_pct_gdp")
if base_trade:
    for y in pivoted:
        if pivoted[y].get("trade_pct_gdp") is not None:
            pivoted[y]["trade_openness_idx"] = (pivoted[y]["trade_pct_gdp"] / base_trade) * 100

os.makedirs("data", exist_ok=True)
with open("data/macro_data.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["year", "trade_pct_gdp", "mfg_va_pct_gdp", "gdp_usd", "eci", "trade_openness_idx"])
    writer.writeheader()
    for y in sorted(pivoted.keys()):
        writer.writerow(pivoted[y])
print("Updated World Bank data")
