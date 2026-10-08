# ============================================================================
# The Geopolitics of Oil: Panel Data Analysis of the 2026 Gulf Crisis
#
# Run from the project root (the folder containing data/ and src/):
#   1. Install packages once:  source("install_packages.R")
#   2. Run this script:        source("src/gulf_crisis_panel_analysis.R")
# ============================================================================

# ----------------------------------------------------------------------------
# STEP 1: LOAD LIBRARIES
# ----------------------------------------------------------------------------
library(readxl)
library(dplyr)
library(ggplot2)
library(plm)
library(lmtest)
library(car)
library(sandwich)   # provides vcovHC (used by lmtest::coeftest)

# Output folder for figures
if (!dir.exists("outputs")) dir.create("outputs")

# Comparison tables: uses stargazer if installed, otherwise prints coefficients
make_table <- function(models, labels, title) {
  if (requireNamespace("stargazer", quietly = TRUE)) {
    stargazer::stargazer(models, title = title, column.labels = labels,
                         type = "text", keep.stat = c("n", "rsq"))
  } else {
    cat("\n===", title, "===\n")
    for (i in seq_along(models)) {
      cat("\n--", labels[i], "--\n")
      print(summary(models[[i]])$coefficients)
    }
  }
}

# ----------------------------------------------------------------------------
# STEP 2: LOAD DATA
# ----------------------------------------------------------------------------
DATA_PATH <- "data/Gulf_Crisis_Finl.xlsx"
if (!file.exists(DATA_PATH)) {
  stop("Dataset not found at ", DATA_PATH, ". Run this script from the project root.")
}

data_raw <- read_excel(
  DATA_PATH,
  sheet     = "Gulf_Crisis",
  skip      = 2,
  col_names = c("country", "date", "group", "oil_balance",
                "cpi", "ipi", "brent", "neer", "policy_rate", "vix")
)

# Keep the 10 raw columns only
data_raw <- data_raw[, c("country", "date", "group", "oil_balance",
                         "cpi", "ipi", "brent", "neer", "policy_rate", "vix")]

# Force correct data types
data_raw$date        <- as.Date(as.character(data_raw$date))
data_raw$cpi         <- as.numeric(as.character(data_raw$cpi))
data_raw$ipi         <- as.numeric(as.character(data_raw$ipi))
data_raw$brent       <- as.numeric(as.character(data_raw$brent))
data_raw$neer        <- as.numeric(as.character(data_raw$neer))
data_raw$policy_rate <- as.numeric(as.character(data_raw$policy_rate))
data_raw$vix         <- as.numeric(as.character(data_raw$vix))
data_raw$country     <- as.character(data_raw$country)
data_raw$group       <- as.character(data_raw$group)
data_raw$oil_balance <- as.character(data_raw$oil_balance)

# Remove any leftover header rows (country codes are 3 letters)
data_raw <- data_raw[nchar(trimws(data_raw$country)) == 3, ]

cat("Rows loaded:", nrow(data_raw), "\n")
cat("Columns:", names(data_raw), "\n")

# ----------------------------------------------------------------------------
# STEP 3: COMPUTE DERIVED VARIABLES
# ----------------------------------------------------------------------------
data_processed <- data_raw %>%
  group_by(country) %>%
  arrange(date, .by_group = TRUE) %>%
  mutate(
    ln_cpi         = log(cpi),
    ln_ipi         = log(ipi),
    ln_neer        = log(neer),
    post_crisis    = ifelse(date >= as.Date("2026-03-01"), 1, 0),
    # dplyr::lag is spelled out because plm masks lag() and would return
    # the series unchanged, making every oil change zero.
    oil_pct_change = (brent - dplyr::lag(brent)) / dplyr::lag(brent) * 100,
    oil_pct_change = ifelse(is.na(oil_pct_change), 0, oil_pct_change)
  ) %>%
  ungroup() %>%
  filter(!is.na(ln_cpi), !is.na(ln_ipi), !is.na(oil_pct_change))

cat("data_processed rows:", nrow(data_processed), "\n")

# ----------------------------------------------------------------------------
# STEP 4: EXPLORATORY DATA ANALYSIS
# ----------------------------------------------------------------------------

# Plot 1: Brent oil price over time
p_brent <- ggplot(data_processed %>% distinct(date, brent), aes(x = date, y = brent)) +
  geom_line(color = "darkred", linewidth = 1) +
  geom_vline(xintercept = as.numeric(as.Date("2026-02-27")),
             linetype = "dashed", color = "blue") +
  annotate("text", x = as.Date("2026-02-27"), y = max(data_processed$brent),
           label = "Crisis Start", hjust = -0.1) +
  labs(title = "Brent Crude Oil Price: Pre and Post 2026 Gulf Crisis",
       x = "Date", y = "USD per Barrel") +
  theme_minimal()
print(p_brent)
ggsave("outputs/brent_oil_price.png", p_brent, width = 8, height = 5, dpi = 150)

# Plot 2: Log CPI trends by country group
p_cpi <- ggplot(data_processed, aes(x = date, y = ln_cpi, color = group)) +
  stat_summary(fun = mean, geom = "line", linewidth = 1) +
  geom_vline(xintercept = as.numeric(as.Date("2026-02-27")),
             linetype = "dashed") +
  labs(title = "Log CPI Trends by Country Group",
       x = "Date", y = "Log(CPI)") +
  theme_minimal()
print(p_cpi)
ggsave("outputs/log_cpi_by_group.png", p_cpi, width = 8, height = 5, dpi = 150)

# ----------------------------------------------------------------------------
# STEP 5: DECLARE PANEL STRUCTURE
# ----------------------------------------------------------------------------
pdata <- pdata.frame(data_processed, index = c("country", "date"))

# ----------------------------------------------------------------------------
# STEP 6: PANEL REGRESSIONS
# ----------------------------------------------------------------------------
formula_cpi <- ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis

# Model 1: Pooled OLS
pols_model <- plm(formula_cpi, data = pdata, model = "pooling")
summary(pols_model)

# Model 2: Fixed Effects
fe_model <- plm(formula_cpi, data = pdata, model = "within")
summary(fe_model)

# Model 3: Random Effects (preferred, per Hausman test)
re_model <- plm(formula_cpi, data = pdata, model = "random")
summary(re_model)

# Comparison table
make_table(list(pols_model, fe_model, re_model),
           labels = c("Pooled OLS", "Fixed Effects", "Random Effects"),
           title  = "Panel Regression Results: CPI Equation")

# ----------------------------------------------------------------------------
# STEP 7: DIAGNOSTIC TESTS
# ----------------------------------------------------------------------------

# Hausman test: FE vs RE
hausman_test <- phtest(fe_model, re_model)
print(hausman_test)

# Breusch-Pagan LM test: RE vs Pooled OLS
bp_test <- plmtest(pols_model, effect = "individual", type = "bp")
print(bp_test)

# Robust standard errors (HC3; Arellano for panel models)
cat("\n--- Pooled OLS (Robust SE) ---\n")
print(coeftest(pols_model, vcov = vcovHC(pols_model, type = "HC3")))

cat("\n--- Fixed Effects (Robust SE) ---\n")
print(coeftest(fe_model, vcov = vcovHC(fe_model, method = "arellano", type = "HC3")))

cat("\n--- Random Effects (Robust SE) ---\n")
print(coeftest(re_model, vcov = vcovHC(re_model, method = "arellano", type = "HC3")))

# ----------------------------------------------------------------------------
# STEP 8: HETEROGENEITY ANALYSIS: OIL IMPORTERS VS EXPORTERS
# ----------------------------------------------------------------------------
importers_data <- pdata %>% filter(oil_balance == "importer")
exporters_data <- pdata %>% filter(oil_balance == "exporter")

fe_importers <- plm(formula_cpi, data = importers_data, model = "within")
fe_exporters <- plm(formula_cpi, data = exporters_data, model = "within")

make_table(list(fe_importers, fe_exporters),
           labels = c("Importers", "Exporters"),
           title  = "Fixed Effects Results: Oil Importers vs. Exporters")

# ----------------------------------------------------------------------------
# STEP 9: ARIMA FORECASTING: APRIL to JUNE 2026
# Requires the 'forecast' package (installed by install_packages.R)
# ----------------------------------------------------------------------------
library(forecast)

countries <- unique(data_processed$country)
vars      <- c("cpi", "ipi")
h         <- 3   # forecast 3 months ahead (Apr, May, Jun 2026)

forecast_rows <- list()

for (ctry in countries) {

  country_data <- data_processed %>%
    filter(country == ctry) %>%
    arrange(date)

  for (var in vars) {

    # Monthly time series starting January 2023
    ts_data <- ts(country_data[[var]], start = c(2023, 1), frequency = 12)

    # Fit ARIMA model automatically (minimises corrected AIC)
    fit <- auto.arima(ts_data)

    # Forecast 3 months ahead
    fc <- forecast(fit, h = h)

    # Store forecasted values
    for (i in 1:h) {
      forecast_rows[[length(forecast_rows) + 1]] <- data.frame(
        country  = ctry,
        date     = as.Date(paste0("2026-0", 3 + i, "-01")),
        variable = var,
        forecast = as.numeric(fc$mean[i]),
        lower_95 = as.numeric(fc$lower[i, 2]),
        upper_95 = as.numeric(fc$upper[i, 2]),
        stringsAsFactors = FALSE
      )
    }

    cat("\n===", ctry, "-", var, "===\n")
    print(fc)
  }
}

# Combine all forecasts into one table and save it
forecast_df <- do.call(rbind, forecast_rows)
print(forecast_df)
write.csv(forecast_df, "outputs/arima_forecasts_apr_jun_2026.csv", row.names = FALSE)
