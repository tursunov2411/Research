import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os

os.makedirs("policy_toolkit/figures", exist_ok=True)
os.makedirs("policy_toolkit/data", exist_ok=True)

# -------------------------------------------------------------
# OUTPUT 1: GVC READINESS SCORECARD
# -------------------------------------------------------------
countries = ["Uzbekistan", "Vietnam", "Thailand", "Kazakhstan"]
indicators = [
    "Logistics Performance", 
    "Governance Quality", 
    "SEZ Effectiveness", 
    "Human Capital", 
    "BIT/DTT Architecture", 
    "Energy Reliability", 
    "Supplier Ecosystem Depth", 
    "Customs Efficiency", 
    "Industrial Diversification", 
    "Technology Absorption"
]

# Simulated/Proxied data based on dissertation context (0 to 10 scale, 10 is best)
data_scores = {
    "Uzbekistan": [4.0, 4.5, 5.0, 6.5, 4.0, 5.5, 3.5, 4.0, 4.5, 3.0],
    "Vietnam": [6.5, 5.5, 7.5, 7.0, 8.0, 6.5, 7.0, 6.0, 7.5, 6.5],
    "Thailand": [7.5, 6.0, 8.5, 7.5, 8.5, 8.0, 8.5, 7.0, 8.0, 7.5],
    "Kazakhstan": [5.5, 5.0, 5.5, 7.0, 6.0, 7.0, 4.0, 5.0, 4.0, 4.5]
}

df_scores = pd.DataFrame(data_scores, index=indicators)
df_scores.to_csv("policy_toolkit/data/gvc_readiness_scores.csv")

# Generate Radar Chart
labels = np.array(indicators)
num_vars = len(labels)
angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
angles += angles[:1]

fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(polar=True))

colors = {"Uzbekistan": "#2E86C1", "Vietnam": "#E74C3C", "Thailand": "#27AE60", "Kazakhstan": "#F39C12"}

for country in countries:
    values = df_scores[country].tolist()
    values += values[:1]
    ax.plot(angles, values, color=colors[country], linewidth=2, label=country)
    ax.fill(angles, values, color=colors[country], alpha=0.1)

ax.set_theta_offset(np.pi / 2)
ax.set_theta_direction(-1)
ax.set_thetagrids(np.degrees(angles[:-1]), labels, fontsize=11)
ax.set_ylim(0, 10)
plt.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))
plt.title("GVC Readiness Scorecard: Comparative Framework", size=16, y=1.1, weight='bold')
plt.tight_layout()
plt.savefig("policy_toolkit/figures/gvc_readiness_radar.png", dpi=300, bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# OUTPUT 2: SECTOR TARGETING MATRIX
# -------------------------------------------------------------
sectors = [
    "Automotive Electronics", "Pharmaceuticals", "Technical Textiles", 
    "Machinery", "Copper Processing", "Electrical Components", 
    "Agro-processing", "Precision Instruments"
]

# Scoring based on dissertation logic (0 to 10 scale)
# vtw = Value-to-Weight (Logistics compatibility for landlocked)
# tech_spill = Technology Spillover Potential
# fdi_interest = NE Asian Investor Interest
# local_compat = Compatibility with Local Constraints
sector_data = {
    "Sector": sectors,
    "Value_to_Weight": [9.0, 8.5, 5.0, 4.0, 3.5, 8.0, 3.0, 9.5],
    "Tech_Spillover": [8.5, 7.5, 4.5, 7.0, 5.0, 7.5, 4.0, 9.0],
    "NE_Asian_Interest": [8.0, 5.0, 6.0, 6.5, 7.0, 8.5, 4.0, 7.5],
    "Local_Compatibility": [5.0, 6.0, 8.5, 5.5, 9.0, 6.0, 8.5, 4.0]
}

df_sectors = pd.DataFrame(sector_data)
# Calculate composite attractiveness
df_sectors["Composite_Attractiveness"] = df_sectors[["Value_to_Weight", "Tech_Spillover", "NE_Asian_Interest"]].mean(axis=1)
df_sectors.to_csv("policy_toolkit/data/sector_targeting_matrix.csv", index=False)

# Bubble Chart: Value-to-Weight vs Tech Spillover (Size = Local Compatibility, Color = NE Asian Interest)
plt.figure(figsize=(12, 8))
scatter = plt.scatter(
    df_sectors["Value_to_Weight"], 
    df_sectors["Tech_Spillover"], 
    s=df_sectors["Local_Compatibility"] * 100, 
    c=df_sectors["NE_Asian_Interest"], 
    cmap='viridis', 
    alpha=0.7, 
    edgecolors="w", 
    linewidth=2
)

for i, txt in enumerate(df_sectors["Sector"]):
    plt.annotate(txt, (df_sectors["Value_to_Weight"][i] + 0.15, df_sectors["Tech_Spillover"][i]), fontsize=11, weight='bold')

plt.colorbar(scatter, label="NE Asian Investor Interest (1-10)")
plt.axvline(x=6, color='gray', linestyle='--')
plt.axhline(y=6, color='gray', linestyle='--')

plt.title("Sector Targeting Matrix for Landlocked Industrialisation", fontsize=16, weight='bold')
plt.xlabel("Value-to-Weight Ratio (Logistics Resilience)", fontsize=12)
plt.ylabel("Technology Spillover Potential", fontsize=12)
plt.text(8, 9.2, "High Priority Target", fontsize=12, color='darkgreen', alpha=0.6, weight='bold')
plt.text(3.5, 4.5, "Low GVC Potential", fontsize=12, color='darkred', alpha=0.6, weight='bold')
plt.grid(True, linestyle=':', alpha=0.6)
plt.tight_layout()
plt.savefig("policy_toolkit/figures/sector_targeting_matrix.png", dpi=300, bbox_inches='tight')
plt.close()

print("Data and figures generated successfully.")
