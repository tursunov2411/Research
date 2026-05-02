import re

filepath = 'report_main.tex'
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Introduction
text = text.replace(r'\section{Introduction}', r'\section{I BOB: Kirish (Introduction)}')

# 2. Add Literature Review before Data and Methodology
text = text.replace(r'\section{Data and Methodology}', 
r'''\section{II BOB: Adabiyotlar Sharhi (Literature Review)}
\input{chapters/ch_literature_review}

\section{III BOB: Metodologiya (Data and Methodology)}
\subsection{Data and Methodology}''')

# 3. Change all subsequent analysis sections to subsections under IV BOB
text = text.replace(r'\section{Structural Break Analysis: The 2017 Reform as a Manufacturing Turning Point}',
r'''\section{IV BOB: Tahlil va Natijalar (Analysis and Results)}
\subsection{Structural Break Analysis: The 2017 Reform as a Manufacturing Turning Point}''')

text = text.replace(r'\section{Revealed Comparative Advantage: Export Sophistication and Its Limits}',
r'\subsection{Revealed Comparative Advantage: Export Sophistication and Its Limits}')

text = text.replace(r'\section{Northeast Asian Trade and FDI Flows}',
r'\subsection{Northeast Asian Trade and FDI Flows}')

text = text.replace(r'\section{Trade Network Analysis: Value-Chain Positioning}\label{sec:network}',
r'\subsection{Trade Network Analysis: Value-Chain Positioning}\label{sec:network}')

text = text.replace(r'\section{Comparative Trajectory: Uzbekistan and Vietnam}',
r'\subsection{Comparative Trajectory: Uzbekistan and Vietnam}')

text = text.replace(r'\section{Regression Analysis}',
r'\subsection{Regression Analysis}')

text = text.replace(r'\section{Scenario Forecasts: Manufacturing Value Added through 2030}',
r'\subsection{Scenario Forecasts: Manufacturing Value Added through 2030}')

text = text.replace(r'\section{Mechanisms: Trade Openness, ECI, and the Complexity Trajectory}',
r'\subsection{Mechanisms: Trade Openness, ECI, and the Complexity Trajectory}')

# 4. Group Conclusion and Policy Implications under V BOB
text = text.replace(r'\section{Policy Implications}',
r'''\section{V BOB: Xulosa va Takliflar (Conclusion and Policy Implications)}
\subsection{Policy Implications}''')

text = text.replace(r'\section{Conclusion}',
r'\subsection{Conclusion}')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print("Restructured report_main.tex into 5 BOBs.")
