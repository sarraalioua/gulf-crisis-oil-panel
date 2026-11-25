# ============================================================================
# Step 2: oil price pass-through to inflation, 12 countries, 2019-2026
#
# Run from the project root, after src/01_build_panel.R:
#   source("src/02_analysis.R")
# ============================================================================

library(dplyr)
library(ggplot2)
library(plm)
library(lmtest)
library(sandwich)
library(forecast)

if (!dir.exists("outputs")) dir.create("outputs")
stopifnot(file.exists("data/panel_monthly.csv"))

DK_LAG <- 3   # Driscoll-Kraay bandwidth: floor(4 * (T/100)^(2/9)) = 3 for T = 92

# Driscoll-Kraay standard errors: robust to heteroskedasticity, serial
# correlation and cross-country correlation (all countries face the same
# oil shock in the same month, so errors are correlated across countries).
dk <- function(model, lag = DK_LAG) vcovSCC(model, maxlag = lag)

# Sum of several coefficients with its DK standard error
cumulative_effect <- function(model, terms, lag = DK_LAG) {
  b <- coef(model); V <- dk(model, lag)
  w <- as.numeric(names(b) %in% terms)
  est <- sum(w * b); se <- sqrt(as.numeric(t(w) %*% V %*% w))
  data.frame(estimate = est, se = se, t = est / se, p = 2 * pnorm(-abs(est / se)))
}

print_dk <- function(model, title, lag = DK_LAG) {
  cat("\n==========", title, "==========\n")
  ct <- coeftest(model, vcov = dk(model, lag))
  print(ct[!grepl("^factor\\(mon\\)", rownames(ct)), , drop = FALSE])
  cat("Observations:", nobs(model), "\n")
}

# ----------------------------------------------------------------------------
# 1. Derived variables (all in percent; dplyr::lag spelled out on purpose,
#    because plm masks lag() and would silently return the series unchanged)
# ----------------------------------------------------------------------------
d <- read.csv("data/panel_monthly.csv", stringsAsFactors = FALSE) %>%
  group_by(country) %>%
  arrange(month, .by_group = TRUE) %>%
  mutate(
    infl      = 100 * (log(cpi)   - log(dplyr::lag(cpi))),    # headline m/m inflation
    core_infl = 100 * (log(core)  - log(dplyr::lag(core))),   # core: excl. food and energy
    oil       = 100 * (log(brent) - log(dplyr::lag(brent))),  # Brent, % change
    dneer     = 100 * (log(neer)  - log(dplyr::lag(neer))),   # + = appreciation
    dpol      = policy_rate - dplyr::lag(policy_rate),
    oil_l1    = dplyr::lag(oil, 1),
    oil_l2    = dplyr::lag(oil, 2),
    oil_l3    = dplyr::lag(oil, 3),
    dneer_l1  = dplyr::lag(dneer, 1),
    dpol_l1   = dplyr::lag(dpol, 1),
    infl_l1   = dplyr::lag(infl, 1),
    lcpi      = 100 * log(cpi),
    mon       = substr(month, 6, 7)                           # calendar month (seasonality)
  ) %>%
  ungroup()

stopifnot(sd(d$oil, na.rm = TRUE) > 0)   # guard against the old lag() bug

oil_terms <- c("oil", "oil_l1", "oil_l2", "oil_l3")
f_main <- infl ~ oil + oil_l1 + oil_l2 + oil_l3 + dneer + dneer_l1 + dpol_l1 + vix + factor(mon)

pd <- pdata.frame(d, index = c("country", "month"))

# ----------------------------------------------------------------------------
# 2. Figures
# ----------------------------------------------------------------------------
shock <- as.Date("2026-03-01")
d$date <- as.Date(paste0(d$month, "-01"))

p1 <- ggplot(distinct(d, date, brent), aes(date, brent)) +
  geom_line(colour = "darkred", linewidth = 0.9) +
  geom_vline(xintercept = shock, linetype = "dashed") +
  labs(title = "Brent crude, monthly average", x = NULL, y = "USD per barrel",
       caption = "Source: FRED (POILBREUSDM)") +
  theme_minimal()
print(p1)
ggsave("outputs/brent.png", p1, width = 8, height = 4.5, dpi = 150)

p2 <- d %>%
  filter(country != "TUR", date >= as.Date("2024-01-01")) %>%
  mutate(group = ifelse(importer == 1, "Oil importers", "Oil exporters")) %>%
  group_by(group, date) %>% summarise(infl = mean(infl, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(date, infl, colour = group)) +
  geom_line(linewidth = 0.9) +
  geom_vline(xintercept = shock, linetype = "dashed") +
  labs(title = "Monthly headline inflation by group (excluding Turkey)",
       x = NULL, y = "% m/m, not seasonally adjusted", colour = NULL,
       caption = "Source: OECD") +
  theme_minimal() + theme(legend.position = "bottom")
print(p2)
ggsave("outputs/inflation_by_group.png", p2, width = 8, height = 4.5, dpi = 150)

# ----------------------------------------------------------------------------
# 3. Panel unit roots (Im-Pesaran-Shin), on the balanced window
#    Feb 2019 to Sep 2025 (US CPI is missing for Oct 2025)
# ----------------------------------------------------------------------------
ur <- pdata.frame(d %>% filter(month >= "2019-03", month <= "2025-09"),
                  index = c("country", "month"))
cat("\n--- IPS: log CPI (intercept + trend) ---\n")
print(purtest(ur$lcpi, test = "ips", exo = "trend", lags = "AIC", pmax = 4))
cat("\n--- IPS: monthly inflation (intercept) ---\n")
print(purtest(ur$infl, test = "ips", exo = "intercept", lags = "AIC", pmax = 4))
# Log CPI has a unit root; inflation does not, so the models use inflation.

# ----------------------------------------------------------------------------
# 4. Main model: fixed effects, distributed lag, Driscoll-Kraay SE
# ----------------------------------------------------------------------------
m_main <- plm(f_main, data = pd, model = "within")
print_dk(m_main, "Main model: headline inflation")
cat("\nCumulative effect of a 1% oil rise after 3 months (pp):\n")
print(cumulative_effect(m_main, oil_terms))

# ----------------------------------------------------------------------------
# 5. Headline vs core inflation (core available for 9 countries)
# ----------------------------------------------------------------------------
m_core <- plm(update(f_main, core_infl ~ .), data = pd, model = "within")
print_dk(m_core, "Core inflation (excl. food and energy)")
print(cumulative_effect(m_core, oil_terms))

# ----------------------------------------------------------------------------
# 6. Robustness
# ----------------------------------------------------------------------------
robust <- list(
  "Excluding Turkey"     = subset(pd, country != "TUR"),
  "2023 onwards"         = subset(pd, as.character(month) >= "2023-01"),
  "Before the 2026 shock" = subset(pd, as.character(month) < "2026-03")
)
rob_table <- bind_rows(lapply(names(robust), function(nm) {
  m <- plm(f_main, data = robust[[nm]], model = "within")
  cbind(sample = nm, n = nobs(m), cumulative_effect(m, oil_terms))
}))
cat("\n========== Robustness: cumulative oil effect ==========\n")
print(rob_table)

# ----------------------------------------------------------------------------
# 7. Importers vs exporters: two-way FE (country + month effects)
#    Month effects absorb everything common to all countries (oil itself,
#    VIX, global demand), so only the importer DIFFERENCE is identified.
# ----------------------------------------------------------------------------
d <- d %>% mutate(oil_imp = oil * importer, oil_l1_imp = oil_l1 * importer,
                  oil_l2_imp = oil_l2 * importer, oil_l3_imp = oil_l3 * importer)
pd <- pdata.frame(d, index = c("country", "month"))
imp_terms <- c("oil_imp", "oil_l1_imp", "oil_l2_imp", "oil_l3_imp")
m_imp <- plm(infl ~ oil_imp + oil_l1_imp + oil_l2_imp + oil_l3_imp + dneer + dneer_l1 + dpol_l1,
             data = pd, model = "within", effect = "twoways")
print_dk(m_imp, "Two-way FE: oil x importer")
cat("\nImporter minus exporter, cumulative (pp per 1% oil):\n")
print(cumulative_effect(m_imp, imp_terms))

# ----------------------------------------------------------------------------
# 8. Local projections (Jorda 2005): cumulative CPI response, h = 0..12
#    y = 100 * (ln CPI[t+h] - ln CPI[t-1]) regressed on oil[t]
# ----------------------------------------------------------------------------
lp <- bind_rows(lapply(0:12, function(h) {
  dd <- d %>% group_by(country) %>%
    mutate(y = dplyr::lead(lcpi, h) - dplyr::lag(lcpi, 1)) %>% ungroup()
  m <- plm(y ~ oil + oil_l1 + oil_l2 + infl_l1 + dneer + dneer_l1 + dpol_l1 + vix + factor(mon),
           data = pdata.frame(dd, index = c("country", "month")), model = "within")
  V <- dk(m, lag = h + DK_LAG)   # overlapping horizons need a wider bandwidth
  data.frame(h = h, beta = coef(m)["oil"], se = sqrt(V["oil", "oil"]), n = nobs(m))
}))
rownames(lp) <- NULL
cat("\n========== Local projections: response to a 1% oil rise ==========\n")
print(lp)
write.csv(lp, "outputs/local_projections.csv", row.names = FALSE)

p3 <- ggplot(lp, aes(h, beta)) +
  geom_ribbon(aes(ymin = beta - 1.96 * se, ymax = beta + 1.96 * se), alpha = 0.2) +
  geom_line(linewidth = 0.9) + geom_hline(yintercept = 0) +
  scale_x_continuous(breaks = 0:12) +
  labs(title = "Cumulative CPI response to a 1% rise in Brent",
       x = "Months after the shock", y = "pp of CPI (95% DK band)") +
  theme_minimal()
print(p3)
ggsave("outputs/local_projections.png", p3, width = 8, height = 4.5, dpi = 150)

# ----------------------------------------------------------------------------
# 9. The 2026 shock: March-September 2026 vs the same months of 2025
#    Model-implied oil contribution uses coefficients estimated BEFORE 2026.
# ----------------------------------------------------------------------------
m_pre <- plm(f_main, data = subset(pd, as.character(month) < "2026-01"), model = "within")
b_pre <- coef(m_pre)[oil_terms]

post <- d %>% filter(month >= "2026-03", month <= "2026-09")
post$oil_contrib <- as.numeric(as.matrix(post[, oil_terms]) %*% b_pre)

event <- post %>%
  group_by(country, importer) %>%
  summarise(infl_2026 = sum(infl), oil_contrib = sum(oil_contrib), .groups = "drop") %>%
  left_join(d %>% filter(month >= "2025-03", month <= "2025-09") %>%
              group_by(country) %>% summarise(infl_2025 = sum(infl)), by = "country") %>%
  mutate(excess = infl_2026 - infl_2025) %>%
  arrange(excess)

cat("\n========== March-September 2026 vs same months of 2025 (pp) ==========\n")
print(as.data.frame(event))
write.csv(event, "outputs/shock_2026_excess_inflation.csv", row.names = FALSE)

p4 <- ggplot(event, aes(reorder(country, excess), excess,
                       fill = ifelse(importer == 1, "Oil importer", "Oil exporter"))) +
  geom_col() + geom_hline(yintercept = mean(event$oil_contrib), linetype = "dashed") +
  coord_flip() +
  labs(title = "Excess inflation, March-September 2026 vs same months of 2025",
       subtitle = "Dashed line: oil contribution implied by pre-2026 coefficients",
       x = NULL, y = "pp", fill = NULL) +
  theme_minimal() + theme(legend.position = "bottom")
print(p4)
ggsave("outputs/shock_2026_excess_inflation.png", p4, width = 8, height = 5, dpi = 150)

ex_tur <- event %>% filter(country != "TUR")
cat("\nMean excess inflation, excluding Turkey:", round(mean(ex_tur$excess), 2), "pp\n")
cat("Model-implied oil contribution:", round(mean(ex_tur$oil_contrib), 2), "pp\n")
print(t.test(excess ~ importer, data = ex_tur))   # Welch test, 7 vs 4 countries

# ----------------------------------------------------------------------------
# 10. Forecasting counterfactual: ARIMA fitted up to February 2026,
#     forecast March-September 2026, compared with actual inflation
# ----------------------------------------------------------------------------
arima_rows <- list()
for (ctry in unique(d$country)) {
  s <- d %>% filter(country == ctry, month >= "2019-02", month <= "2026-02") %>% arrange(month)
  if (any(is.na(s$infl))) s$infl <- na.interp(ts(s$infl, frequency = 12))  # forecasting only
  y  <- ts(s$infl, start = c(2019, 2), frequency = 12)
  fc <- forecast(auto.arima(y), h = 7)
  actual <- d %>% filter(country == ctry, month >= "2026-03", month <= "2026-09") %>% arrange(month)
  arima_rows[[ctry]] <- data.frame(
    country = ctry, month = actual$month, actual = actual$infl,
    forecast = as.numeric(fc$mean), lower_95 = as.numeric(fc$lower[, 2]),
    upper_95 = as.numeric(fc$upper[, 2]))
}
arima_cf <- bind_rows(arima_rows) %>% mutate(gap = actual - forecast)
write.csv(arima_cf, "outputs/arima_counterfactual_2026.csv", row.names = FALSE)
cat("\n========== ARIMA counterfactual: cumulative gap Mar-Sep 2026 (pp) ==========\n")
print(as.data.frame(arima_cf %>% group_by(country) %>%
  summarise(months_above_95 = sum(actual > upper_95),   # computed first: summarise
            actual = sum(actual), forecast = sum(forecast),  # overwrites 'actual' in order
            gap = sum(gap)) %>% arrange(gap)))

p5 <- arima_cf %>%
  filter(country %in% c("ITA", "FRA", "USA", "SAU")) %>%
  mutate(date = as.Date(paste0(month, "-01"))) %>%
  ggplot(aes(date)) +
  geom_ribbon(aes(ymin = lower_95, ymax = upper_95), fill = "grey80") +
  geom_line(aes(y = forecast, linetype = "ARIMA forecast (fitted to Feb 2026)")) +
  geom_line(aes(y = actual, linetype = "Actual"), colour = "darkred") +
  facet_wrap(~ country) +
  labs(title = "Actual inflation vs no-shock ARIMA forecast, 2026",
       x = NULL, y = "% m/m", linetype = NULL) +
  theme_minimal() + theme(legend.position = "bottom")
print(p5)
ggsave("outputs/arima_counterfactual_2026.png", p5, width = 8, height = 5, dpi = 150)
