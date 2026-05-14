# app.R -----------------------------------------------------------------------
#
# Shiny app: wOBA vs xwOBA trend explorer for the 2026 Mariners.
#
# Players above the diagonal are over-performing their expected stats
# (wOBA > xwOBA) and may regress. Players below are under-performing
# and have potential upside.
#
# Port is hardcoded for consistent Coder workspace port-forwarding.
# Forward port 3838 in your Coder template or `coder port-forward` command.

library(shiny)
library(ggplot2)
library(dplyr)
library(here)

PORT <- 3838L

# ---- UI ---------------------------------------------------------------------

ui <- fluidPage(

  titlePanel("Mariners 2026 — wOBA vs xwOBA trends"),

  sidebarLayout(
    sidebarPanel(
      width = 3,

      sliderInput("min_pa", "Minimum plate appearances:",
                  min = 10, max = 200, value = 50, step = 10),

      hr(),

      # Threshold for colouring a player as meaningfully over/under-performing
      sliderInput("threshold", "Colour threshold (wOBA − xwOBA):",
                  min = 0.005, max = 0.050, value = 0.020, step = 0.005),

      hr(),

      tags$p(tags$b("Above the line"), "— wOBA > xwOBA.",
             "Player is out-performing their batted-ball profile.",
             "Expect some regression."),
      tags$p(tags$b("Below the line"), "— xwOBA > wOBA.",
             "Player is under-performing. Upside still in the profile."),
      tags$p(tags$em("Click a dot to see details."))
    ),

    mainPanel(
      width = 9,

      plotOutput("scatter",
                 height = "520px",
                 click  = "plot_click"),

      hr(),

      fluidRow(
        column(6, tableOutput("click_info")),
        column(6, tableOutput("summary_table"))
      )
    )
  )
)

# ---- Server -----------------------------------------------------------------

server <- function(input, output, session) {

  # Reactive: filtered + labelled batting data
  batting <- reactive({
    path <- here("data", "batting_2026.rds")
    req(file.exists(path))
    readRDS(path) |>
      filter(pa >= input$min_pa) |>
      mutate(
        diff  = woba - xwoba,
        trend = case_when(
          diff >  input$threshold ~ "Over-performing",
          diff < -input$threshold ~ "Under-performing",
          TRUE                    ~ "On track"
        ),
        trend = factor(trend, levels = c("Over-performing", "On track", "Under-performing"))
      )
  })

  # Main scatter plot
  output$scatter <- renderPlot({
    df <- batting()

    # Axis range: symmetric around the diagonal with a little padding
    lim <- range(c(df$woba, df$xwoba), na.rm = TRUE)
    pad <- diff(lim) * 0.08
    lim <- c(lim[1] - pad, lim[2] + pad)

    ggplot(df, aes(x = xwoba, y = woba, colour = trend, size = pa)) +
      # Identity line: wOBA == xwOBA
      geom_abline(slope = 1, intercept = 0,
                  linetype = "dashed", colour = "grey55", linewidth = 0.7) +
      # Threshold band
      geom_abline(slope = 1, intercept =  input$threshold,
                  linetype = "dotted", colour = "#C8102E", alpha = 0.5) +
      geom_abline(slope = 1, intercept = -input$threshold,
                  linetype = "dotted", colour = "#0C2C56", alpha = 0.5) +
      geom_point(alpha = 0.85) +
      ggrepel::geom_text_repel(
        aes(label = player),
        size = 3.5, max.overlaps = 20, seed = 42, box.padding = 0.4,
        show.legend = FALSE
      ) +
      scale_colour_manual(
        values = c(
          "Over-performing"  = "#C8102E",   # Mariners red — hot, likely to cool
          "On track"         = "grey60",
          "Under-performing" = "#0C2C56"    # Mariners navy — cold, upside remaining
        ),
        drop = FALSE
      ) +
      scale_size_continuous(range = c(3, 10), name = "PA") +
      coord_fixed(xlim = lim, ylim = lim) +
      labs(
        title    = "wOBA vs xwOBA — who is over/under-performing?",
        subtitle = paste0("Dashed line = perfect agreement  ·  ",
                          "Dotted lines = ±", input$threshold, " threshold"),
        x        = "xwOBA  (expected, from batted-ball quality)",
        y        = "wOBA  (actual)",
        colour   = NULL
      ) +
      theme_minimal(base_size = 13) +
      theme(legend.position = "bottom")
  })

  # Click-to-inspect: show full stat line for the nearest point
  output$click_info <- renderTable({
    req(input$plot_click)
    df <- batting()
    near <- nearPoints(df, input$plot_click,
                       xvar = "xwoba", yvar = "woba",
                       maxpoints = 1, threshold = 20)
    req(nrow(near) > 0)
    near |>
      select(Player = player, PA = pa,
             wOBA = woba, xwOBA = xwoba, Diff = diff, Trend = trend)
  },
  digits = 3,
  caption = "Selected player",
  caption.placement = "top")

  # Summary table: biggest movers sorted by absolute gap
  output$summary_table <- renderTable({
    batting() |>
      arrange(desc(abs(diff))) |>
      select(Player = player, PA = pa,
             wOBA = woba, xwOBA = xwoba, Diff = diff, Trend = trend) |>
      head(8)
  },
  digits = 3,
  caption = "Largest wOBA − xwOBA gaps",
  caption.placement = "top")
}

# ---- Launch -----------------------------------------------------------------

shinyApp(
  ui     = ui,
  server = server,
  options = list(
    port = PORT,
    host = "0.0.0.0"   # bind to all interfaces so Coder can forward the port
  )
)
