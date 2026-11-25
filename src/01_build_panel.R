# ============================================================================
# Step 1: build the monthly panel from the official raw files
#
# Reads only the files in data/raw/ (downloaded from FRED, BIS and the OECD;
# see data/raw/SOURCES.md). It does not estimate, fill or interpolate
# any value. Missing observations stay missing.
#
# Output: data/panel_monthly.csv (12 countries, Jan 2019 to Sep 2026)
# Run from the project root:  source("src/01_build_panel.R")
# ============================================================================

library(dplyr)

RAW <- "data/raw/"
stopifnot(dir.exists(RAW))

countries <- c("DEU", "FRA", "ITA", "JPN", "KOR", "POL", "TUR", "IND",   # importers
               "USA", "CAN", "NOR", "SAU")                               # exporters
importers <- c("DEU", "FRA", "ITA", "JPN", "KOR", "POL", "TUR", "IND")
iso2 <- c(DEU = "DE", FRA = "FR", ITA = "IT", JPN = "JP", KOR = "KR", POL = "PL",
          TUR = "TR", IND = "IN", USA = "US", CAN = "CA", NOR = "NO", SAU = "SA")

# ----------------------------------------------------------------------------
# 1. Consumer prices (OECD)
# Two OECD dataflows: COICOP 1999 (oecd_prices.csv) and COICOP 2018
# (oecd_prices_c2018.csv). Several countries moved to COICOP 2018 in 2026
# and are only up to date in the second file. Each country uses ONE source
# for the whole period, so no series is spliced.
# ----------------------------------------------------------------------------
read_oecd <- function(file) {
  read.csv(file.path(RAW, file), stringsAsFactors = FALSE) %>%
    select(REF_AREA, METHODOLOGY, EXPENDITURE, TIME_PERIOD, OBS_VALUE, OBS_STATUS)
}
oecd <- bind_rows(
  read_oecd("oecd_prices.csv")       %>% mutate(file = "c1999"),
  read_oecd("oecd_prices_c2018.csv") %>% mutate(file = "c2018")
)

cpi_source <- data.frame(
  country     = c("CAN", "FRA", "ITA", "JPN", "NOR", "SAU", "TUR", "POL",
                  "DEU", "KOR", "USA", "IND"),
  file        = c(rep("c2018", 8), rep("c1999", 4)),
  methodology = c(rep("N", 7), "HICP", rep("N", 4)),   # Poland: HICP (national CPI not current)
  stringsAsFactors = FALSE
)

prices <- oecd %>%
  inner_join(cpi_source, by = c("REF_AREA" = "country", "file", "METHODOLOGY" = "methodology")) %>%
  filter(EXPENDITURE %in% c("_T", "_TXCP01_NRG")) %>%
  mutate(var = ifelse(EXPENDITURE == "_T", "cpi", "core")) %>%
  select(country = REF_AREA, month = TIME_PERIOD, var, value = OBS_VALUE, status = OBS_STATUS)

cat("\nObservations not flagged 'A' (normal) by the OECD:\n")
print(as.data.frame(prices %>% filter(status != "A") %>% count(country, var, status)))

prices <- full_join(
  prices %>% filter(var == "cpi")  %>% select(country, month, cpi  = value),
  prices %>% filter(var == "core") %>% select(country, month, core = value),
  by = c("country", "month")
)

# ----------------------------------------------------------------------------
# 2. Brent and NEER (FRED; Saudi NEER directly from the BIS)
# NEER: BIS broad nominal effective exchange rate. A rise = appreciation.
# ----------------------------------------------------------------------------
fred <- read.csv(file.path(RAW, "fred_brent_neer.csv"), stringsAsFactors = FALSE) %>%
  mutate(month = substr(observation_date, 1, 7))

brent <- fred %>% select(month, brent = POILBREUSDM)

neer <- bind_rows(lapply(setdiff(countries, "SAU"), function(c) {
  data.frame(country = c, month = fred$month,
             neer = fred[[paste0("NB", iso2[c], "BIS")]], stringsAsFactors = FALSE)
}))

bis_sa <- read.csv(file.path(RAW, "bis_neer_sau.csv"), skip = 3,
                   stringsAsFactors = FALSE, check.names = FALSE)
neer <- bind_rows(neer, data.frame(
  country = "SAU",
  month   = substr(bis_sa[["TIME_PERIOD:Period"]], 1, 7),
  neer    = as.numeric(bis_sa[["OBS_VALUE:Value"]]),
  stringsAsFactors = FALSE
))

# ----------------------------------------------------------------------------
# 3. VIX (FRED, daily -> monthly mean of trading days)
# ----------------------------------------------------------------------------
vix <- read.csv(file.path(RAW, "fred_vix.csv"), stringsAsFactors = FALSE) %>%
  mutate(VIXCLS = suppressWarnings(as.numeric(VIXCLS)),
         month  = substr(observation_date, 1, 7)) %>%
  group_by(month) %>%
  summarise(vix = mean(VIXCLS, na.rm = TRUE), .groups = "drop")

# ----------------------------------------------------------------------------
# 4. Policy rates (BIS). Germany, France and Italy use the ECB rate (XM).
# ----------------------------------------------------------------------------
bis_pol <- read.csv(file.path(RAW, "bis_policy_rates.csv"), stringsAsFactors = FALSE)
policy <- bind_rows(lapply(countries, function(c) {
  area <- if (c %in% c("DEU", "FRA", "ITA")) "XM" else iso2[c]
  bis_pol %>% filter(REF_AREA == area) %>%
    transmute(country = c, month = TIME_PERIOD, policy_rate = OBS_VALUE)
}))

# ----------------------------------------------------------------------------
# 5. Merge on a full country x month grid
# ----------------------------------------------------------------------------
months <- format(seq(as.Date("2019-01-01"), as.Date("2026-09-01"), by = "month"), "%Y-%m")
panel <- expand.grid(country = countries, month = months, stringsAsFactors = FALSE) %>%
  left_join(prices, by = c("country", "month")) %>%
  left_join(brent,  by = "month") %>%
  left_join(neer,   by = c("country", "month")) %>%
  left_join(vix,    by = "month") %>%
  left_join(policy, by = c("country", "month")) %>%
  mutate(importer = as.integer(country %in% importers)) %>%
  arrange(country, month) %>%
  select(country, month, importer, cpi, core, brent, neer, vix, policy_rate)

cat("\nMissing values by country:\n")
print(as.data.frame(panel %>% group_by(country) %>%
  summarise(across(c(cpi, core, neer, policy_rate), ~ sum(is.na(.x))), .groups = "drop")))

write.csv(panel, "data/panel_monthly.csv", row.names = FALSE)
cat("\nSaved data/panel_monthly.csv:", nrow(panel), "rows\n")
