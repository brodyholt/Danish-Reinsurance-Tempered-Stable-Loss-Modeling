# =============================================================================
# Loss Modeling of Danish Reinsurance Claims with Tempered Stable Model
# =============================================================================


# ── Load Libraries ─────────────────────────────────────────────────────────────

#install.packages(c("stabledist", "TempStable", "tidyverse", "CASdatasets", "ggplot2", "actuar", "twosamples", "evir", "gt"), repos = c("https://cas.uqam.ca/pub/", "https://cran.r-project.org"))

library(stabledist)
library(TempStable)
library(tidyverse)
library(CASdatasets)
library(ggplot2)
library(actuar)
library(fitdistrplus)
library(twosamples)
library(evir)
library(gt)


# ── Exploratory Analysis ───────────────────────────────────────────────────────

# Load data
data(danishuni)
df <- danishuni
df <- df %>% 
  mutate("Year" = year(Date)) 

# Summary statistics
df %>% dplyr::select(Loss) %>% 
  summarize(Mean = mean(Loss),
            Median = median(Loss),
            Variance = var(Loss),
            SD = sd(Loss),
            CV = sd(Loss)/mean(Loss)) %>% 
  gt()

# Aggregate frequency and severity
df %>% 
  group_by(Year) %>% 
  summarize(Count = n(), AggLoss = sum(Loss)) %>% 
  ungroup() %>% 
  summarize("Mean Yearly Claim Count" = mean(Count),                            
            "Yearly Claim Count Variance" = var(Count),
            "Mean Yearly Aggregate Loss" = mean(AggLoss)) %>% 
  gt()

# Get yearly claim count (estimate for frequency) 
counts <- df %>% 
  group_by(Year) %>% 
  summarize(Count = n()) %>% 
  ungroup()

# QQ plot versus normal
# Upward convex shape confirms heavy tailed data
centeredLosses <- (df$Loss - mean(df$Loss)) / sd(df$Loss)
qqnorm(centeredLosses, pch = 1, frame = FALSE)
qqline(centeredLosses, col = "steelblue", lwd = 2)

# Mean excess plot, 
# Linear upward trend indicates heavy tail behavior
meplot(df$Loss)
  
# Hill estimator plot
# Convergence around under alpha = 1.5
hill(df$Loss)

# ── Distribution Fitting ───────────────────────────────────────────────────────

# Fit tempered stable model via method of moments (cumulant matching)

# Calculate sample cumulants
kappa_1 <- mean(df$Loss) 
kappa_2 <- var(df$Loss) 
kappa_3 <- sum(df$Loss ^ 3) / length(df$Loss) - 3 * mean(df$Loss) * (sum(df$Loss ^ 2) / length(df$Loss)) + 2 * mean(df$Loss) ^ 3

# Solve for parameter estimates
alpha_hat <- 1 - (kappa_2 ^ 2) / (kappa_3 * kappa_1 - kappa_2 ^ 2)
lambda_hat <- kappa_1 * (1 - alpha_hat) / kappa_2
delta_hat <- kappa_1 * lambda_hat ^ (1 - alpha_hat) / gamma(1 - alpha_hat)

# Fit tempered stable model via maximum likelihood estimation
# Estimates from cumulant matching will serve as the starting estimates
fit_TS <- TemperedEstim("TSS","ML",df$Loss,theta0 = c(alpha_hat, delta_hat, lambda_hat))

ts_estim_table <- data.frame(
  Method = c("Cumulant Matching", "Maximum Likelihood Estimation"),
  alpha = c(alpha_hat, as.numeric(fit_TS@par[1])),
  delta = c(delta_hat, as.numeric(fit_TS@par[2])),
  lambda = c(lambda_hat, as.numeric(fit_TS@par[3]))
)

ts_estim_table %>% 
  gt()

# Fit Weibull, Pareto, lognormal via MLE
lnorm_fit <- fitdist(df$Loss, distr = "lnorm")
weibull_fit <- fitdist(df$Loss, distr = "weibull")
pareto_fit <- fitdist(df$Loss, distr = "pareto")


# ── Goodness of Fit Statistics ──────────────────────────────────────────────────

# Tempered stable goodness of fit statistics
# Loglikelihood
ts_loglikelihood <- sum(log(dTSS(df$Loss,alpha = fit_TS@par[1], delta = fit_TS@par[2], lambda = fit_TS@par[3])))

# Akaike information criterion
ts_aic <- 2*3 - 2 * sum(log(dTSS(df$Loss,alpha = fit_TS@par[1], delta = fit_TS@par[2], lambda = fit_TS@par[3])))

# Bayesian information criterion
ts_bic <- 3 * log(length(df$Loss)) - 2 * sum(log(dTSS(df$Loss,alpha = fit_TS@par[1], delta = fit_TS@par[2], lambda = fit_TS@par[3])))


# ── CDF Plot ────────────────────────────────────────────────────────────────────

# Tempered stable CDF/survival function is calculated empirically via Monte Carlo simulation, this is much faster than numerical inversion of the characteristic function
TS_Loss <- rTSS(20000, alpha = fit_TS@par['alpha'], delta = fit_TS@par['delta'], lambda = fit_TS@par['lambda'], method = "AR")

# Generate plot
plot(ecdf(df$Loss), col = "black" , main = "Cumulative Distribution Function", xlim = c(0,10))
plot(ecdf(TS_Loss), col = "red", add = TRUE)
curve(ppareto(x, shape = pareto_fit$estimate[1], scale = pareto_fit$estimate[2]), add = TRUE, col = "green")
curve(pweibull(x, shape = weibull_fit$estimate[1], scale = weibull_fit$estimate[2]), add = TRUE, col = "orange")
curve(plnorm(x, meanlog = lnorm_fit$estimate[1], sdlog = lnorm_fit$estimate[2]), add = TRUE, col = "blue")
legend("bottomright", legend = c("Actual Losses", "Tempered Stable", "Pareto", "Lognormal", "Weibull"), 
       col = c("black", "red", "green", "blue", "orange"), lty = c(1, 1, 1, 1, 1), lwd = 2)


# ── Log-Log Survival Plot ───────────────────────────────────────────────────

# Generate state space
t <- seq(min(df$Loss), max(df$Loss), length.out = 10000)

# Calculate survival functions on state space
S_ln <- 1-plnorm(t, meanlog = lnorm_fit$estimate[1], sdlog = lnorm_fit$estimate[2])
S_pareto <- 1-ppareto(t, shape = pareto_fit$estimate['shape'], scale = pareto_fit$estimate['scale'])
S_weibull <- 1-pweibull(t, shape = weibull_fit$estimate['shape'], scale = weibull_fit$estimate['scale'])

# Calculate actual empirical and tempered stable survival functions
S_emp <- numeric(10000)
S_ts <- numeric(10000)
for(i in 1:10000) {
  S_emp[i] <- sum(df$Loss > t[i]) / length(df$Loss)
  S_ts[i] <- sum(TS_Loss > t[i]) / 20000
}

# Generate plot
plot(log(t), log(S_emp),
     pch = 16, cex = 0.5, col = "black",
     xlab = "log(Loss)", ylab = "log(S(x))",
     xlim = c(0, 5),
     main = "Log-Log Survival Function",
     type = 'l')
lines(log(t), log(S_ln), col = "blue", lwd = 1, lty = 1)
lines(log(t), log(S_ts), col = "red", lwd = 1, lty = 1)
lines(log(t), log(S_pareto), col = "green", lwd = 1, lty = 1)
lines(log(t), log(S_weibull), col = "orange", lwd = 1, lty = 1)
legend("topright", legend = c("Actual Losses", "Tempered Stable", "Pareto", "Lognormal", "Weibull"), 
       col = c("black", "red", "green", "blue", "orange"), lty = c(1, 1, 1, 1, 1), lwd = 2)


# ── Two-sample KS and AD Tests ────────────────────────────────────────────────

# Generate samples from fitted distributions
sim_loss_ts <- rTSS(length(df$Loss), alpha = fit_TS@par[1], delta = fit_TS@par[2], lambda = fit_TS@par[3], method = "AR")
sim_loss_pareto <- rpareto(length(df$Loss), shape = pareto_fit$estimate[1], scale = pareto_fit$estimate[2])
sim_loss_weibull <- rweibull(length(df$Loss), shape = weibull_fit$estimate[1], scale = weibull_fit$estimate[2])
sim_loss_lognormal <- rlnorm(length(df$Loss), meanlog = lnorm_fit$estimate[1], sdlog = lnorm_fit$estimate[2])

# Kolmogorov-Smirnov tests
KS_ts <- ks.test(df$Loss, sim_loss_ts)
KS_pareto <- ks.test(df$Loss, sim_loss_pareto)
KS_weibull <- ks.test(df$Loss, sim_loss_weibull)
KS_lognormal <- ks.test(df$Loss, sim_loss_lognormal)

# Anderson-Darling tests
AD_ts <- ad_test(df$Loss, sim_loss_ts)
AD_pareto <- ad_test(df$Loss, sim_loss_pareto)
AD_weibull <- ad_test(df$Loss, sim_loss_weibull)
AD_lognormal <- ad_test(df$Loss, sim_loss_lognormal)


# ── Aggregate Loss Simulation: Poisson Frequency ─────────────────────────────

# Poisson model for claim frequency
count_fit <- fitdist(counts$Count, distr = "pois")
model_freq <- expression(data = rpois(lambda = as.numeric(count_fit$estimate[1])))

# Define severity models
pareto_model_sev <- expression(data = rpareto(shape = as.numeric(pareto_fit$estimate[1]), scale = as.numeric(pareto_fit$estimate[2])))
weibull_model_sev <- expression(data = rweibull(shape = weibull_fit$estimate[1], scale = weibull_fit$estimate[2]))
lognormal_model_sev <- expression(data = rlnorm(meanlog = lnorm_fit$estimate[1], sdlog = lnorm_fit$estimate[2]))
ts_model_sev <- expression(data = rTSS(alpha = as.numeric(fit_TS@par[1]), delta = as.numeric(fit_TS@par[2]), lambda = as.numeric(fit_TS@par[3]), method = "AR"))

# Simulate aggregate losses
Fs_pareto <- aggregateDist(method = "simulation", nb.simul = 10000, model_freq, pareto_model_sev)
Fs_weibull <- aggregateDist(method = "simulation", nb.simul = 10000, model_freq, weibull_model_sev)
Fs_lognormal <- aggregateDist(method = "simulation", nb.simul = 10000, model_freq, lognormal_model_sev)
Fs_ts <- aggregateDist("simulation", nb.simul = 1000, model_freq, ts_model_sev)


# ── Summary Tables ──────────────────────────────────────────────────────────

# Goodness of fit statistics
gof_table <- data.frame(
  Statistic = c("Kolmogorov-Smirnov", "Anderson-Darling", "Akaike Information Criterion", "Bayesian Information Criterion", "Negative Loglikelihood"),
  Weibull = c(KS_weibull$statistic, AD_weibull[1], weibull_fit$aic, weibull_fit$bic, -weibull_fit$loglik),
  Lognormal = c(KS_lognormal$statistic, AD_lognormal[1], lnorm_fit$aic, lnorm_fit$bic, -lnorm_fit$loglik),
  Pareto = c(KS_pareto$statistic, AD_pareto[1], pareto_fit$aic, pareto_fit$bic, -pareto_fit$loglik),
  TemperedStable = c(KS_ts$statistic, AD_ts[1], ts_aic, ts_bic, -ts_loglikelihood)
) 

# Two-sample test p-values
pval_table <- data.frame(
  Pval = c("Kolmogorov-Smirnov", "Anderson-Darling"),
  Weibull = c(KS_weibull$p.value, AD_weibull[2]),
  Lognormal = c(KS_lognormal$p.value, AD_lognormal[2]),
  Pareto = c(KS_pareto$p.value, AD_pareto[2]),
  TemperedStable = c(KS_ts$p.value, AD_ts[2])
)

# Mean aggregate loss, Poisson frequency
agg_table <- data.frame(
  SeverityModel = c("Weibull", "Lognormal", "Pareto", "Tempered Stable"),
  MeanAggLoss = c(mean(Fs_weibull), mean(Fs_lognormal), mean(Fs_pareto), mean(Fs_ts))
)

# Tail value at risk, Poisson frequency
tvar_table <- data.frame(
  TVaR = c("90%", "95%", "99%"),
  Weibull = c(CTE(Fs_weibull)[1], CTE(Fs_weibull)[2], CTE(Fs_weibull)[3]),
  Lognormal = c(CTE(Fs_lognormal)[1], CTE(Fs_lognormal)[2], CTE(Fs_lognormal)[3]),
  Pareto = c(CTE(Fs_pareto)[1], CTE(Fs_pareto)[2], CTE(Fs_pareto)[3]),
  TemperedStable = c(CTE(Fs_ts)[1], CTE(Fs_ts)[2], CTE(Fs_ts)[3])
)


# ── Render Tables ──────────────────────────────────────────────────────────

# Goodness of fit statistics
gof_table %>% 
  gt() %>% 
  fmt_number(columns = everything(), rows = c(2,3,4,5), decimals = 2, use_seps = TRUE) %>%
  cols_label(TemperedStable = "Tempered Stable") %>%
  cols_align(align = "center", columns = everything()) %>%
  tab_style(style = cell_text(weight = "bold"), locations = cells_column_labels(everything())) %>% 
  tab_style(
    style = cell_fill(color = "white"),  
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  ) %>%
  tab_style(
    style = "padding-right: 40px;",
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  )

# Two-sample test p-values
pval_table %>% 
  gt() %>% 
  cols_label(Pval = "P-value", TemperedStable = "Tempered Stable") %>%
  cols_align(align = "center", columns = everything()) %>% 
  tab_style(style = cell_text(weight = "bold"), locations = cells_column_labels(everything())) %>% 
  tab_style(
    style = cell_fill(color = "white"),  
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  ) %>%
  tab_style(
    style = "padding-right: 40px;",
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  ) 

# Mean aggregate loss
agg_table %>% 
  gt() %>% 
  cols_label(SeverityModel = "Severity Model", MeanAggLoss = "Mean Aggregate Loss") %>%
  cols_align(align = "center", columns = everything()) %>% 
  tab_style(style = cell_text(weight = "bold"), locations = cells_column_labels(everything())) %>% 
  tab_style(
    style = cell_fill(color = "white"),  
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  ) %>%
  tab_style(
    style = "padding-right: 40px;",
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  )

# Tail value at risk
tvar_table %>% 
  gt() %>% 
  cols_label(TemperedStable = "Tempered Stable") %>% 
  cols_align(align = "center", columns = everything()) %>% 
  tab_style(style = cell_text(weight = "bold"), locations = cells_column_labels(everything())) %>% 
  tab_style(
    style = cell_fill(color = "white"),
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  ) %>%
  tab_style(
    style = "padding-right: 40px;",
    locations = list(
      cells_body(columns = 1),
      cells_column_labels(columns = 1)
    )
  )

# =============================================================================

