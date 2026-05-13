# ---------------------- #
# FULL ANALYSIS PIPELINE (Fixed for Correct Column Name)
# ---------------------- #

# Load required libraries
library(plyr)
library(sqldf)
library(markovchain)
library(dplyr)

# ---------------------- #
# STEP 1: SET FILE PATHS #
# ---------------------- #

print("Loading input data...")

# Define file paths (Input Files)
#For Example:
INPUT_FOLDER <- "C:/Users/Sumed Seeyakmani/OneDrive/Documents/Penalty Sequence Analysis/input_files/"
BOOTSTRAP_FOLDER <- "C:/Users/Sumed Seeyakmani/OneDrive/Documents/Penalty Sequence Analysis/bootstrap/"
OUTPUT_FOLDER <- "C:/Users/Sumed Seeyakmani/OneDrive/Documents/Penalty Sequence Analysis/output_files/"

#INPUT_FOLDER <- "C:/path/to/Penalty_Shootout_Analysis/input_files/"
#BOOTSTRAP_FOLDER <- "C:/path/to/Penalty_Shootout_Analysis/bootstrap/"
#OUTPUT_FOLDER <- "C:/path/to/Penalty_Shootout_Analysis/output_files/"


# Load input files
shootout_data <- read.csv(paste0(INPUT_FOLDER, "shootout_data.csv"))
aph_mapping <- read.csv(paste0(INPUT_FOLDER, "aph_competition_mapping.csv"))
international_competitions <- read.csv(paste0(INPUT_FOLDER, "international_competitions.csv"))

# Function to identify and summarize NAs
na_summary <- function(df) {
  na_counts <- sapply(df, function(x) sum(is.na(x)))
  na_percentage <- na_counts / nrow(df) * 100
  na_table <- data.frame(
    Variable = names(df),
    NA_Count = na_counts,
    NA_Percentage = na_percentage
  )
  return(na_table[na_table$NA_Count > 0, ])
}

# Apply function to shootout data
na_report1 <- na_summary(shootout_data)
print(na_report1)
na_report2 <- na_summary(aph_mapping)
print(na_report2)
na_report3 <- na_summary(international_competitions)
print(na_report3)

# ------------------------ #
# STEP 2: DATA PROCESSING #
# ------------------------ #

print("Processing shootout data...")

# Prepare Data
pso <- NULL
for (g in 1:nrow(shootout_data)) {
  kickNumber <- 1
  teamAScore <- 0
  teamBScore <- 0
  for (shot in strsplit(as.character(shootout_data[g,]$goal_scored), "")[[1]]) {
    is_team_A_shot <- kickNumber %% 2
    isConverted <- ifelse(shot == 'Y', 1, 0)
    gd <- teamAScore - teamBScore
    if (is_team_A_shot) {
      teamAScore <- teamAScore + isConverted
    } else {
      teamBScore <- teamBScore + isConverted
    }
    round <- floor((kickNumber + 1) / 2)
    uri <- as.numeric(shootout_data[g,]$uri)
    pso <- rbind(pso, c(uri, kickNumber, is_team_A_shot, isConverted, teamAScore, teamBScore, round, gd))
    kickNumber <- kickNumber + 1
  }
}

colnames(pso) <- c("uri", "kickNumber", "is_team_A_shot", "isConverted", "teamAScore", "teamBScore", "round", "gd")
pso <- data.frame(pso, stringsAsFactors = FALSE)

# Compute shootout winners
shootout_results <- pso %>% filter(is_team_A_shot == 1 & kickNumber == max(kickNumber)) %>%
  mutate(is_team_A_winner = ifelse(teamAScore > teamBScore, 1, 0))

shootout_data <- merge(shootout_data, shootout_results[, c("uri", "is_team_A_winner")], by = "uri")

# ------------------------------ #
# STEP 3: GENERATE BOOTSTRAPPED DATA (Lower Iterations for Faster Processing)
# ------------------------------ #

print("Generating bootstrapped samples...")

bootstrap_function <- function(num_iterations, shootouts, output_file) {
  results <- list()
  for (i in 1:num_iterations) {
    sample_shootouts <- shootouts[sample(1:nrow(shootouts), replace = TRUE), ]
    results[[i]] <- sample_shootouts
  }
  write.csv(do.call(rbind, results), file = output_file, row.names = FALSE)
}


bootstrap_function(100, pso, paste0(BOOTSTRAP_FOLDER, "bootstrap_aph.csv"))
bootstrap_function(100, pso, paste0(BOOTSTRAP_FOLDER, "bootstrap_extended.csv"))

# ------------------------------ #
# STEP 4: LOAD BOOTSTRAPPED SIMULATION DATA #
# ------------------------------ #

print("Loading precomputed simulation data...")

# Load files for APH competitions
aph_ABAB <- read.csv(paste0(BOOTSTRAP_FOLDER, "aph_ABAB.csv"))
aph_ABBA <- read.csv(paste0(BOOTSTRAP_FOLDER, "aph_ABBA.csv"))
aph_tm <- read.csv(paste0(BOOTSTRAP_FOLDER, "aph_tm.csv"))

# Load files for all competitions
extended_ABAB <- read.csv(paste0(BOOTSTRAP_FOLDER, "extended_ABAB.csv"))
extended_ABBA <- read.csv(paste0(BOOTSTRAP_FOLDER, "extended_ABBA.csv"))
extended_TM <- read.csv(paste0(BOOTSTRAP_FOLDER, "extended_tm-1.csv"))  # Using extended_tm-1.csv as specified

# ---------------------- #
# STEP 5: ADD DYNAMIC SEQUENCES
# ---------------------- #


print("Estimating Bayesian priors from bootstrapped data...")



# Function to Estimate Priors Dynamically
estimate_priors <- function(data) {
  p_hat <- mean(data, na.rm = TRUE)
  var_hat <- var(data, na.rm = TRUE)
  alpha_est <- max(p_hat * ((p_hat * (1 - p_hat)) / var_hat - 1), 1)
  beta_est <- max((1 - p_hat) * ((p_hat * (1 - p_hat)) / var_hat - 1), 1)
  return(list(alpha = alpha_est, beta = beta_est))
}

# Combine Bootstrapped Data from ABAB, ABBA, and TM
combined_penalty_data <- c(aph_ABAB$val, aph_ABBA$val, aph_tm$val, extended_ABAB$val, extended_ABBA$val, extended_TM$val )

# Estimate global priors from all sequences
global_priors <- estimate_priors(combined_penalty_data)



update_bayesian_probability <- function(alpha, beta, successes, failures, weight = 0.1) {
  new_alpha <- alpha + weight * successes
  new_beta <- beta + weight * failures
  p_est <- rbeta(1, new_alpha, new_beta)
  return(min(max(p_est, 0.6), 0.9))  # Constrain between 60% and 90%
}


print("Simulating dynamic penalty sequences with Bayesian updating...")

simulate_dynamic_sequence <- function(num_shootouts = 10000, rule_type) {
  
  results <- data.frame(team_A_win = numeric(num_shootouts))
  
  for (i in 1:num_shootouts) {
    
    # Dynamically estimate priors for each shootout
    priors <- global_priors
    
    team_A_score <- 0
    team_B_score <- 0
    
    # Initialize separate probabilities for Team A & B
    alpha_A <- priors$alpha
    beta_A <- priors$beta
    alpha_B <- priors$alpha
    beta_B <- priors$beta
    
    p_goal_A <- rbeta(1, alpha_A, beta_A)
    p_goal_B <- rbeta(1, alpha_B, beta_B)
    
    for (round in 1:10) {
      
      # Determine shooting order dynamically
      team_A_shoots_first <- switch(rule_type,
                                    "catch_up" = (team_A_score < team_B_score),
                                    "adjusted_catch_up" = ifelse(round <= 5, (team_A_score < team_B_score), FALSE),
                                    "behind_first" = (team_A_score < team_B_score),
                                    "adjusted_behind_first" = ifelse(round <= 5, (team_A_score < team_B_score), FALSE))
      
      # Team A Shoots
      team_A_shot <- sample(c(1, 0), 1, prob = c(p_goal_A, 1 - p_goal_A))
      team_A_score <- team_A_score + team_A_shot
      p_goal_A <- update_bayesian_probability(alpha_A, beta_A, team_A_shot, 1 - team_A_shot)
      
      # Team B Shoots
      team_B_shot <- sample(c(1, 0), 1, prob = c(p_goal_B, 1 - p_goal_B))
      team_B_score <- team_B_score + team_B_shot
      p_goal_B <- update_bayesian_probability(alpha_B, beta_B, team_B_shot, 1 - team_B_shot)
      
      if (round >= 3 && abs(team_A_score - team_B_score) > (5 - round)) {
        break
      }
    }
    
    results$team_A_win[i] <- as.numeric(team_A_score > team_B_score)
  }
  
  return(results)
}



set.seed(123)
catch_up_results <- simulate_dynamic_sequence(10000, "catch_up")
adjusted_catch_up_results <- simulate_dynamic_sequence(10000, "adjusted_catch_up")
behind_first_results <- simulate_dynamic_sequence(10000, "behind_first")
adjusted_behind_first_results <- simulate_dynamic_sequence(10000, "adjusted_behind_first")

# ---------------------- #
# STEP 6: FIX COMPUTATION OF TABLE 3
# ---------------------- #

print("Computing final statistics...")

compute_table3 <- function(data) {
  if ("val" %in% colnames(data)) {
    # Static sequences (ABAB, ABBA, TM)
    return(c(mean(data$val), quantile(data$val, probs = c(0.01, 0.05, 0.5, 0.95, 0.99), na.rm = TRUE)))
  } else {
    # Dynamic sequences (Catch-Up, Adjusted Catch-Up, etc.)
    win_rates <- cumsum(data$team_A_win) / seq_along(data$team_A_win)  # Rolling win rate
    return(c(mean(data$team_A_win), quantile(win_rates, probs = c(0.01, 0.05, 0.5, 0.95, 0.99), na.rm = TRUE)))
  }
}


table_3 <- data.frame(
  aph_ABAB = compute_table3(aph_ABAB),
  aph_ABBA = compute_table3(aph_ABBA),
  aph_tm = compute_table3(aph_tm),
  extended_ABAB = compute_table3(extended_ABAB),
  extended_ABBA = compute_table3(extended_ABBA),
  extended_TM = compute_table3(extended_TM),
  Catch_Up = compute_table3(catch_up_results),
  Adjusted_Catch_Up = compute_table3(adjusted_catch_up_results),
  Behind_First = compute_table3(behind_first_results),
  Adjusted_Behind_First = compute_table3(adjusted_behind_first_results)
)

write.csv(table_3, file = paste0(OUTPUT_FOLDER, "final_results.csv"), row.names = TRUE)

# ------------------------------ #
# COMPLETION #
# ------------------------------ #

print("Analysis complete! Results saved in the output folder.")
