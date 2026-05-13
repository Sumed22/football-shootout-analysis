# Football Shootout Analysis

A statistical analysis of football penalty shootout fairness using empirical data, bootstrapping, Bayesian updating, Monte Carlo simulation, and Markov chains in R.

This project re-evaluates the findings of Csató & Petróczy (2021) by extending the analysis to dynamic penalty shootout sequences and incorporating empirical simulation methods.

---

## Project Overview

Penalty shootouts have long been debated due to the potential **First Mover Advantage (FMA)**, where the team shooting first may have a higher probability of winning.

This project compares the fairness of multiple penalty shootout formats:

### Static Sequences
- ABAB (Traditional format)
- ABBA
- Thue-Morse (ABBA|BAAB)

### Dynamic Sequences
- Catch-Up
- Adjusted Catch-Up
- Behind-First
- Adjusted Behind-First

The analysis combines:
- Bootstrapping
- Bayesian Updating (Beta-Binomial Model)
- Monte Carlo Simulation
- Markov Chain Modeling

---

## Key Findings

- The traditional **ABAB** sequence shows a noticeable bias toward the first-shooting team.
- **ABBA** significantly reduces this imbalance and performs closest to fairness.
- Dynamic rules such as **Catch-Up** and **Behind-First** unexpectedly bias the shootout toward the second-shooting team.
- The results challenge the theoretical conclusions proposed by Csató & Petróczy (2021).

---

## Technologies Used

- R (Version 4.4.2)
- plyr
- dplyr
- sqldf
- markovchain

---

## Project Structure

```text
football-shootout-analysis/
│── README.md
│── report/
│   └── Penalty_Sequence_Analysis.pdf
│── scripts/
│   └── analysis_pipeline.R
│── input_files/
│   ├── shootout_data.csv
│   ├── aph_competition_mapping.csv
│   └── international_competitions.csv
│── bootstrap/
│── output_files/
```

---

## Installation

Install the required R packages:

```r
install.packages(c(
  "plyr",
  "sqldf",
  "markovchain",
  "dplyr"
))
```

---

## Running the Analysis

### 1. Open RStudio

Open the project folder in RStudio or another R-compatible IDE.

### 2. Set Working Directory

Update the paths inside `analysis_pipeline.R`:

```r
INPUT_FOLDER <- "path/to/input_files/"
BOOTSTRAP_FOLDER <- "path/to/bootstrap/"
OUTPUT_FOLDER <- "path/to/output_files/"
```

### 3. Run the Script

Execute the full analysis pipeline:

```r
source("scripts/analysis_pipeline.R")
```

The script will:

1. Load and preprocess historical penalty shootout data
2. Generate bootstrapped datasets
3. Estimate Bayesian priors
4. Simulate dynamic penalty shootout sequences
5. Compute winning probabilities
6. Export the final results

---

## Output

Final simulation results are saved in:

```text
output_files/final_results.csv
```

The output includes:
- Mean winning probabilities
- Quantile estimates
- Comparison across all shootout formats

---

## Statistical Methods

### Bootstrapping
Used to generate synthetic datasets from observed penalty shootout outcomes.

### Bayesian Updating
Implemented using the Beta-Binomial conjugate model to dynamically estimate scoring probabilities.

### Monte Carlo Simulation
Thousands of simulated shootouts were generated to evaluate fairness across different rules.

### Markov Chains
Used to model transitions between score states during penalty shootouts.

---

## Report

The full academic report can be found here:

```text
report/Penalty_Sequence_Analysis.pdf
```

---

## References

- Csató, L., & Petróczy, D. G. (2022). *Fairness in penalty shootouts: Is it worth using dynamic sequences?*
- Rudi, N., Olivares, M., & Shetty, A. (2020). *Ordering sequential competitions to reduce order relevance: Soccer penalty shootouts.*
- Murphy, K. P. (2013). *Machine Learning: A Probabilistic Perspective.*
- Levin, D. A., Peres, Y., & Wilmer, E. L. (2006). *Markov Chains and Mixing Times.*

---

## Author

**Sumed Seeyakmani Kuson**  
B.Sc. Data Science  
TU Dortmund University
