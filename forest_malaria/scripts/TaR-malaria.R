########################
# TaR Malaria
#
# Author: Alec Georgoff
#
# Purpose: Solve for equilibrium prevalence values given R values in a complex system
########################

rm(list = ls())

list.of.packages <- c("rootSolve", "data.table", "plotly", "ggplot2", "gridExtra")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

require(rootSolve)
require(data.table)
require(plotly)
require(ggplot2)
require(gridExtra)

###################################
#
# Set parameters
#
###################################

# specify filepaths for parameter .csv files:

params_path <- "H:/georgoff.github.io/forest_malaria/example1/params.csv"
psi_path <- "H:/georgoff.github.io/forest_malaria/example1/psi.csv"
r_values_path <- "H:/georgoff.github.io/forest_malaria/example1/r_values.csv"

# Output settings:
output_csv <- TRUE
output_bar_PDF <- FALSE
output_line_PDF <- FALSE
csv_filepath <- "H:/georgoff.github.io/forest_malaria/example1/results.csv"
pdf_bar_filepath <- "H:/georgoff.github.io/forest_malaria/example1/bar.pdf"
pdf_line_filepath <- "H:/georgoff.github.io/forest_malaria/lines.pdf"

# this script assumes that the following parameters are the same for every
# location; in reality this may not be accurate. an update may be made that
# allows for custom parameters in every location

a <- 0.88   # human blood feeding rate
b <- 0.55   # proportion of bites by infectious mosquitoes that cause an infection
c <- 0.15   # proportion of mosquitoes infected after biting infectious human
g <- 0.1    # per capita death rate of mosquitoes
r <- 1/200  # rate that humans recover from an infection
n <- 12     # time for sporogonic cycle
S <- a/g    # stability index

###################################
#
# Establish matrices of variables
#
###################################

# read in village and forest parameters from .csv file:

params <- as.data.table(read.csv(params_path))

# n_villages <- nrow(params)

H <- params$H
X <- vector(mode = "numeric", length = length(H))

Psi <- as.data.table(read.csv(psi_path))
Psi[, id := NULL]
Psi <- as.matrix(Psi)
Psi_dt <- as.data.table(Psi)

locs <- names(Psi_dt)

H_psi <- t(Psi) %*% H
X_psi <- t(Psi) %*% X

# choose starting point for root solver:
theta_start <- vector(mode = "numeric", length = length(H))
theta_start[1:length(theta_start)] <- 0.9

# convert to number of humans:
X_start <- theta_start * H

###################################
#
# Set up the equations as a function
#
###################################

model <- function(X, Psi, R, c_val, S_val, H) {
  
  theta_psi <- (t(Psi) %*% X) / (t(Psi) %*% H)
  
  equation_vector <- (Psi %*% (R * (theta_psi/(c_val*S_val*theta_psi + 1)))) *
    (H-X) - X
  
  return(equation_vector)
  
}

###################################
#
# Solve for roots
#
###################################

find_roots <- function(R,
                       Psi. = Psi,
                       H. = H,
                       S. = S,
                       c_val = c,
                       X_start. = X_start) {
  
  # use multiroot solver to find roots:
  ss <- multiroot(f = model, start = X_start.,
                  positive = TRUE, maxiter = 1000,
                  ctol = 1e-20,
                  Psi = Psi.,
                  R = R,
                  c_val = c_val,
                  S_val = S.,
                  H = H.)
  
  return(ss)
}

###################################
#
# Set up results table
#
###################################
 
# all_R_values <- seq(R_min, R_max, R_step)

all_R_values <- as.data.table(read.csv(r_values_path))

list_of_R_values <- list(NULL)

for (i in 1:length(locs)) {
  list_of_R_values[[i]] <- seq(all_R_values[id == locs[i]]$R_min,
                               all_R_values[id == locs[i]]$R_max,
                               all_R_values[id == locs[i]]$R_step)
  
  names(list_of_R_values)[i] <- locs[i]
}

# fill results table with every possible combination of
# R values:

results <- as.data.table(expand.grid(list_of_R_values))

# put in placeholder for theta values:

theta_holder <- as.data.table(matrix(data = 0, nrow = nrow(results),
                                     ncol = length(locs)))

for (k in 1:length(locs)) {
  names(theta_holder)[k] <- paste0("theta_", locs[k])
}

results <- cbind(results, theta_holder)

###################################
#
# Cycle through R values
#
###################################

for (i in 1:nrow(results)) {
  cat("Working on ", i, " of ", nrow(results), "\n")
  
  these_R_values <- unlist(results[i, 1:length(locs)], use.names = FALSE)
  
  X_solutions <- find_roots(these_R_values)$root
  
  theta_solutions <- (t(Psi) %*% X_solutions) / H_psi
  
  for (j in (1 + length(locs)):ncol(results)) {
    results[i, j] <- theta_solutions[j - length(locs)]
  }
}

###################################
#
# Create .csv of results
#
###################################

if (output_csv) {
  write.csv(results, file = csv_filepath)
}

###################################
#
# Create PDF of results
#
###################################

if (output_bar_PDF) {
  pdf(pdf_bar_filepath)
  
  this_row_locs <- vector(mode = "character", length = length(locs))
  
  for (j in 1:nrow(results)) {
    for (location in 1:length(locs)) {
      this_row_locs[location] <- paste0(locs[location],
                                        "\nR = ",
                                        as.character(results[j, ..location]))
    }
    
    this_row <- data.table(loc = this_row_locs,
                           theta = unlist(results[j, (1+length(locs)):ncol(results)],
                                          use.names = F))
    
    bar <- ggplot(data = this_row,
                  aes(x = loc, y = theta)) +
      geom_col() +
      geom_text(aes(label = round(theta, 3), y = theta + 0.02)) +
      coord_cartesian(ylim = c(0,0.31))
    
    print(bar)
  }
  
  dev.off()
}

# NOTE: this output functionality was used once for a specific case and will not work for most
# model parameters.

# if (output_line_PDF) {
#   line1 <- ggplot(data = results, aes(x = V1, y = theta_V1)) +
#     geom_point()
#   
#   line2 <- ggplot(data = results, aes(x = V2, y = theta_V2)) +
#     geom_point()
#   
#   line3 <- ggplot(data = results, aes(x = V3, y = theta_V3)) +
#     geom_point()
#   
#   line4 <- ggplot(data = results, aes(x = V4, y = theta_V4)) +
#     geom_point()
#   
#   line5 <- ggplot(data = results, aes(x = V5, y = theta_V5)) +
#     geom_point()
#   
#   grid.arrange(line1, line2, line3, line4, line5, nrow = 3)
# }