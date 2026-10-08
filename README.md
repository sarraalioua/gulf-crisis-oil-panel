# The Geopolitics of Oil: Macroeconomic Impact of the 2026 Gulf Crisis

A panel data econometrics study of how the February 2026 oil price shock affected consumer price inflation across twelve advanced and emerging economies. It compares Pooled OLS, Fixed Effects, and Random Effects models, tests which one fits, examines whether oil importers and exporters responded differently, and forecasts CPI and industrial production for April to June 2026 with ARIMA.

Advanced Econometrics project (BA351), Tunis Business School, 2025–2026. Supervised by Dr. Naceur Khraief.

## Research Question

How did the 2026 oil price shock transmit to consumer prices, and did the transmission differ between net oil importers and exporters?

## Data

- **Sample:** 12 countries, monthly, January 2023 to March 2026 (39 months), giving a balanced panel of 468 observations. ARIMA extends forecasts to June 2026.
- **Groups:** Advanced importers (Germany, France, Italy, Japan), advanced exporters (United States, Canada), emerging importers (Turkey, Poland, India, Thailand), emerging exporters (Saudi Arabia, Russia).
- **Variables:** CPI and industrial production (index), Brent crude price (USD/bbl), nominal effective exchange rate (NEER), policy rate (%), and the VIX index.
- **Sources (per the report):** IMF IFS, OECD, FRED, BIS, national central banks, and CBOE. Check each series against its source before citing.
- **File:** `data/Gulf_Crisis_Finl.xlsx`, sheet `Gulf_Crisis`.

## Model

The inflation equation estimated is:

ln(CPI)ᵢₜ = αᵢ + β₁·OilShockₜ + β₂·ln(NEERᵢₜ) + β₃·PolicyRateᵢₜ + β₄·VIXₜ + β₅·PostCrisisₜ + εᵢₜ

- **Dependent variable:** log CPI
- **Oil shock:** monthly percentage change in Brent crude
- **Post-crisis dummy:** 1 from March 2026 onward

## Methods

1. Pooled OLS, Fixed Effects (within), and Random Effects (Swamy–Arora) estimators, via the `plm` package
2. Breusch–Pagan LM test to reject Pooled OLS in favour of a panel model
3. Hausman test to choose between Fixed and Random Effects
4. HC3 heteroskedasticity-robust standard errors, with Arellano clustering for panel models
5. Heterogeneity analysis: Fixed Effects models estimated separately for oil importers and exporters
6. ARIMA forecasts for CPI and industrial production, with the order selected automatically by `auto.arima()` (corrected AIC)

## Results

Main regression (dependent variable: ln CPI, n = 468). Standard errors in parentheses. \*\*\* p < 0.01.

| Variable | Pooled OLS | Fixed Effects | Random Effects |
|---|---|---|---|
| Oil shock (Brent % change) | 0.0020 (0.0031) | 0.0004 (0.0003) | 0.0004 (0.0003) |
| ln NEER | −0.494*** (0.078) | −1.553*** (0.034) | −1.550*** (0.034) |
| Policy rate | 0.045*** (0.003) | 0.0032*** (0.0005) | 0.0032*** (0.0005) |
| VIX | 0.008 (0.005) | 0.0032*** (0.0005) | 0.0032*** (0.0005) |
| Post-crisis | −0.145 (0.216) | −0.021 (0.020) | −0.021 (0.020) |

**Diagnostics**
- Breusch–Pagan: χ² = 6309.7, p < 2.2e-16. Pooled OLS is rejected.
- Hausman: χ² = 5.09, df = 5, p = 0.405. Random Effects is consistent and is the preferred model.

**Heterogeneity (Fixed Effects, separate samples)**

| Variable | Importers | Exporters |
|---|---|---|
| Oil shock | 0.0004 (0.0004), p = 0.31 | 0.0004 (0.0004), p = 0.32 |
| ln NEER | −1.561*** (0.038) | −1.511*** (0.104) |
| Post-crisis | −0.041 (0.027), p = 0.12 | 0.019 (0.026), p = 0.48 |

**Key findings**
- The exchange rate is strongly negative in every specification. A stronger currency is associated with lower consumer prices.
- The policy rate is positive and significant in the pooled and panel models.
- The oil shock is positive but small. It is not significant under model-based or time-clustered (Driscoll–Kraay) standard errors (p between 0.18 and 0.64), and it is significant at the 5% level only under country-clustered robust errors (p ≈ 0.025 for FE and RE). Treat the oil effect as fragile.
- The post-crisis dummy is not significant in any model. Only one post-crisis month (March 2026) is observed, so this estimate is weakly identified.
- ARIMA projections show continued upward CPI pressure through June 2026 across all country groups (see report, Section 7).

## Correction to the Report

The original report's tables and text were produced while the oil shock variable was silently dropped from every model. The variable was zero for every row because `plm` masks `dplyr::lag()`, which returned the series unchanged. The R script in this repository has been fixed, and the results above are the corrected ones.

As a result, the report's main heterogeneity finding (a positive, significant post-crisis effect for oil exporters, β = 0.039, p < 0.05) does not hold in the corrected analysis (β = 0.019, p = 0.48). The Hausman conclusion (prefer Random Effects) is unchanged. The ARIMA forecasts were not affected, since they don't use the oil variable.

The report needs to be updated before it is cited. The team should agree on the corrected results before publishing.

## Limitations

- **Short post-crisis window.** Only one month (March 2026) of observed data falls after the shock, so the post-crisis estimates are weakly identified.
- **Forecasts are short and model-based.** ARIMA is fitted country by country on 39 months of data. Treat the April to June 2026 forecasts as indicative only.
- **Data.** Check each series against its listed source. Confirm whether any part of the 2026 data is constructed rather than observed.

## Project Structure

```
├── data/        # Gulf_Crisis_Finl.xlsx
├── src/         # gulf_crisis_panel_analysis.R
├── docs/        # Final report (PDF) and R output screenshots (PDF)
├── outputs/     # Figures and forecast CSV (created by the script)
├── install_packages.R
└── README.md
```

## How to Run

1. Open R or RStudio in the project root (the folder containing `data/` and `src/`).
2. Install the packages once:

   ```r
   source("install_packages.R")
   ```

3. Run the analysis:

   ```r
   source("src/gulf_crisis_panel_analysis.R")
   ```

The script prints all regression tables and diagnostics, and saves the figures and the forecast CSV to `outputs/`. It was tested in R 4.3.3. `stargazer` is optional: if it isn't installed, the script prints plain coefficient tables instead.

## Team

- Alaa Azouzi
- Sarra Alioua
- Nouha Boukhris
- Mariem Chammem

## License

Code is released under the [MIT License](LICENSE). The data is subject to the terms of its original sources.
