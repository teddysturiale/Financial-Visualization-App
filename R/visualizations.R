# ==============================================================================
# visualizations.R
# All Plotly chart-generating functions
# ==============================================================================

# Color scheme constants
COLOR_ASSET_A <- "#3498DB"  # Blue
COLOR_ASSET_B <- "#E74C3C"  # Red
COLOR_SPY     <- "#2ECC71"  # Green

# Dark theme layout defaults for all charts
DARK_LAYOUT <- list(
  paper_bgcolor = "rgba(22, 33, 62, 0)",
  plot_bgcolor = "rgba(26, 26, 46, 0.5)",
  font = list(color = "#e0e0e0", family = "system-ui, -apple-system, sans-serif"),
  xaxis = list(
    gridcolor = "rgba(255, 255, 255, 0.08)",
    zerolinecolor = "rgba(255, 255, 255, 0.15)"
  ),
  yaxis = list(
    gridcolor = "rgba(255, 255, 255, 0.08)",
    zerolinecolor = "rgba(255, 255, 255, 0.15)"
  )
)

# Shared Plotly config for toolbar
PLOTLY_CONFIG <- list(
  displayModeBar = TRUE,
  modeBarButtonsToRemove = list("lasso2d", "select2d"),
  displaylogo = FALSE
)

# ------------------------------------------------------------------------------
# apply_dark_theme
# Helper to apply dark theme to any plotly object.
# Merges DARK_LAYOUT with custom layout args.
#
# Parameters:
#   p              - plotly object
#   custom_layout  - list, additional layout overrides
#
# Returns:
#   Modified plotly object.
# ------------------------------------------------------------------------------
apply_dark_theme <- function(p, custom_layout = list()) {
  # Merge dark defaults with custom overrides (custom wins on conflict)
  final_layout <- modifyList(DARK_LAYOUT, custom_layout)
  p <- p %>%
    plotly::layout(
      paper_bgcolor = final_layout$paper_bgcolor,
      plot_bgcolor = final_layout$plot_bgcolor,
      font = final_layout$font
    ) %>%
    plotly::config(
      displayModeBar = PLOTLY_CONFIG$displayModeBar,
      modeBarButtonsToRemove = PLOTLY_CONFIG$modeBarButtonsToRemove,
      displaylogo = PLOTLY_CONFIG$displaylogo
    )
  return(p)
}

# ------------------------------------------------------------------------------
# plot_portfolio_value
# Creates an interactive Plotly line chart of portfolio values over time.
# Includes scatter points and LOESS trend lines (like the reference project).
#
# Parameters:
#   portfolio_vals  - xts object with portfolio values (3 columns)
#   ticker_a        - character, ticker symbol for asset A
#   ticker_b        - character, ticker symbol for asset B
#
# Returns:
#   A plotly object.
# ------------------------------------------------------------------------------
plot_portfolio_value <- function(portfolio_vals, ticker_a, ticker_b) {
  df <- data.frame(
    Date = index(portfolio_vals),
    coredata(portfolio_vals),
    check.names = FALSE
  )

  # Numeric date for LOESS fitting
  date_numeric <- as.numeric(df$Date)

  # Compute LOESS smoothed lines
  loess_a <- tryCatch(
    predict(loess(df[[ticker_a]] ~ date_numeric, span = 0.3)),
    error = function(e) df[[ticker_a]]
  )
  loess_b <- tryCatch(
    predict(loess(df[[ticker_b]] ~ date_numeric, span = 0.3)),
    error = function(e) df[[ticker_b]]
  )
  loess_spy <- tryCatch(
    predict(loess(df[["SPY"]] ~ date_numeric, span = 0.3)),
    error = function(e) df[["SPY"]]
  )

  p <- plotly::plot_ly(df, x = ~Date) %>%
    # Scatter points
    plotly::add_markers(
      y = df[[ticker_a]],
      name = ticker_a,
      marker = list(color = COLOR_ASSET_A, size = 3, opacity = 0.4),
      showlegend = FALSE,
      hoverinfo = "skip"
    ) %>%
    plotly::add_markers(
      y = df[[ticker_b]],
      name = ticker_b,
      marker = list(color = COLOR_ASSET_B, size = 3, opacity = 0.4),
      showlegend = FALSE,
      hoverinfo = "skip"
    ) %>%
    plotly::add_markers(
      y = df[["SPY"]],
      name = "SPY",
      marker = list(color = COLOR_SPY, size = 3, opacity = 0.3),
      showlegend = FALSE,
      hoverinfo = "skip"
    ) %>%
    # LOESS trend lines
    plotly::add_lines(
      y = loess_a,
      name = ticker_a,
      line = list(color = COLOR_ASSET_A, width = 3)
    ) %>%
    plotly::add_lines(
      y = loess_b,
      name = ticker_b,
      line = list(color = COLOR_ASSET_B, width = 3)
    ) %>%
    plotly::add_lines(
      y = loess_spy,
      name = "SPY (Benchmark)",
      line = list(color = COLOR_SPY, width = 3, dash = "dot")
    ) %>%
    plotly::layout(
      title = list(text = "Portfolio Value Over Time", font = list(size = 16)),
      xaxis = list(
        title = "Date",
        rangeslider = list(visible = TRUE),
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      yaxis = list(
        title = "Portfolio Value ($)",
        tickprefix = "$",
        tickformat = ",.0f",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      legend = list(orientation = "h", x = 0, y = 1.12),
      hovermode = "x unified"
    )

  p <- apply_dark_theme(p)
  return(p)
}

# ------------------------------------------------------------------------------
# plot_returns_timeseries
# Creates a Plotly chart with scatter points and LOESS trend lines of periodic
# returns over time, matching the reference project's approach.
#
# Parameters:
#   returns   - xts object of periodic returns (3 columns)
#   ticker_a  - character, ticker for asset A
#   ticker_b  - character, ticker for asset B
#   period    - character, the period label (for title)
#
# Returns:
#   A plotly object.
# ------------------------------------------------------------------------------
plot_returns_timeseries <- function(returns, ticker_a, ticker_b, period = "Daily") {
  df <- data.frame(
    Date = index(returns),
    coredata(returns),
    check.names = FALSE
  )

  date_numeric <- as.numeric(df$Date)
  loess_span <- ifelse(nrow(df) > 20, 0.6, 1.0)

  loess_a <- tryCatch(
    predict(loess(df[[ticker_a]] ~ date_numeric, span = loess_span)),
    error = function(e) df[[ticker_a]]
  )
  loess_b <- tryCatch(
    predict(loess(df[[ticker_b]] ~ date_numeric, span = loess_span)),
    error = function(e) df[[ticker_b]]
  )
  loess_spy <- tryCatch(
    predict(loess(df[["SPY"]] ~ date_numeric, span = loess_span)),
    error = function(e) df[["SPY"]]
  )

  p <- plotly::plot_ly(df, x = ~Date) %>%
    # Scatter points
    plotly::add_markers(
      y = df[[ticker_a]],
      name = ticker_a,
      marker = list(color = COLOR_ASSET_A, size = 3, opacity = 0.4),
      showlegend = FALSE,
      hoverinfo = "skip"
    ) %>%
    plotly::add_markers(
      y = df[[ticker_b]],
      name = ticker_b,
      marker = list(color = COLOR_ASSET_B, size = 3, opacity = 0.4),
      showlegend = FALSE,
      hoverinfo = "skip"
    ) %>%
    plotly::add_markers(
      y = df[["SPY"]],
      name = "SPY",
      marker = list(color = COLOR_SPY, size = 3, opacity = 0.3),
      showlegend = FALSE,
      hoverinfo = "skip"
    ) %>%
    # LOESS trend lines
    plotly::add_lines(
      y = loess_a,
      name = ticker_a,
      line = list(color = COLOR_ASSET_A, width = 2.5)
    ) %>%
    plotly::add_lines(
      y = loess_b,
      name = ticker_b,
      line = list(color = COLOR_ASSET_B, width = 2.5)
    ) %>%
    plotly::add_lines(
      y = loess_spy,
      name = "SPY (Benchmark)",
      line = list(color = COLOR_SPY, width = 2.5, dash = "dot")
    ) %>%
    plotly::layout(
      title = list(text = paste(period, "Returns"), font = list(size = 16)),
      xaxis = list(
        title = "Date",
        rangeslider = list(visible = TRUE),
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      yaxis = list(
        title = "Return on Investment",
        tickformat = ".1%",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      legend = list(orientation = "h", x = 0, y = 1.12),
      hovermode = "x unified"
    )

  p <- apply_dark_theme(p)
  return(p)
}

# ------------------------------------------------------------------------------
# plot_return_distribution
# Creates side-by-side histograms comparing return distributions.
#
# Parameters:
#   returns   - xts object of returns (3 columns)
#   ticker_a  - character, ticker for asset A
#   ticker_b  - character, ticker for asset B
#
# Returns:
#   A plotly object.
# ------------------------------------------------------------------------------
plot_return_distribution <- function(returns, ticker_a, ticker_b) {
  p <- plotly::plot_ly(alpha = 0.5) %>%
    plotly::add_histogram(
      x = as.numeric(returns[, ticker_a]),
      name = ticker_a,
      marker = list(color = COLOR_ASSET_A)
    ) %>%
    plotly::add_histogram(
      x = as.numeric(returns[, ticker_b]),
      name = ticker_b,
      marker = list(color = COLOR_ASSET_B)
    ) %>%
    plotly::add_histogram(
      x = as.numeric(returns[, "SPY"]),
      name = "SPY",
      marker = list(color = COLOR_SPY)
    ) %>%
    plotly::layout(
      title = list(text = "Return Distribution", font = list(size = 16)),
      xaxis = list(
        title = "Return",
        tickformat = ".1%",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      yaxis = list(
        title = "Frequency",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      barmode = "overlay",
      legend = list(orientation = "h", x = 0, y = 1.12)
    )

  p <- apply_dark_theme(p)
  return(p)
}

# ------------------------------------------------------------------------------
# plot_sharpe_ratios_full
# Creates a grouped horizontal bar chart comparing all three Sharpe ratio
# variants (StdDev, VaR, ES) for each asset — matching the reference project.
#
# Parameters:
#   sharpe_df  - data.frame from calculate_full_sharpe_ratios()
#   ticker_a   - character, ticker for asset A
#   ticker_b   - character, ticker for asset B
#
# Returns:
#   A plotly object.
# ------------------------------------------------------------------------------
plot_sharpe_ratios_full <- function(sharpe_df, ticker_a, ticker_b) {
  p <- plotly::plot_ly(
    sharpe_df,
    y = ~Metric
  ) %>%
    plotly::add_bars(
      x = sharpe_df[[ticker_a]],
      name = ticker_a,
      marker = list(color = COLOR_ASSET_A),
      orientation = "h"
    ) %>%
    plotly::add_bars(
      x = sharpe_df[[ticker_b]],
      name = ticker_b,
      marker = list(color = COLOR_ASSET_B),
      orientation = "h"
    ) %>%
    plotly::add_bars(
      x = sharpe_df[["SPY"]],
      name = "SPY",
      marker = list(color = COLOR_SPY),
      orientation = "h"
    ) %>%
    plotly::layout(
      title = list(text = "Sharpe Ratio Comparison", font = list(size = 16)),
      xaxis = list(
        title = "Sharpe Ratio",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      yaxis = list(
        title = "",
        categoryorder = "trace",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      barmode = "group",
      legend = list(orientation = "h", x = 0, y = 1.15),
      margin = list(l = 120)
    )

  p <- apply_dark_theme(p)
  return(p)
}

# ------------------------------------------------------------------------------
# plot_drawdowns
# Creates a Plotly time series of drawdowns with filled area.
#
# Parameters:
#   drawdowns   - xts object of drawdown values
#   max_dd      - named numeric vector of max drawdown values
#   ticker_a    - character, ticker for asset A
#   ticker_b    - character, ticker for asset B
#
# Returns:
#   A plotly object.
# ------------------------------------------------------------------------------
plot_drawdowns <- function(drawdowns, max_dd, ticker_a, ticker_b) {
  df <- data.frame(
    Date = index(drawdowns),
    coredata(drawdowns),
    check.names = FALSE
  )

  p <- plotly::plot_ly(df, x = ~Date) %>%
    plotly::add_trace(
      y = df[[ticker_a]],
      name = ticker_a,
      type = "scatter",
      mode = "lines",
      line = list(color = COLOR_ASSET_A, width = 1.5),
      fill = "tozeroy",
      fillcolor = "rgba(52, 152, 219, 0.3)"
    ) %>%
    plotly::add_trace(
      y = df[[ticker_b]],
      name = ticker_b,
      type = "scatter",
      mode = "lines",
      line = list(color = COLOR_ASSET_B, width = 1.5),
      fill = "tozeroy",
      fillcolor = "rgba(231, 76, 60, 0.3)"
    ) %>%
    plotly::add_trace(
      y = df[["SPY"]],
      name = "SPY",
      type = "scatter",
      mode = "lines",
      line = list(color = COLOR_SPY, width = 1.5, dash = "dot"),
      fill = "tozeroy",
      fillcolor = "rgba(46, 204, 113, 0.15)"
    ) %>%
    plotly::layout(
      title = list(text = "Drawdown From Peak", font = list(size = 16)),
      xaxis = list(
        title = "Date",
        rangeslider = list(visible = TRUE),
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      yaxis = list(
        title = "Drawdown",
        tickformat = ".1%",
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      legend = list(orientation = "h", x = 0, y = 1.12),
      hovermode = "x unified",
      annotations = list(
        list(
          x = 0.5, y = -0.18,
          xref = "paper", yref = "paper",
          text = paste0(
            "Max DD \u2014 ", ticker_a, ": ", round(max_dd[ticker_a] * 100, 1), "%",
            "  |  ", ticker_b, ": ", round(max_dd[ticker_b] * 100, 1), "%",
            "  |  SPY: ", round(max_dd["SPY"] * 100, 1), "%"
          ),
          showarrow = FALSE,
          font = list(size = 11, color = "#aaa")
        )
      )
    )

  p <- apply_dark_theme(p)
  return(p)
}

# ------------------------------------------------------------------------------
# plot_rolling_correlation
# Creates a Plotly chart of rolling correlation with green/red fill.
#
# Parameters:
#   rolling_cor  - xts object with rolling correlation values
#   ticker_a     - character, ticker for asset A
#   ticker_b     - character, ticker for asset B
#   window       - integer, window size used
#
# Returns:
#   A plotly object.
# ------------------------------------------------------------------------------
plot_rolling_correlation <- function(rolling_cor, ticker_a, ticker_b, window = 30) {
  if (is.null(rolling_cor) || nrow(rolling_cor) == 0) {
    p <- plotly::plot_ly() %>%
      plotly::layout(
        title = list(text = "Rolling Correlation", font = list(size = 16)),
        annotations = list(
          list(
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            text = "Not enough data for rolling correlation (need 30+ trading days)",
            showarrow = FALSE,
            font = list(size = 14, color = "#e0e0e0")
          )
        )
      )
    p <- apply_dark_theme(p)
    return(p)
  }

  df <- data.frame(
    Date = index(rolling_cor),
    Correlation = as.numeric(rolling_cor),
    check.names = FALSE
  )

  # Split into positive and negative for conditional coloring
  df$Positive <- ifelse(df$Correlation >= 0, df$Correlation, 0)
  df$Negative <- ifelse(df$Correlation < 0, df$Correlation, 0)

  p <- plotly::plot_ly(df, x = ~Date) %>%
    plotly::add_trace(
      y = ~Positive,
      type = "scatter",
      mode = "lines",
      line = list(color = COLOR_SPY, width = 0.5),
      fill = "tozeroy",
      fillcolor = "rgba(46, 204, 113, 0.4)",
      name = "Positive"
    ) %>%
    plotly::add_trace(
      y = ~Negative,
      type = "scatter",
      mode = "lines",
      line = list(color = COLOR_ASSET_B, width = 0.5),
      fill = "tozeroy",
      fillcolor = "rgba(231, 76, 60, 0.4)",
      name = "Negative"
    ) %>%
    plotly::add_lines(
      y = ~Correlation,
      name = "Correlation",
      line = list(color = "#ECF0F1", width = 2)
    ) %>%
    plotly::layout(
      title = list(
        text = paste0(window, "-Period Rolling Correlation: ", ticker_a, " vs ", ticker_b),
        font = list(size = 16)
      ),
      xaxis = list(
        title = "Date",
        rangeslider = list(visible = TRUE),
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      yaxis = list(
        title = "Correlation",
        range = list(-1, 1),
        gridcolor = "rgba(255, 255, 255, 0.08)"
      ),
      legend = list(orientation = "h", x = 0, y = 1.12),
      hovermode = "x unified",
      shapes = list(
        list(
          type = "line",
          x0 = min(df$Date), x1 = max(df$Date),
          y0 = 0, y1 = 0,
          line = list(color = "#95A5A6", width = 1, dash = "dash")
        )
      )
    )

  p <- apply_dark_theme(p)
  return(p)
}
