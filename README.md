# The Geopolitics of Oil: Oil Price Pass-Through to Inflation and the 2026 Gulf Crisis

How much of an oil price shock reaches consumer prices, how fast, and does it hit oil importers harder than exporters? This project answers that with a monthly panel of 12 countries from January 2019 to September 2026. The panel covers the 2026 Gulf crisis, when Brent rose from about $69 in February 2026 to $99 in March.

Advanced Econometrics project (BA351), Tunis Business School, 2025–2026. Supervised by Dr. Naceur Khraief.

## Version 3: rebuilt on official data

The first version of this project used a dataset (`Gulf_Crisis_Finl.xlsx`) that could not be traced to its sources. Brent and the VIX matched, but several CPI and policy rate series did not. For example, Turkey's CPI and the US policy rate for 2025–2026 were off. That dataset has been removed.

Version 3 rebuilds everything from files downloaded directly from the OECD, BIS and FRED. They are stored unchanged in `data/raw/`, and every value in the panel comes from them. Nothing is estimated, filled or interpolated. Sources, the CPI series used for each country and known gaps are listed in [`data/raw/SOURCES.md`](data/raw/SOURCES.md).

The original report (`docs/archive/`) is kept for the record only. Its results are superseded by the ones below.

## Data

- **Countries.**
  - Oil importers: Germany, France, Italy, Japan, Korea, Poland, Turkey, India.
  - Oil exporters: United States, Canada, Norway, Saudi Arabia.
- **Period.** Monthly, January 2019 to September 2026 (1,116 country-months). The sample ends when the Brent series ends. It includes the 2020 collapse, the 2022 energy shock and seven months after the 2026 shock.

| Variable | Definition | Source |
|---|---|---|
| Headline inflation | 100 × Δ ln CPI, month on month | OECD |
| Core inflation | Same, CPI excluding food and energy (9 countries) | OECD |
| Oil shock | 100 × Δ ln Brent (USD/bbl, monthly average) | FRED / IMF |
| Δ NEER | 100 × Δ ln broad nominal effective exchange rate; a rise means appreciation | BIS |
| Δ policy rate | Monthly change in the central bank policy rate, lagged one month (ECB rate for the euro area) | BIS |
| VIX | Monthly average of the daily close | FRED / Cboe |

## Methodology

1. **Unit roots.** Im–Pesaran–Shin panel test on February 2019 to September 2025. Log CPI, with a trend: W̄ = 0.15, p = 0.56, so a unit root is not rejected. Monthly inflation: W̄ = −16.7, p < 0.001, so it is stationary. Every model is therefore written in inflation rates. The first version regressed the log CPI level, which risks a spurious regression.
2. **Main model.** Country fixed effects, with calendar-month dummies for seasonality and a distributed lag of the oil shock:

   πᵢₜ = αᵢ + Σₖ₌₀³ βₖ·Oilₜ₋ₖ + γ₀·ΔNEERᵢₜ + γ₁·ΔNEERᵢₜ₋₁ + δ·ΔPolicyᵢₜ₋₁ + θ·VIXₜ + month dummies + εᵢₜ

   The cumulative pass-through is β₀ + β₁ + β₂ + β₃.
3. **Standard errors.** Driscoll–Kraay with a bandwidth of 3 months. All countries face the same oil price in the same month, so their errors are correlated. Errors that ignore this correlation overstate precision.
4. **Headline vs core.** If oil works mainly through fuel and energy prices, it should move headline inflation and not core.
5. **Importers vs exporters.** A two-way fixed effects model, with country and month effects and oil × importer. The month effects absorb everything common to all countries, including oil itself. Only the importer–exporter difference is identified.
6. **Local projections** (Jordà, 2005). The cumulative CPI response 0 to 12 months after a 1% oil shock.
7. **The 2026 episode.**
   - Inflation from March to September 2026 compared with the same months of 2025.
   - The part explained by oil, using coefficients estimated only on data before 2026.
   - An ARIMA counterfactual fitted up to February 2026.
8. **Robustness.** Three variants: excluding Turkey (very high inflation), estimating on 2023 onward only, and estimating only on data before the 2026 shock.

## Results

Standard errors are Driscoll–Kraay. Effects are in percentage points (pp) of monthly inflation per 1% change in Brent.

### Main model (n = 1,066)

| Variable | Coefficient | SE | p |
|---|---|---|---|
| Oil, month t | 0.0119 | 0.0040 | 0.003 |
| Oil, t−1 | 0.0049 | 0.0019 | 0.011 |
| Oil, t−2 | 0.0014 | 0.0028 | 0.62 |
| Oil, t−3 | 0.0013 | 0.0032 | 0.68 |
| **Cumulative (t to t−3)** | **0.0195** | **0.0093** | **0.036** |
| Δ NEER, t | −0.075 | 0.041 | 0.065 |
| Δ NEER, t−1 | −0.154 | 0.057 | 0.008 |
| Δ policy rate, t−1 | 0.197 | 0.095 | 0.038 |
| VIX | 0.006 | 0.007 | 0.41 |

A 10% rise in Brent adds about 0.12 pp to inflation in the same month and about 0.2 pp to the price level within a quarter. Most of the effect arrives within two months. A 1% currency appreciation lowers inflation by about 0.23 pp over two months.

The positive policy rate coefficient is not a causal effect. Central banks raise rates when inflation is already rising.

### Headline vs core (n = 798, 9 countries)

The cumulative oil effect on core inflation is −0.0003 (SE 0.0068, p = 0.97). The short-run pass-through runs through energy and fuel prices, not through broad second-round effects.

### Robustness: cumulative oil effect

| Sample | n | Cumulative | SE | p |
|---|---|---|---|---|
| Full sample | 1,066 | 0.0195 | 0.0093 | 0.036 |
| Excluding Turkey | 977 | 0.0169 | 0.0052 | 0.001 |
| 2023 onwards | 538 | 0.0099 | 0.0028 | < 0.001 |
| Before the 2026 shock | 982 | 0.0223 | 0.0116 | 0.054 |

The effect is positive in every sample. It does not depend on the 2026 months. It is smaller in 2023–2026 than over the full period, which includes the 2021–2022 energy surge.

### Importers vs exporters

Importer minus exporter, cumulative: −0.0093 (SE 0.0083, p = 0.26). Excluding Turkey: −0.0059 (p = 0.15).

There is no evidence that consumer prices in oil importers respond more to oil than prices in exporters. One likely reason: in the United States and Canada, fuel has a large weight in the CPI and pump prices follow world prices. Being an oil exporter protects the trade balance, not consumers.

### Local projections

Cumulative CPI response to a 1% rise in Brent:

| Months after | 0 | 1 | 2 | 3 | 6 | 12 |
|---|---|---|---|---|---|---|
| Response (pp) | 0.011 | 0.019 | 0.024 | 0.025 | 0.031 | 0.082 |
| SE | 0.003 | 0.005 | 0.008 | 0.011 | 0.017 | 0.024 |

The response is significant up to three months and matches the distributed-lag model. Beyond six months the estimate keeps rising and the bands widen. The long horizons probably pick up the persistent 2021–2022 inflation episode rather than the oil shock alone, so they should be read with caution.

### The 2026 shock: March to September 2026 vs the same months of 2025

| Country | Group | Inflation 2026 (pp) | Inflation 2025 (pp) | Excess (pp) |
|---|---|---|---|---|
| Italy | Importer | 3.40 | 0.82 | 2.59 |
| France | Importer | 2.78 | 0.64 | 2.14 |
| India | Importer | 4.61 | 3.10 | 1.50 |
| Poland | Importer | 2.40 | 0.96 | 1.44 |
| Germany | Importer | 2.80 | 1.48 | 1.32 |
| Canada | Exporter | 2.44 | 1.16 | 1.28 |
| United States | Exporter | 3.06 | 1.78 | 1.28 |
| Korea | Importer | 1.70 | 0.84 | 0.86 |
| Japan | Importer | 1.98 | 1.21 | 0.77 |
| Norway | Exporter | 1.75 | 1.10 | 0.65 |
| Saudi Arabia | Exporter | 1.21 | 1.08 | 0.13 |
| Turkey | Importer | 14.12 | 15.50 | −1.38 |

- **Excess inflation.** Excluding Turkey, where disinflation dominated, prices rose 1.27 pp more than over the same months of 2025.
- **Oil's share.** Coefficients estimated on pre-2026 data attribute 0.77 pp of that to oil, about 60%.
- **Importers vs exporters.** Excess inflation averaged 1.52 pp for importers and 0.84 pp for exporters (Welch p = 0.11, with only 7 and 4 countries). The gap is suggestive but not significant.
- **Saudi Arabia** had almost no excess inflation. This fits a pegged currency and administered fuel prices.

**ARIMA counterfactual.** An `auto.arima` model fitted to each country's inflation up to February 2026 gives a "no-shock" forecast for March to September. Excluding Turkey, actual inflation exceeded the forecast by 1.00 pp on average. The gap is largest for Italy (2.39 pp), France (2.19), India (1.80) and Japan (1.52), and close to zero for Poland, Saudi Arabia and Norway. Two different baselines, last year's inflation and a time-series forecast, give a similar size for the 2026 shock: about 1 to 1.3 pp. Month by month, though, actual inflation stayed inside the 95% forecast band almost everywhere. Only Germany and the United States had one month above it. The shock shows up as a steady accumulation of small surprises, not as one spike, so the cumulative gap is the meaningful measure. Details are in `outputs/arima_counterfactual_2026.csv`.

## Conclusions

1. Oil shocks pass through to headline inflation quickly. About 0.2 pp per 10% rise in Brent, mostly within two months.
2. The short-run effect runs through energy prices. Core inflation does not respond.
3. Being a net oil exporter does not shield consumers. The importer–exporter difference in pass-through is not significant.
4. Oil explains about 60% of the extra inflation in March–September 2026.

## Limitations

- **Small panel.** Twelve countries. Group comparisons rest on 7–8 importers and 4 exporters.
- **Common shock.** The oil effect is identified from time variation in a single world price. Other global events in the same months (supply chains in 2021–2022) may be partly picked up despite the controls.
- **Not seasonally adjusted.** Seasonality is handled with calendar-month dummies common to all countries.
- **Data gaps.** US CPI for October 2025 was not published, and some US core values are OECD estimates. See `data/raw/SOURCES.md`.

## Project Structure

```
├── data/
│   ├── raw/                 # Official files, unchanged, and SOURCES.md
│   └── panel_monthly.csv    # Built by src/01_build_panel.R
├── src/
│   ├── 01_build_panel.R     # Raw files -> panel
│   └── 02_analysis.R        # Tests, models, 5 figures, forecasts
├── outputs/                 # Figures and CSV tables (created by the scripts)
├── docs/archive/            # Original report (superseded)
├── install_packages.R
└── README.md
```

## How to Run

Open R or RStudio in the project root (the folder that contains `data/` and `src/`), then run:

```r
source("install_packages.R")      # once
source("src/01_build_panel.R")
source("src/02_analysis.R")
```

## Team

- Alaa Azouzi
- Sarra Alioua
- Nouha Boukhris
- Mariem Chammem

## License

The code is released under the [MIT License](LICENSE). The data belongs to its original providers (OECD, BIS, Federal Reserve Bank of St. Louis, IMF, Cboe) and is subject to their terms. The VIX is © Cboe Global Markets.
