# Raw data sources

All files were downloaded on 25 November 2026 and are stored unchanged.

| File | Source | Series |
|---|---|---|
| `oecd_prices.csv` | OECD Data Explorer, *Consumer price indices (CPIs, HICPs), COICOP 1999* (`DSD_PRICES@DF_PRICES_ALL`) | Monthly CPI index, not seasonally adjusted: total (`_T`) and total excluding food and energy (`_TXCP01_NRG`) |
| `oecd_prices_c2018.csv` | OECD Data Explorer, *Consumer price indices (CPIs, HICPs), COICOP 2018* (`DSD_PRICES_COICOP2018@DF_PRICES_C2018_ALL`) | Same measures, for countries that moved to COICOP 2018 in 2026 |
| `fred_brent_neer.csv` | FRED, Federal Reserve Bank of St. Louis | `POILBREUSDM` (Brent, USD/bbl, monthly average, IMF); `NBxxBIS` (BIS broad nominal effective exchange rates) |
| `bis_neer_sau.csv` | BIS Data Portal, `WS_EER`, key `M.N.B.SA` | Saudi Arabia broad nominal effective exchange rate (not on FRED) |
| `fred_vix.csv` | FRED, `VIXCLS` (CBOE) | VIX, daily close |
| `bis_policy_rates.csv` | BIS Data Portal, `WS_CBPOL` | Central bank policy rates, monthly; `XM` = euro area (used for Germany, France, Italy) |

## CPI source by country

Each country uses a single source for the whole sample, so no series is spliced.

| Country | File | Methodology |
|---|---|---|
| Canada, France, Italy, Japan, Norway, Saudi Arabia, Turkey | COICOP 2018 | National CPI |
| Poland | COICOP 2018 | HICP (the national CPI series stops in December 2025) |
| Germany, Korea, United States, India | COICOP 1999 | National CPI |

## Known gaps and flags

- **US CPI, October 2025:** not published (US federal government shutdown). Left missing, so US inflation for October and November 2025 is missing.
- **US core CPI:** 20 monthly values in 2025–2026 are flagged `E` (estimated) by the OECD; September 2026 is missing.
- **Core CPI** is not available for Poland, Saudi Arabia or India; the core regression uses 9 countries.
- **Brent** is available to September 2026, which sets the end of the sample.
