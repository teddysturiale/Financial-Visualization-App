# Equity Comparison Tool

An R Shiny web application for comparing the performance of two user-selected equities against the S&P 500 benchmark. Built as a portfolio project for quantitative finance and data science roles.

**Live App:** [https://teddysturiale.shinyapps.io/equity-comparison-tool/](https://teddysturiale.shinyapps.io/equity-comparison-tool/)

## Features

- **Portfolio Value Tracking** — Compare how an initial investment grows across two equities and SPY, with interactive Plotly charts and a color-coded summary table.
- **Returns Analysis** — Periodic returns (daily/weekly/monthly) with distribution histograms and descriptive statistics (mean, median, std dev, skewness, kurtosis).
- **Risk-Adjusted Metrics** — Sharpe Ratio comparison, drawdown-from-peak analysis with max drawdown annotations, and 30-period rolling correlation between the two selected assets.
- **Data Explorer** — Browse raw adjusted closing prices in an interactive DataTable with CSV export.

All data is sourced from Yahoo Finance via `quantmod`. The S&P 500 (SPY) is automatically included as a benchmark in every view.

## How to Run Locally

### Prerequisites

- R >= 4.0
- RStudio (optional but recommended)

### Setup

```bash
# Clone the repo
git clone https://github.com/teddysturiale/Financial-Visualization-App
cd Financial-Visualization-App

# Install dependencies
Rscript -e "install.packages('renv'); renv::init()"

# Run the app
Rscript -e "shiny::runApp('app.R')"
```

The app will launch in your default browser at `http://127.0.0.1:PORT`.

## Project Structure

```
Financial-Visualization-App/
├── app.R                  # Main Shiny app (UI + server)
├── R/
│   ├── data_fetching.R    # Yahoo Finance data retrieval via quantmod
│   ├── calculations.R     # Financial calculations (returns, Sharpe, drawdown, correlation)
│   └── visualizations.R   # Plotly chart functions
├── www/
│   └── custom.css         # Dark theme CSS overrides
├── CLAUDE.md              # Project specification
└── README.md              # This file
```

## Methodology

### Data

- Adjusted closing prices from Yahoo Finance (accounts for splits and dividends)
- End date lagged by 3 days to handle weekends/holidays
- All series aligned to common dates via inner join

### Calculations

| Metric | Method |
|--------|--------|
| Returns | `PerformanceAnalytics::Return.calculate()` with discrete method |
| Sharpe Ratio | `PerformanceAnalytics::SharpeRatio()` with StdDev denominator |
| Drawdown | `PerformanceAnalytics::Drawdowns()` / `maxDrawdown()` |
| Rolling Correlation | `zoo::rollapply()` with 30-period window, Pearson method |

### Color Scheme

- Asset A: Blue (`#3498DB`)
- Asset B: Red (`#E74C3C`)
- SPY Benchmark: Green (`#2ECC71`)

## Deployment

```bash
Rscript -e "rsconnect::deployApp()"
```

Targets shinyapps.io free tier.

## Acknowledgments

Inspired by [pmaji/financial-asset-comparison-tool](https://github.com/pmaji/financial-asset-comparison-tool). Built as an improved, original version with benchmark comparison, drawdown analysis, rolling correlation, and a modern dark UI.

Data sourced from Yahoo Finance via quantmod. For educational purposes only.
