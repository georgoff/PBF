list.of.packages <- c("shiny", "data.table", "DT")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(shiny)
library(data.table)
library(DT)

rm(list = ls())

source("H:/georgoff.github.io/forest_malaria/TaR-malaria-functions.R")

ui <- fluidPage(
  titlePanel("Forest Malaria Simulator"),
  
  tabsetPanel(
    tabPanel("Home",
             img(src = "mosely.png", height = 600, width = 600)),
    
    tabPanel("Constants",
             sidebarLayout(
               sidebarPanel(numericInput(inputId = "a",
                                         label = "a: Human Blood Feeding Rate",
                                         value = 0.88,
                                         min = 0, max = 1, step = 0.01),
                            numericInput(inputId = "b",
                                         label = "b: Proportion of Bites by Infectious Mosquitoes That Cause an Infection",
                                         value = 0.55,
                                         min = 0, max = 1, step = 0.01),
                            numericInput(inputId = "c",
                                         label = "c: Proportion of Mosquitoes Infected After Biting Infectious Human",
                                         value = 0.15,
                                         min = 0, max = 1, step = 0.01),
                            numericInput(inputId = "g",
                                         label = "g: Per Capita Death Rate of Mosquitoes",
                                         value = 0.1,
                                         min = 0, max = 1, step = 0.01),
                            numericInput(inputId = "n",
                                         label = "n: Time for Sporogonic Cycle",
                                         value = 12,
                                         min = 0, step = 0.5),
                            numericInput(inputId = "r",
                                         label = "r: Rate that Humans Recover from an Infection",
                                         value = 1/200,
                                         min = 0)),
               
               mainPanel(DTOutput(outputId = "constants_table",
                                  width = "35%")))
             ),
    
    tabPanel("Parameters",
             sidebarLayout(
               sidebarPanel(fileInput(inputId = "params_csv",
                                      label = "Upload params.csv",
                                      accept = c("text/csv",
                                                 "text/comma-separated-values,text/plain",
                                                 ".csv")),
                            fileInput(inputId = "psi_csv",
                                      label = "Upload psi.csv",
                                      accept = c("text/csv",
                                                 "text/comma-separated-values,text/plain",
                                                 ".csv"))),
               
               mainPanel(dataTableOutput(outputId = "params_table",
                                         width = "35%"),
                         dataTableOutput(outputId = "psi_table",
                                         width = "50%"))
             )
             ),
    
    tabPanel("R Values",
             sidebarLayout(
               sidebarPanel(numericInput(inputId = "R_min",
                                         label = "Minimum R Value",
                                         value = 0,
                                         min = 0, step = 0.5),
                            numericInput(inputId = "R_max",
                                         label = "Maximum R Value",
                                         value = 3,
                                         min = 0, step = 0.5),
                            numericInput(inputId = "R_step",
                                         label = "Step Size Between R Values",
                                         value = 0.1,
                                         min = 0, step = 0.1)),
               
               mainPanel(textOutput(outputId = "R_statement"))
             )),
    
    tabPanel("Execute",
             sidebarLayout(
               sidebarPanel(
                 h3("If you are satisfied with simulation setup, press GO:"),
                 actionButton(inputId = "go_button",
                              label = "GO",
                              width = "100%")
                 # downloadButton(outputId = "download_button",
                 #                label = "Download Results")
                 ),
               
               mainPanel(
                 dataTableOutput(outputId = "results_table")
               )
             ))
  )
  
)

server <- function(input, output) {
  output$constants_table <- renderDT({
    table <- as.data.table(matrix(nrow = 6, ncol = 2))
    names(table) <- c("Constant", "Value")
    table[, "Constant"] <- c("a", "b", "c", "g", "n", "r")
    table[, "Value"] <- as.character(c(input$a, input$b, input$c,
                          input$g, input$n, input$r))
    
    table
  })
  
  observeEvent(input$params_csv,
               {
                 inFile_params <- input$params_csv
                 
                 output$params_table <- renderDT({
                   return(read.csv(inFile_params$datapath))
                 }
                 )
               })
  
  observeEvent(input$psi_csv,
               {
                 output$psi_table <- renderDT({
                   return(read.csv(input$psi_csv$datapath))
                 })
               })
  
  output$R_statement <- renderText({
    paste0("R will range from ", as.character(input$R_min), " to ", as.character(input$R_max),
              ", with a step size of ", as.character(input$R_step))
  })
  
  observeEvent(input$go_button, {
    variables <- initialize_variables(inFile_params = input$params_csv,
                                      inFile_psi = input$psi_csv)
    
    results <- create_results_table(R_min = input$R_min,
                                    R_max = input$R_max,
                                    R_step = input$R_step,
                                    locs = variables$locs)
    
    output$results_table <- renderDT({
      withProgress(message = "Working", value = 0, {
        # solve!
        results <- solve_all_R_values(results = results,
                                      locs = variables$locs,
                                      Psi = variables$Psi,
                                      H = variables$H,
                                      S = input$a / input$g,
                                      c = input$c)
      })
      
      results
    },
    server = FALSE,
    extensions = "Buttons", options = list(
      dom = "Bfrtip",
      buttons = 
        list("copy", "print", list(
          extend = "collection",
          buttons = c("csv", "excel", "pdf"),
          text = "Download"
        ))
    ))
  })
  
  # output$download_button <- downloadHandler(
  #   filename = function() {
  #     "simulation_results.csv"
  #   },
  #   content = function(file) {
  #     write.csv(results, file, row.names = FALSE)
  #   }
  # )
}

shinyApp(ui = ui, server = server)