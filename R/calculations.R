# ==============================================================================
# calculations.R
# All financial metric calculations (returns, Sharpe, drawdown, correlation)
# ==============================================================================

# ------------------------------------------------------------------------------
# calculate_returns
# Computes periodic returns from a price series.
#
# Parameters:
#   prices  - xts object of adjusted closing prices
#   period  - character, one of "daily", "weekly", "monthly"
#
# Returns:
#   An xts object of discrete returns at the specified frequency.
# ------------------------------------------------------------------------------
calculate_returns <- function(prices, period = "daily") {
  if (period == "daily") {
    returns <- PerformanceAnalytics::Return.calculate(prices, method = "discrete")
  } else if (period == "weekly") {
    # Convert to weekly endpoints then compute returns
    weekly_prices <- xts::to.weekly(prices, OHLC = FALSE)
    returns <- PerformanceAnalytics::Return.calculate(weekly_prices, method = "discrete")
  } else if (period == "monthly") {
    monthly_prices <- xts::to.monthly(prices, OHLC = FALSE)
    returns <- PerformanceAnalytics::Return.calculate(monthly_prices, method = "discrete")
  } else {
    returns <- PerformanceAnalytics::Return.calculate(prices, method = "discrete")
  }
  # Remove the first row (NA from return calculation)
  returns <- na.omit(returns)
  return(returns)
}

# ------------------------------------------------------------------------------
# calculate_sharpe_ratios
# Computes the annualized Sharpe Ratio (StdDev method) for each asset.
#
# Parameters:
#   returns         - xts object of returns (multiple columns)
#   risk_free_rate  - numeric, annualized risk-free rate as decimal (e.g., 0.045)
#   period          - character, one of "daily", "weekly", "monthly"
#
# Returns:
#   A named numeric vector of Sharpe ratios.
# ------------------------------------------------------------------------------
calculate_sharpe_ratios <- function(returns, risk_free_rate = 0.045, period = "daily") {
  # Determine periods per year based on frequency
  periods_per_year <- switch(period,
    "daily" = 252,
    "weekly" = 52,
    "monthly" = 12,
    252
  )

  # Per-period risk free rate
  rf_per_period <- risk_free_rate / periods_per_year

  # PerformanceAnalytics::SharpeRatio returns a matrix; extract StdDev row
  sharpe_mat <- PerformanceAnalytics::SharpeRatio(
    returns,
    Rf = rf_per_period,
    FUN = "StdDev"
  )

  sharpe_vec <- as.numeric(sharpe_mat[1, ])
  names(sharpe_vec) <- colnames(returns)
  return(sharpe_vec)
}

# ------------------------------------------------------------------------------
# calculate_full_sharpe_ratios
# Computes all three Sharpe Ratio variants (StdDev, VaR, ES) for each asset.
# This matches the reference project's approach with multiple Sharpe metrics.
#
# Parameters:
#   returns         - xts object of returns (multiple columns)
#   risk_free_rate  - numeric, annualized risk-free rate as decimal (e.g., 0.045)
#   period          - character, one of "daily", "weekly", "monthly"
#   p               - numeric, confidence level for VaR/ES (default 0.95)
#
# Returns:
#   A data.frame with columns: Metric, and one column per asset, with rows
#   for StdDev Sharpe, VaR Sharpe, and ES Sharpe.
# ------------------------------------------------------------------------------
calculate_full_sharpe_ratios <- function(returns, risk_free_rate = 0.045, period = "daily", p = 0.95) {
  periods_per_year <- switch(period,
    "daily" = 252,
    "weekly" = 52,
    "monthly" = 12,
    252
  )

  rf_per_period <- risk_free_rate / periods_per_year

  # Compute all three Sharpe variants
  sharpe_mat <- PerformanceAnalytics::SharpeRatio(
    returns,
    Rf = rf_per_period,
    p = p,
    FUN = "StdDev"
  )

  sharpe_var <- PerformanceAnalytics::SharpeRatio(
    returns,
    Rf = rf_per_period,
    p = p,
    FUN = "VaR"
  )

  sharpe_es <- PerformanceAnalytics::SharpeRatio(
    returns,
    Rf = rf_per_period,
    p = p,
    FUN = "ES"
  )

  # Build a tidy data frame
  asset_names <- colnames(returns)

  df <- data.frame(
    Metric = c("StdDev Sharpe", "VaR Sharpe", "ES Sharpe"),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(asset_names)) {
    df[[asset_names[i]]] <- round(c(
      as.numeric(sharpe_mat[1, i]),
      as.numeric(sharpe_var[1, i]),
      as.numeric(sharpe_es[1, i])
    ), 4)
  }

  return(df)
}

# ------------------------------------------------------------------------------
# calculate_drawdowns
# Computes the drawdown series (percentage below running peak) for each asset.
#
# Parameters:
#   returns  - xts object of returns (multiple columns)
#
# Returns:
#   An xts object of drawdown values (negative percentages).
# ------------------------------------------------------------------------------
calculate_drawdowns <- function(returns) {
  dd <- PerformanceAnalytics::Drawdowns(returns)
  return(dd)
}

# ------------------------------------------------------------------------------
# calculate_max_drawdown
# Computes the maximum drawdown scalar for each asset.
#
# Parameters:
#   returns  - xts object of returns (multiple columns)
#
# Returns:
#   A named numeric vector of max drawdown values.
# ------------------------------------------------------------------------------
calculate_max_drawdown <- function(returns) {
  max_dd <- apply(returns, 2, function(col) {
    PerformanceAnalytics::maxDrawdown(na.omit(col))
  })
  return(max_dd)
}

# ------------------------------------------------------------------------------
# calculate_rolling_correlation
# Computes the rolling Pearson correlation between two return series.
#
# Parameters:
#   returns_a  - xts object, returns for asset A (single column)
#   returns_b  - xts object, returns for asset B (single column)
#   window     - integer, rolling window size in periods (default: 30)
#
# Returns:
#   An xts object with the rolling correlation values.
# ------------------------------------------------------------------------------
calculate_rolling_correlation <- function(returns_a, returns_b, window = 30) {
  # Merge the two series
  merged <- merge(returns_a, returns_b, join = "inner")
  merged <- na.omit(merged)

  if (nrow(merged) < window) {
    return(NULL)
  }

  # Compute rolling correlation using zoo::rollapply
  # rollapply on an xts object returns an xts with correct date indices
  rolling_cor <- zoo::rollapply(
    merged,
    width = window,
    FUN = function(x) cor(x[, 1], x[, 2]),
    by.column = FALSE,
    align = "right"
  )

  # Convert to xts if not already (rollapply on xts returns zoo)
  rolling_cor <- xts::as.xts(rolling_cor)
  colnames(rolling_cor) <- "Rolling_Correlation"
  return(rolling_cor)
}

# ------------------------------------------------------------------------------
# calculate_descriptive_stats
# Computes descriptive statistics for return series.
#
# Parameters:
#   returns  - xts object of returns (multiple columns)
#
# Returns:
#   A data.frame with rows: Mean, Median, Std Dev, Skewness, Kurtosis
#   and one column per asset.
# ------------------------------------------------------------------------------
calculate_descriptive_stats <- function(returns) {
  stats_list <- lapply(seq_len(ncol(returns)), function(i) {
    r <- as.numeric(na.omit(returns[, i]))
    data.frame(
      Mean = mean(r),
      Median = median(r),
      `Std Dev` = sd(r),
      Skewness = PerformanceAnalytics::skewness(r, method = "moment"),
      Kurtosis = PerformanceAnalytics::kurtosis(r, method = "moment"),
      check.names = FALSE
    )
  })
  stats_df <- do.call(rbind, stats_list)
  rownames(stats_df) <- colnames(returns)
  return(stats_df)
}

# ------------------------------------------------------------------------------
# build_portfolio_summary
# Builds the summary table for the portfolio value tab.
#
# Parameters:
#   portfolio_vals  - xts object, portfolio values for each asset
#   daily_returns   - xts object, daily returns for each asset
#
# Returns:
#   A data.frame with columns: Asset, Starting Value, Ending Value,
#   Max Value, Min Value, Total Return (%), Best Day (%), Worst Day (%)
# ------------------------------------------------------------------------------
build_portfolio_summary <- function(portfolio_vals, daily_returns) {
  n <- nrow(portfolio_vals)
  summary_list <- lapply(seq_len(ncol(portfolio_vals)), function(i) {
    vals <- as.numeric(portfolio_vals[, i])
    rets <- as.numeric(daily_returns[, i])

    start_val <- vals[1]
    end_val <- vals[n]
    max_val <- max(vals, na.rm = TRUE)
    min_val <- min(vals, na.rm = TRUE)
    total_ret <- ((end_val - start_val) / start_val) * 100
    best_day <- max(rets, na.rm = TRUE) * 100
    worst_day <- min(rets, na.rm = TRUE) * 100

    data.frame(
      Asset = colnames(portfolio_vals)[i],
      `Starting Value` = round(start_val, 2),
      `Ending Value` = round(end_val, 2),
      `Max Value` = round(max_val, 2),
      `Min Value` = round(min_val, 2),
      `Total Return (%)` = round(total_ret, 2),
      `Best Day (%)` = round(best_day, 2),
      `Worst Day (%)` = round(worst_day, 2),
      check.names = FALSE
    )
  })
  summary_df <- do.call(rbind, summary_list)
  return(summary_df)
}
