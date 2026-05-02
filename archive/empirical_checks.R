library(tidyverse)
library(lmtest)
library(car)
library(stargazer)

# Read the data used in previous regressions
uz <- read_csv("data/processed/uzbekistan_panel.csv")
uz_eci <- read_csv("data/processed/eci_data.csv") %>% select(year, eci) %>% left_join(uz, ., by="year")

# Original models
reg1 <- lm(mfg_va ~ fdi_lag1 + trade_open + post2017 + trend, data = uz)
reg2 <- lm(mfg_va ~ fdi_lag1 + fdi_lag2 + trade_open + post2017 + trend, data = uz)
reg_eci <- lm(eci ~ mfg_va + trade_open + post2017 + trend, data = uz_eci)

# VIF
vif1 <- vif(reg1)
vif2 <- vif(reg2)

# Breusch-Pagan test for heteroskedasticity
bp1 <- bptest(reg1)
bp2 <- bptest(reg2)

# Durbin-Watson for autocorrelation
dw1 <- dwtest(reg1)
dw2 <- dwtest(reg2)

# Output robustness checks to a LaTeX table manually or via stargazer
robustness_df <- data.frame(
  Test = c("Breusch-Pagan (Heteroskedasticity) p-value", "Durbin-Watson (Autocorrelation) stat", "Max VIF (Multicollinearity)"),
  Model_1 = c(round(bp1$p.value, 3), round(dw1$statistic, 3), round(max(vif1), 3)),
  Model_2 = c(round(bp2$p.value, 3), round(dw2$statistic, 3), round(max(vif2), 3))
)

stargazer(robustness_df, summary=FALSE, rownames=FALSE, type="latex",
          title="Empirical Robustness Diagnostics",
          label="tab:robustness",
          out="output/tables/robustness_checks.tex")
