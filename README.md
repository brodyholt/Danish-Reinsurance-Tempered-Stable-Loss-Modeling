# Tempered Stable Distributions for Actuarial Loss Modeling

> A comparative feasibility study — Danish Fire Reinsurance Dataset · Preliminary Analysis

![Language](https://img.shields.io/badge/language-R-276DC3)
![Dataset](https://img.shields.io/badge/dataset-CAS%20Danish%20Fire-gray)
![Status](https://img.shields.io/badge/status-preliminary-yellow)
![Best Fit](https://img.shields.io/badge/best%20fit-Tempered%20Stable-2d6a4a)

---

## Contents

1. [Motivation](#1-motivation)
2. [Actuarially Relevant Results](#2-actuarially-relevant-results)
3. [Limitations](#3-limitations)
4. [Future Directions](#4-future-directions)

---

## 1. Motivation


---

## 2. Results


### Parameter Estimation


| Parameter | Description | MoM Estimate | MLE Estimate |
|:---|:---|---:|---:|
| `α` | Stability index | 0.840 | 0.830 |
| `δ` | Scale | 0.262 | 0.266 |
| `λ` | Tempering | 0.00724 | 0.00727 |



### Goodness-of-Fit Comparison

| Statistic | Weibull | Lognormal | Pareto | **Tempered Stable** |
|:---|---:|---:|---:|---:|
| Kolmogorov–Smirnov | 0.2560 | 0.1396 | 0.3110 | **0.0559** |
| Anderson–Darling | 959,452.90 | 406,183.90 | 1,205,179.19 | **52,052.02** |
| AIC | 9,251.95 | 7,968.26 | 9,137.61 | **6,793.84** |
| BIC | 9,263.31 | 7,979.62 | 9,148.97 | **6,810.88** |
| Negative Log-Likelihood | 4,623.98 | 3,982.13 | 4,566.80 | **3,393.92** |


### Aggregate Loss Simulation — TVaR (millions DKK)

| Confidence | Weibull | Lognormal | Pareto | **Tempered Stable** |
|:---|---:|---:|---:|---:|
| 90% | 811.00 | 713.01 | 800.08 | **866.70** |
| 95% | 847.54 | 745.11 | 837.58 | **922.87** |
| 99% | 922.25 | 808.47 | 913.08 | **1,051.23** |



---

## 3. Limitations



---

## 4. Future Directions


---

## References

- Massing, T. (2024). *Parametric Estimation of Tempered Stable Laws*. arXiv:2303.07060v4 \[math.ST\]. University of Duisburg-Essen. https://arxiv.org/abs/2303.07060
- Rosinski, J. (2007). Tempering stable processes. *Stochastic Processes and their Applications*, 117(6), 677–707.
- Küchler, U. and Tappe, S. (2013). Tempered stable distributions and processes. *Stochastic Processes and their Applications*, 123(12), 4256–4293.



---

