import requests
import json
import time

themes = {
    "gvc_theory": "Global Value Chains OR GVC OR global production networks",
    "industrial_policy": "industrial policy OR developmental state",
    "strategic_trade": "strategic trade theory",
    "flying_geese": "flying geese model OR East Asian industrialization",
    "china_plus_one": "China plus one OR supply chain restructuring",
    "vietnam_thailand": "Vietnam industrialization OR Thailand Eastern Seaboard model",
    "sez_policy": "Special Economic Zones OR SEZ policy",
    "bri_central_asia": "Belt and Road Initiative Central Asia OR Central Asian development",
    "uzbekistan_reforms": "Uzbekistan economic reforms OR Uzbekistan industrialization",
    "landlocked": "landlocked developing countries OR trade costs landlocked",
    "fdi_tech_transfer": "foreign direct investment technology transfer OR FDI spillovers",
    "logistics_eurasian": "logistics Eurasian corridors"
}

bibtex_entries = []
seen_dois = set()

def fetch_works(query, max_results=30):
    url = "https://api.openalex.org/works"
    params = {
        "search": query,
        "filter": "publication_year:2020-2026,type:article|book-chapter",
        "sort": "cited_by_count:desc",
        "per-page": max_results,
        "mailto": "research@example.com"
    }
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return data.get("results", [])
    except Exception as e:
        print(f"Error fetching {query}: {e}")
        return []

def format_bibtex(work, theme):
    doi = work.get("doi")
    if not doi or doi in seen_dois:
        return None
    seen_dois.add(doi)
    
    doi_clean = doi.replace("https://doi.org/", "")
    bib_key = doi_clean.replace("/", "_").replace(".", "_").replace("-", "_")
    
    title = work.get("title", "")
    year = work.get("publication_year", "")
    
    authors = []
    for auth in work.get("authorships", []):
        name = auth.get("author", {}).get("display_name")
        if name:
            authors.append(name)
    author_str = " and ".join(authors) if authors else "Unknown"
    
    journal = ""
    volume = ""
    issue = ""
    pages = ""
    host = work.get("primary_location", {}).get("source", {})
    if host:
        journal = host.get("display_name", "")
    
    if work.get("primary_location", {}).get("volume"):
        volume = work.get("primary_location").get("volume")
    if work.get("primary_location", {}).get("issue"):
        issue = work.get("primary_location").get("issue")
    
    bib = f"@article{{{bib_key},\n"
    bib += f"  title = {{{title}}},\n"
    bib += f"  author = {{{author_str}}},\n"
    bib += f"  journal = {{{journal}}},\n"
    if volume: bib += f"  volume = {{{volume}}},\n"
    if issue: bib += f"  number = {{{issue}}},\n"
    bib += f"  year = {{{year}}},\n"
    bib += f"  doi = {{{doi_clean}}},\n"
    bib += f"  note = {{Theme: {theme.replace('_', ' ')}}}\n"
    bib += f"}}\n"
    return bib

print("Fetching literature from OpenAlex...")
for theme, query in themes.items():
    print(f"Querying for: {theme}")
    works = fetch_works(query, max_results=30)
    for w in works:
        bib = format_bibtex(w, theme)
        if bib:
            bibtex_entries.append(bib)
    time.sleep(1) # rate limiting

with open("references_expanded.bib", "w", encoding="utf-8") as f:
    f.write("\n".join(bibtex_entries))

print(f"Successfully generated references_expanded.bib with {len(bibtex_entries)} references.")

