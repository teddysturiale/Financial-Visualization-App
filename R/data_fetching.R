# ==============================================================================
# data_fetching.R
# All Yahoo Finance / quantmod data retrieval functions
# ==============================================================================

# ------------------------------------------------------------------------------
# fetch_asset_data
# Fetches adjusted closing prices for a single ticker from Yahoo Finance.
#
# Parameters:
#   ticker       - character, stock ticker symbol (e.g., "AAPL")
#   start_date   - Date, start of the date range
#   end_date     - Date, end of the date range (lagged by 3 days internally)
#
# Returns:
#   An xts object with a single column of adjusted closing prices,
#   or NULL if the ticker is invalid / data unavailable.
# ------------------------------------------------------------------------------
fetch_asset_data <- function(ticker, start_date, end_date) {
  # Lag end date by 3 days to avoid API gaps from weekends/holidays
  end_date_lagged <- end_date - 3

  tryCatch(
    {
      raw <- quantmod::getSymbols(
        ticker,
        src = "yahoo",
        from = start_date,
        to = end_date_lagged,
        auto.assign = FALSE
      )
      # Extract adjusted closing prices
      prices <- quantmod::Ad(raw)
      # Clean column name to just the ticker
      colnames(prices) <- ticker
      return(prices)
    },
    error = function(e) {
      return(NULL)
    }
  )
}

# ------------------------------------------------------------------------------
# fetch_all_assets
# Fetches and aligns adjusted closing prices for Asset A, Asset B, and SPY.
#
# Parameters:
#   ticker_a    - character, ticker for asset A
#   ticker_b    - character, ticker for asset B
#   start_date  - Date, start of the date range
#   end_date    - Date, end of the date range
#
# Returns:
#   A named list with:
#     prices  - xts object with aligned adjusted close prices (3 columns)
#     error   - character string if any fetch failed, or NULL on success
# ------------------------------------------------------------------------------
fetch_all_assets <- function(ticker_a, ticker_b, start_date, end_date) {
  asset_a <- fetch_asset_data(ticker_a, start_date, end_date)
  asset_b <- fetch_asset_data(ticker_b, start_date, end_date)
  asset_spy <- fetch_asset_data("SPY", start_date, end_date)

  # Check for fetch failures
  if (is.null(asset_a)) {
    return(list(prices = NULL, error = paste0("Could not fetch data for '", ticker_a, "'. Please check the ticker symbol.")))
  }
  if (is.null(asset_b)) {
    return(list(prices = NULL, error = paste0("Could not fetch data for '", ticker_b, "'. Please check the ticker symbol.")))
  }
  if (is.null(asset_spy)) {
    return(list(prices = NULL, error = "Could not fetch benchmark data (SPY). Please try again."))
  }

  # Align all time series to the same date index using inner join
  # merge.xts 'join' only works for 2-object merges, so merge pairwise
  merged <- merge(merge(asset_a, asset_b, join = "inner"), asset_spy, join = "inner")
  colnames(merged) <- c(ticker_a, ticker_b, "SPY")

  # Remove any remaining NA rows
  merged <- na.omit(merged)

  if (nrow(merged) < 2) {
    return(list(prices = NULL, error = "Not enough overlapping data for the selected assets and date range."))
  }

  return(list(prices = merged, error = NULL))
}

# ------------------------------------------------------------------------------
# compute_portfolio_values
# Converts aligned price series into portfolio value series starting from
# an initial investment amount.
#
# Parameters:
#   prices              - xts object with aligned adjusted closing prices
#   initial_investment  - numeric, starting investment in USD
#
# Returns:
#   An xts object with portfolio values for each column.
# ------------------------------------------------------------------------------
compute_portfolio_values <- function(prices, initial_investment) {
  # Normalize each price series: value = investment * (price / first_price)
  first_prices <- as.numeric(prices[1, ])
  portfolio_vals <- sweep(prices, 2, first_prices, FUN = "/") * initial_investment
  return(portfolio_vals)
}
