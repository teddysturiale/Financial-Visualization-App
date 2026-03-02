# ==============================================================================
# app.R — Financial Asset Comparison Tool
# Main Shiny application: UI + Server
# ==============================================================================

# Load packages
library(shiny)
library(shinydashboard)
library(quantmod)
library(tidyquant)
library(dplyr)
library(tidyr)
library(lubridate)
library(plotly)
library(PerformanceAnalytics)
library(DT)
library(formattable)
library(xts)
library(zoo)

# Source helper files
source("R/data_fetching.R")
source("R/calculations.R")
source("R/visualizations.R")

# ==============================================================================
# UI
# ==============================================================================

ui <- dashboardPage(
  skin = "black",

  dashboardHeader(
    title = tags$span(
      icon("chart-line", style = "margin-right: 8px;"),
      "Equity Comparison Tool"
    ),
    titleWidth = 300
  ),

  dashboardSidebar(
    width = 300,
    sidebarMenu(
      id = "tabs",
      menuItem("Portfolio Value", tabName = "portfolio", icon = icon("chart-line")),
      menuItem("Returns Analysis", tabName = "returns", icon = icon("chart-bar")),
      menuItem("Risk-Adjusted Returns", tabName = "risk", icon = icon("shield-alt")),
      menuItem("Data Explorer", tabName = "data", icon = icon("table"))
    ),

    hr(),

    # --- Asset Inputs ---
    tags$div(
      class = "sidebar-section-header",
      icon("search-dollar"),
      "Asset Selection"
    ),

    textInput(
      inputId = "ticker_a",
      label = "Asset A Ticker:",
      value = "AAPL",
      placeholder = "e.g. AAPL, GOOGL, TSLA"
    ),

    textInput(
      inputId = "ticker_b",
      label = "Asset B Ticker:",
      value = "MSFT",
      placeholder = "e.g. MSFT, AMZN, META"
    ),

    tags$div(
      style = "padding: 0 15px 10px 15px;",
      actionButton(
        inputId = "apply_btn",
        label = "Apply",
        icon = icon("refresh"),
        width = "100%",
        class = "btn-apply"
      )
    ),

    hr(),

    tags$div(
      class = "sidebar-section-header",
      icon("calendar-alt"),
      "Time & Parameters"
    ),

    dateRangeInput(
      inputId = "date_range",
      label = "Date Range:",
      start = Sys.Date() - 730,
      end = Sys.Date(),
      min = "2010-01-01",
      max = Sys.Date()
    ),

    numericInput(
      inputId = "initial_investment",
      label = "Initial Investment ($):",
      value = 10000,
      min = 1,
      step = 100
    ),

    sliderInput(
      inputId = "risk_free_rate",
      label = "Risk-Free Rate (%):",
      min = 0,
      max = 5,
      value = 4.5,
      step = 0.1
    ),

    selectInput(
      inputId = "returns_period",
      label = "Returns Period:",
      choices = c("Daily" = "daily", "Weekly" = "weekly", "Monthly" = "monthly"),
      selected = "daily"
    ),

    hr(),

    tags$div(
      class = "sidebar-note",
      icon("info-circle"),
      "S&P 500 (SPY) is automatically included as a benchmark."
    )
  ),

  dashboardBody(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
    ),

    tabItems(

      # ======================================================================
      # Tab 1: Portfolio Value
      # ======================================================================
      tabItem(
        tabName = "portfolio",
        fluidRow(
          box(
            title = tagList(icon("chart-line"), "Portfolio Value Over Time"),
            status = "primary",
            solidHeader = TRUE,
            width = 8,
            div(
              class = "chart-container",
              plotlyOutput("portfolio_chart", height = "480px")
            )
          ),
          box(
            title = tagList(icon("info-circle"), "About This Chart"),
            status = "primary",
            solidHeader = TRUE,
            width = 4,
            tags$div(
              class = "info-panel",
              tags$h4("Portfolio Performance"),
              tags$p("This chart shows how an initial investment grows (or shrinks) over your selected time period for both assets and the S&P 500 benchmark."),
              tags$p("All three lines start at the same initial investment amount so you can directly compare performance."),
              tags$hr(),
              tags$h4("How to Read"),
              tags$ul(
                tags$li(tags$span(class = "color-dot dot-blue"), "Asset A (blue)"),
                tags$li(tags$span(class = "color-dot dot-red"), "Asset B (red)"),
                tags$li(tags$span(class = "color-dot dot-green"), "SPY benchmark (green, dashed)")
              ),
              tags$p(class = "tip-text", icon("lightbulb"), "Use the range slider below the chart to zoom into a specific period."),
              tags$hr(),
              tags$p(class = "tip-text", icon("hand-pointer"), "Hover over lines to see exact portfolio values on any date.")
            )
          )
        ),
        fluidRow(
          box(
            title = tagList(icon("table"), "Portfolio Summary"),
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            tags$p(class = "table-description", "For each metric, the best-performing asset is highlighted in green."),
            formattableOutput("portfolio_summary_table")
          )
        )
      ),

      # ======================================================================
      # Tab 2: Returns Analysis
      # ======================================================================
      tabItem(
        tabName = "returns",
        fluidRow(
          box(
            title = tagList(icon("chart-bar"), "Returns Over Time"),
            status = "success",
            solidHeader = TRUE,
            width = 8,
            div(
              class = "chart-container",
              plotlyOutput("returns_chart", height = "450px")
            )
          ),
          box(
            title = tagList(icon("info-circle"), "About Returns"),
            status = "success",
            solidHeader = TRUE,
            width = 4,
            tags$div(
              class = "info-panel",
              tags$h4("Rate of Return"),
              tags$p("This chart shows the ", tags$strong("periodic rate of return"), " calculated at the frequency you selected in the sidebar (daily, weekly, or monthly)."),
              tags$p(tags$a(href = "https://www.investopedia.com/terms/r/rateofreturn.asp", target = "_blank", "Rate of return"), " measures the gain or loss of an investment over a specified period, expressed as a proportion of the investment's cost."),
              tags$hr(),
              tags$h4("Reading the Chart"),
              tags$ul(
                tags$li("Values above 0% = positive returns"),
                tags$li("Values below 0% = negative returns"),
                tags$li("Wider swings = higher volatility")
              ),
              tags$p(class = "tip-text", icon("lightbulb"), "Try switching between Daily, Weekly, and Monthly to see how aggregation smooths volatility.")
            )
          )
        ),
        fluidRow(
          box(
            title = tagList(icon("chart-area"), "Return Distribution"),
            status = "success",
            solidHeader = TRUE,
            width = 6,
            div(
              class = "chart-container",
              plotlyOutput("returns_distribution", height = "380px")
            )
          ),
          box(
            title = tagList(icon("calculator"), "Descriptive Statistics"),
            status = "success",
            solidHeader = TRUE,
            width = 6,
            tags$p(class = "table-description", "Statistical summary of return distributions for each asset."),
            formattableOutput("descriptive_stats_table")
          )
        )
      ),

      # ======================================================================
      # Tab 3: Risk-Adjusted Returns
      # ======================================================================
      tabItem(
        tabName = "risk",
        fluidRow(
          box(
            title = tagList(icon("balance-scale"), "Sharpe Ratio Comparison"),
            status = "warning",
            solidHeader = TRUE,
            width = 6,
            tags$p(class = "table-description",
              "The ", tags$a(href = "https://en.wikipedia.org/wiki/Sharpe_ratio", target = "_blank", "Sharpe Ratio"),
              " measures excess return per unit of risk. Higher is better. Three variants shown: StdDev, VaR, and ES."
            ),
            div(
              class = "chart-container",
              plotlyOutput("sharpe_chart", height = "350px")
            )
          ),
          box(
            title = tagList(icon("chart-area"), "Drawdown From Peak"),
            status = "warning",
            solidHeader = TRUE,
            width = 6,
            tags$p(class = "table-description",
              "Drawdown measures the decline from a historical peak. Max drawdown annotations shown below."
            ),
            div(
              class = "chart-container",
              plotlyOutput("drawdown_chart", height = "350px")
            )
          )
        ),
        fluidRow(
          box(
            title = tagList(icon("project-diagram"), "Rolling Correlation"),
            status = "warning",
            solidHeader = TRUE,
            width = 12,
            tags$p(class = "table-description",
              "30-day rolling Pearson correlation between the two selected assets. ",
              "Green fill = positive correlation, red fill = negative correlation. Reference line at 0."
            ),
            div(
              class = "chart-container",
              plotlyOutput("rolling_corr_chart", height = "400px")
            )
          )
        )
      ),

      # ======================================================================
      # Tab 4: Data Explorer
      # ======================================================================
      tabItem(
        tabName = "data",
        fluidRow(
          box(
            title = tagList(icon("database"), "Raw Adjusted Closing Prices"),
            status = "info",
            solidHeader = TRUE,
            width = 12,
            tags$div(
              class = "data-toolbar",
              downloadButton("download_csv", "Download CSV", class = "btn-download"),
              tags$span(class = "data-toolbar-info", textOutput("data_row_count", inline = TRUE))
            ),
            br(),
            DT::dataTableOutput("data_table")
          )
        )
      )
    ),

    # Footer
    tags$footer(
      class = "app-footer",
      tags$div(
        tags$span("Data sourced from Yahoo Finance via quantmod."),
        tags$span(class = "footer-separator", "|"),
        tags$span("For educational purposes only."),
        tags$span(class = "footer-separator", "|"),
        tags$span(
          tags$a(href = "https://github.com/pmaji/financial-asset-comparison-tool",
                 target = "_blank",
                 "Inspired by pmaji/financial-asset-comparison-tool")
        )
      )
    )
  )
)


# ==============================================================================
# SERVER
# ==============================================================================

server <- function(input, output, session) {

  # --------------------------------------------------------------------------
  # Reactive values for ticker inputs (only update on Apply click)
  # --------------------------------------------------------------------------
  ticker_vals <- reactiveValues(
    ticker_a = "AAPL",
    ticker_b = "MSFT"
  )

  observeEvent(input$apply_btn, {
    ticker_vals$ticker_a <- toupper(trimws(input$ticker_a))
    ticker_vals$ticker_b <- toupper(trimws(input$ticker_b))
  })

  # --------------------------------------------------------------------------
  # Helpers for clean ticker labels
  # --------------------------------------------------------------------------
  ticker_a_clean <- reactive({ ticker_vals$ticker_a })
  ticker_b_clean <- reactive({ ticker_vals$ticker_b })

  # --------------------------------------------------------------------------
  # Reactive: Fetch and align price data
  # --------------------------------------------------------------------------
  price_data <- reactive({
    req(ticker_a_clean(), ticker_b_clean(), input$date_range)

    ta <- ticker_a_clean()
    tb <- ticker_b_clean()

    validate(
      need(nchar(ta) > 0, "Please enter a ticker for Asset A."),
      need(nchar(tb) > 0, "Please enter a ticker for Asset B."),
      need(input$date_range[1] < input$date_range[2], "Start date must be before end date.")
    )

    result <- fetch_all_assets(ta, tb, input$date_range[1], input$date_range[2])

    validate(
      need(is.null(result$error), result$error)
    )

    result$prices
  })

  # --------------------------------------------------------------------------
  # Reactive: Portfolio values
  # --------------------------------------------------------------------------
  portfolio_vals <- reactive({
    req(price_data())
    compute_portfolio_values(price_data(), input$initial_investment)
  })

  # --------------------------------------------------------------------------
  # Reactive: Daily returns (always computed for summary stats)
  # --------------------------------------------------------------------------
  daily_returns <- reactive({
    req(price_data())
    calculate_returns(price_data(), period = "daily")
  })

  # --------------------------------------------------------------------------
  # Reactive: Periodic returns based on user selection
  # --------------------------------------------------------------------------
  periodic_returns <- reactive({
    req(price_data())
    calculate_returns(price_data(), period = input$returns_period)
  })

  # ==========================================================================
  # TAB 1: Portfolio Value
  # ==========================================================================

  output$portfolio_chart <-
    debounce(
      renderPlotly({
        req(portfolio_vals())
        plot_portfolio_value(portfolio_vals(), ticker_a_clean(), ticker_b_clean())
      }),
      millis = 1500
    )

  output$portfolio_summary_table <-
    debounce(
      renderFormattable({
        req(portfolio_vals(), daily_returns())

        summary_df <- build_portfolio_summary(portfolio_vals(), daily_returns())

        # Gradient bar formatter like the reference project
        bar_formatter <- function() {
          formatter("span",
            style = x ~ style(
              display = "inline-block",
              direction = "rtl",
              "border-radius" = "4px",
              "padding-right" = "4px",
              "background-color" = csscolor("darkslategray"),
              width = percent(proportion(x)),
              color = csscolor(gradient(x, "red", "green"))
            )
          )
        }

        # Green-highlight the best value
        green_best <- formatter(
          "span",
          style = x ~ ifelse(
            x == max(x),
            style(color = "#2ECC71", font.weight = "bold"),
            NA
          )
        )

        # Worst Day: least negative is best
        worst_best <- formatter(
          "span",
          style = x ~ ifelse(
            x == max(x),
            style(color = "#2ECC71", font.weight = "bold"),
            NA
          )
        )

        formattable(
          summary_df,
          list(
            `Starting Value` = green_best,
            `Ending Value` = bar_formatter(),
            `Max Value` = bar_formatter(),
            `Min Value` = green_best,
            `Total Return (%)` = bar_formatter(),
            `Best Day (%)` = green_best,
            `Worst Day (%)` = worst_best
          )
        )
      }),
      millis = 1500
    )

  # ==========================================================================
  # TAB 2: Returns Analysis
  # ==========================================================================

  output$returns_chart <-
    debounce(
      renderPlotly({
        req(periodic_returns())
        period_label <- tools::toTitleCase(input$returns_period)
        plot_returns_timeseries(periodic_returns(), ticker_a_clean(), ticker_b_clean(), period_label)
      }),
      millis = 1500
    )

  output$returns_distribution <-
    debounce(
      renderPlotly({
        req(periodic_returns())
        plot_return_distribution(periodic_returns(), ticker_a_clean(), ticker_b_clean())
      }),
      millis = 1500
    )

  output$descriptive_stats_table <-
    debounce(
      renderFormattable({
        req(periodic_returns())
        stats_df <- calculate_descriptive_stats(periodic_returns())

        stats_formatted <- stats_df
        stats_formatted[] <- lapply(stats_formatted, function(x) round(x, 6))

        stats_formatted <- cbind(
          Asset = rownames(stats_formatted),
          stats_formatted
        )
        rownames(stats_formatted) <- NULL

        formattable(
          stats_formatted,
          list(
            Mean = formatter("span",
              style = x ~ ifelse(x == max(x),
                style(color = "#2ECC71", font.weight = "bold"), NA)),
            `Std Dev` = formatter("span",
              style = x ~ ifelse(x == min(x),
                style(color = "#2ECC71", font.weight = "bold"), NA))
          )
        )
      }),
      millis = 1500
    )

  # ==========================================================================
  # TAB 3: Risk-Adjusted Returns
  # ==========================================================================

  output$sharpe_chart <-
    debounce(
      renderPlotly({
        req(periodic_returns())
        sharpe_df <- calculate_full_sharpe_ratios(
          periodic_returns(),
          risk_free_rate = input$risk_free_rate / 100,
          period = input$returns_period
        )
        plot_sharpe_ratios_full(sharpe_df, ticker_a_clean(), ticker_b_clean())
      }),
      millis = 1500
    )

  output$drawdown_chart <-
    debounce(
      renderPlotly({
        req(daily_returns())
        dd <- calculate_drawdowns(daily_returns())
        max_dd <- calculate_max_drawdown(daily_returns())
        plot_drawdowns(dd, max_dd, ticker_a_clean(), ticker_b_clean())
      }),
      millis = 1500
    )

  output$rolling_corr_chart <-
    debounce(
      renderPlotly({
        req(daily_returns())
        ta <- ticker_a_clean()
        tb <- ticker_b_clean()
        rolling_cor <- calculate_rolling_correlation(
          daily_returns()[, ta],
          daily_returns()[, tb],
          window = 30
        )
        plot_rolling_correlation(rolling_cor, ta, tb, window = 30)
      }),
      millis = 1500
    )

  # ==========================================================================
  # TAB 4: Data Explorer
  # ==========================================================================

  output$data_row_count <- renderText({
    req(price_data())
    paste0(nrow(price_data()), " trading days of data")
  })

  output$data_table <- DT::renderDataTable({
    req(price_data())
    df <- data.frame(
      Date = index(price_data()),
      coredata(price_data()),
      check.names = FALSE
    )
    # Round prices to 2 decimals for display
    numeric_cols <- sapply(df, is.numeric)
    df[numeric_cols] <- lapply(df[numeric_cols], round, 2)

    DT::datatable(
      df,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'lfrtip',
        language = list(
          search = "Filter:",
          lengthMenu = "Show _MENU_ rows"
        )
      ),
      rownames = FALSE,
      class = "display compact"
    )
  })

  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("equity_data_", ticker_a_clean(), "_", ticker_b_clean(), "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- data.frame(
        Date = index(price_data()),
        coredata(price_data()),
        check.names = FALSE
      )
      write.csv(df, file, row.names = FALSE)
    }
  )
}


# ==============================================================================
# Run the app
# ==============================================================================
shinyApp(ui = ui, server = server)
