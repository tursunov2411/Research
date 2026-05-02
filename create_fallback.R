df <- read.csv("output/tables/table_triad_bilateral_trade.csv")
df$imports_mn_usd <- df$imports_usd / 1e6
df$partner <- ifelse(df$partner == "South Korea", "S. Korea", df$partner)
write.csv(df, "data/baci_bilateral_trade.csv", row.names = FALSE)
cat("Fallback baci_bilateral_trade.csv created.\n")
