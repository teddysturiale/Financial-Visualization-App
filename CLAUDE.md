# CLAUDE.md — R Shiny Financial Asset Comparison Tool

## Project Overview

You are helping build an **R Shiny web application** for financial asset comparison. This is a portfolio project targeting quant/data science and economic research roles. The goal is a polished, deployed app that compares the performance of two user-selected equities using progressively complex metrics.

This project is inspired by: https://github.com/pmaji/financial-asset-comparison-tool
Use that repo as a structural and functional reference, but build an improved, original version — do not copy code directly.

---

## Quick Start

```bash
# Install R dependencies (first time)
Rscript -e "install.packages('renv'); renv::init()"

# Run the app locally
Rscript -e "shiny::runApp('app.R')"

# Deploy to shinyapps.io
Rscript -e "rsconnect::deployApp()"
```

---

## Goals & Differentiators

Build upon the inspiration project with the following improvements:

1. **Benchmark comparison** — always display a third line (S&P 500 via SPY) alongside the two user-selected assets so performance is automatically contextualized against the market.
2. **Drawdown analysis** — add a max drawdown chart and metric. This is a standard risk metric highly valued in quant/risk roles.
3. **Rolling correlation** — add a chart showing how the correlation between the two selected assets changes over the chosen time window.
4. **Focus on equities only** — remove cryptocurrency support to keep the app clean and focused. Use Yahoo Finance as the sole data source via `quantmod`.
5. **Clean, modern UI** — use `shinydashboard` with a dark theme (`shinythemes` or custom CSS). The app should look professional, not like a default Shiny template.

---

## File Structure

Build and maintain the following structure:

```
project/
├── CLAUDE.md              ← this file
├── app.R                  ← main Shiny app (UI + server), keeps code organized by sourcing helpers
├── R/
│   ├── data_fetching.R    ← all Yahoo Finance / quantmod data retrieval functions
│   ├── calculations.R     ← all financial metric calculations (returns, Sharpe, drawdown, correlation)
│   └── visualizations.R   ← all Plotly chart-generating functions
├── www/
│   └── custom.css         ← any custom CSS overrides for the UI
├── README.md              ← project description, methodology, how to run locally, live app link
└── renv.lock              ← package lockfile (use renv for reproducibility)
```

---

## Required R Packages

Use the following packages. Install all via `renv::init()` at project start for reproducibility.

```r
library(shiny)
library(shinydashboard)
library(shinythemes)
library(quantmod)       # Yahoo Finance data
library(tidyquant)      # tidy financial data helpers
library(dplyr)
library(tidyr)
library(lubridate)
library(plotly)         # interactive charts
library(PerformanceAnalytics)  # Sharpe, drawdown, returns
library(DT)             # interactive data tables
library(formattable)    # color-coded summary tables
library(xts)
library(zoo)
```

---

## App Sections & Features

Build the app as a `shinydashboard` with a sidebar and the following tabs/sections:

### Sidebar (global inputs — affect all sections)
- **Asset A selector**: text input for a stock ticker (default: "AAPL")
- **Asset B selector**: text input for a stock ticker (default: "MSFT")
- **Date range**: date range picker (default: last 2 years; minimum selectable: 2010-01-01)
- **Initial investment amount**: numeric input in USD (default: $10,000)
- **Risk-free rate**: numeric slider (0% to 5%, default: 4.5% to reflect current T-bill rate; used for Sharpe calculations)
- **Returns period**: selector for Daily / Weekly / Monthly (affects returns and Sharpe charts)
- Note: S&P 500 (SPY) is always included automatically as a benchmark — do not make it user-selectable.

### Tab 1: Portfolio Value
- **Main chart**: interactive Plotly line chart showing portfolio value over time for Asset A, Asset B, and SPY (benchmark). All three start at the user-specified initial investment amount. Use `quantmod::getSymbols()` to pull adjusted closing prices.
- **Summary table**: a `formattable` table with the following columns for each asset (A, B, SPY):
  - Starting Value, Ending Value, Max Value, Min Value, Total Return (%), Best Single Day (%), Worst Single Day (%)
  - Green-highlight the winning asset for each metric column.

### Tab 2: Returns Analysis
- **Returns chart**: Plotly bar or line chart of periodic returns (daily/weekly/monthly depending on sidebar selection) for both assets and SPY.
- **Return distribution**: side-by-side histogram or density plot comparing the return distributions of the two assets.
- **Descriptive stats table**: mean return, median return, standard deviation, skewness, kurtosis for each asset.

### Tab 3: Risk-Adjusted Returns
- **Sharpe Ratio chart**: horizontal bar chart comparing Sharpe ratios (using standard deviation in denominator) for Asset A, Asset B, and SPY.
- **Drawdown chart**: Plotly time series of drawdown from peak for both assets over the selected period. Show max drawdown value as an annotation.
- **Rolling correlation chart**: 30-day rolling Pearson correlation between Asset A and Asset B returns. Include a reference line at 0. Color the fill green when positive, red when negative.

### Tab 4: Data Explorer
- A `DT::datatable` showing the raw adjusted closing prices for both assets and SPY for the selected date range.
- Include a download button so users can export the data as CSV.

---

## Data Fetching Rules

- Use `quantmod::getSymbols(ticker, src = "yahoo", auto.assign = FALSE)` for all data.
- Always use **adjusted closing prices** (accounts for dividends and splits) — use `Ad()` to extract.
- Handle errors gracefully: if a ticker is invalid or data is unavailable, display a user-friendly `shiny::validate()` message rather than crashing.
- Always lag the end date by 3 days (as the original project does) to avoid API gaps from weekends/holidays.
- Align all time series to the same date index using `merge()` before any calculations.

---

## Calculation Standards

Define all calculation functions in `R/calculations.R`. Key rules:

- **Returns**: use `PerformanceAnalytics::Return.calculate(prices, method = "discrete")` for period returns.
- **Sharpe Ratio**: use `PerformanceAnalytics::SharpeRatio(returns, Rf = risk_free_rate / periods_per_year, FUN = "StdDev")`.
- **Drawdown**: use `PerformanceAnalytics::Drawdowns(returns)` to compute the full drawdown series; `PerformanceAnalytics::maxDrawdown(returns)` for the scalar.
- **Rolling correlation**: compute manually using `zoo::rollapply()` with `cor` and a window of 30 periods.
- All calculations must handle `NA` values — use `na.omit()` before passing to any PerformanceAnalytics function.

---

## Visualization Standards

Define all chart functions in `R/visualizations.R`. Each function should accept pre-computed data (not raw prices) and return a Plotly object.

- **Color scheme**: Asset A = `#3498DB` (blue), Asset B = `#E74C3C` (red), SPY benchmark = `#2ECC71` (green). Use these consistently across all charts.
- **All charts must be interactive Plotly objects** — no static ggplot2 charts.
- Use `plotly::layout()` to add: chart title, axis labels, a range slider at the bottom of time series charts, and a legend.
- Include `config(displayModeBar = TRUE)` so users can zoom, pan, and download charts.
- Drawdown chart: fill the area under the line with the red color at 30% opacity.

---

## UI/UX Standards

- Use `shinydashboard` with `dashboardPage()`, `dashboardHeader()`, `dashboardSidebar()`, `dashboardBody()`.
- Apply a dark skin: `dashboardPage(skin = "black", ...)`.
- Each tab should use `box()` components with appropriate `width` and `status` arguments.
- Add a collapsible sidebar with `collapsed = FALSE` default.
- Add a footer note crediting data sources: "Data sourced from Yahoo Finance via quantmod. For educational purposes only."
- Make the app **responsive** — use `fluidRow()` and `column()` layouts so it works on different screen sizes.

---

## Testing

No formal test suite. Manual testing checklist:
- Invalid ticker (e.g., "ZZZZZZ") — should show validation message, not crash
- Very short date range (< 30 days) — rolling correlation will show "not enough data" message
- Identical tickers for A and B — should still work, correlation = 1.0
- Weekend/holiday end dates — 3-day lag in `fetch_asset_data()` handles this

---

## Deployment

- Target deployment: **shinyapps.io** (free tier).
- Use `rsconnect::deployApp()` to deploy.
- The README.md must include the live shinyapps.io URL once deployed.
- Before deployment, test that all packages in `renv.lock` are compatible with shinyapps.io.

---

## Code Quality Standards

- **Comment every function** with a header block: what it does, its parameters, and what it returns.
- Use `snake_case` for all variable and function names.
- Keep `app.R` lean — source the R/ helper files at the top, put all logic in helper functions, not inline in the server.
- Reactive expressions (`reactive({})`) should be used for data fetching and computation so results are cached and not recomputed on every render.
- Use `req()` to guard all reactive expressions that depend on user inputs — prevents errors on app initialization.
- Do not hardcode any tickers, dates, or investment amounts — everything must flow from user inputs.

---

## What to Build First (Suggested Order)

1. Scaffold the full file structure as listed above.
2. Implement data fetching in `R/data_fetching.R` and test that it correctly pulls and aligns Asset A, Asset B, and SPY.
3. Build the Tab 1 portfolio value chart and summary table — get the core working end-to-end before adding complexity.
4. Add Tab 2 returns analysis.
5. Add Tab 3 risk-adjusted metrics (drawdown, Sharpe, rolling correlation).
6. Add Tab 4 data explorer.
7. Polish UI, add CSS, test edge cases (invalid tickers, short date ranges, identical assets).
8. Write README.md, initialize renv, and deploy to shinyapps.io.

---

## Notes for Claude Code

- If a package function has changed or is deprecated, find the current equivalent — do not use deprecated syntax.
- The `quantmod` Yahoo Finance API occasionally changes. If `getSymbols` fails, try `tidyquant::tq_get()` as a fallback.
- Do not use `<<-` (global assignment) anywhere — keep all state within Shiny's reactive system.
- When in doubt about a financial calculation, implement the textbook definition and add a comment explaining the formula.
