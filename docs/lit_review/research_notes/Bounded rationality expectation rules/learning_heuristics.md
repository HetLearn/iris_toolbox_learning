# Learning and heuristic-switching expectation models beyond a two-type RE vs AR(1)-learner setup

Scope: heuristic-switching models (HSMs) with more than two types, behavioral learning equilibria (BLE) and SAC learning, endogenous gains and anchoring, small forecasting models in Smets-Wouters (2007), experience-based learning, restricted perceptions and consistent-expectations equilibria, mean-only learning, and how each could enter the hetlearn toolbox (MATLAB/IRIS; today one RE type and one BR type, Brock-Hommes switching, re-solve each quarter, time-varying Kalman filter likelihood).

Notes on sourcing. Most numbers below were read from the full text of working-paper or author-hosted versions (PDFs downloaded and text-extracted in this session). Where the published version may differ, the bullet says so. Formulas are transcribed from the extracted text; where the PDF extraction garbled sub/superscripts, the bullet flags the reconstruction. Notation is kept close to each source, so the same Greek letter means different things in different bullets (for example β is the intensity of choice in Anufriev-Hommes and a bias parameter in Jang-Sacht).

Corrections to the brief, found while checking citations:
- Hommes, Mavromatis, Özden and Zhu (2023) is in *Quantitative Economics* 14(4), 1401-1445, not the *Journal of Applied Econometrics* — [QE](https://doi.org/10.3982/QE1533).
- Hommes and Lustenhouwer (2019) on endogenous credibility is in the *Journal of Monetary Economics* 107, 48-62, not JEDC — [UvA accepted PDF](https://pure.uva.nl/ws/files/44671470/1_s2.0_S0304393219300170_main.pdf).
- Milani (2014) is "Learning and time-varying macroeconomic volatility", *JEDC* 47, 94-114, not JME — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).
- Gáti (2023) is in *JME* 140 (Supplement), S37-S47 — [IDEAS](https://ideas.repec.org/a/eee/moneco/v140y2023isps37-s47.html). The reference list of Kostyshyna-Özden-Zhang (2024) gives "JME 114, 592-621" for it, which conflicts with RePEc — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).
- "Elias" is Christopher J. Elias (*Macroeconomic Dynamics* 2022; *Journal of Macroeconomics* 2022) — [IDEAS](https://ideas.repec.org/a/cup/macdyn/v26y2022i4p920-944_3.html); [EMU Commons](https://commons.emich.edu/fac_sch2022/42).
- Kostyshyna-Özden-Zhang (2024) estimate only the RE baseline (Bayesian, Canadian data) and calibrate the learning and switching block — [KOZ](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).
- I could not find any Özden-Wouters paper (three searches). See Gaps under Question 2.

---

## 1. Heuristic-switching models with more than two types: formulas, switching rules, and which were estimated

### Takeaway
The Brock-Hommes discrete-choice machinery extends directly to K types. The canonical K = 4 case is Anufriev-Hommes (2012): adaptive, weak trend, strong trend, and learning anchoring-and-adjustment, with memory η = 0.7, intensity β = 0.4 and inertia δ = 0.9. It is calibrated to laboratory data, not estimated on macro data. The macro HSMs that have been estimated are almost all two-type: Cornea-Madeira, Hommes and Massaro (2019) by NLS on a US Phillips curve (intensity of choice 5.04, mean fundamentalist share 0.35); Jang-Sacht (2016) by SMM on euro-area data with the intensity fixed on a grid; Kostyshyna-Özden-Zhang (2024) on Canadian data, with structural parameters from a Bayesian RE estimation and the switching parameters calibrated. The exception is Elias (2022), a Bayesian-estimated three-type adaptive-learning NK model on US data. I found no Bayesian estimation of an N > 2 switching model inside a medium-scale DSGE.

### Cited Findings

#### Brock-Hommes (1997) and the generic discrete-choice rule
- Brock, W.A. and Hommes, C.H. (1997), "A rational route to randomness", *Econometrica* 65(5), 1059-1095; companion Brock and Hommes (1998), "Heterogeneous beliefs and routes to chaos in a simple asset pricing model", *JEDC* 22, 1235-1274. — [Anufriev-Hommes (2012, KER) reference list](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf). The same 1059-1095 range is in the [Kostyshyna-Özden-Zhang (2024) reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf); the Branch (2004) and Branch-McGough (2009, 2010) reference lists print "1059-1160", which looks like a typo in those lists — [Branch (2004)](https://sites.socsci.uci.edu/~wbranch/Templates/EJ2004July.pdf); [Branch-McGough (2009)](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2009_heteronk.pdf).
- BH (1997) is a cobweb model with costly rational versus naive predictors; predictor switching can become complicated when the intensity of choice is high — [Branch (2004, EJ)](https://sites.socsci.uci.edu/~wbranch/Templates/EJ2004July.pdf). For large but finite intensity, complex dynamics come from the tension between repelling and attracting forces once predictor choice is coupled with price dynamics — [Branch-McGough (2010)](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf).
- Generic I-type rule: fractions n_{i,t} follow a multinomial logit in the realized fitness U_{i,t-1}, with intensity of choice β ≥ 0. β = 0 gives constant equal fractions 1/I; β = ∞ is the "neoclassical" limit where everyone uses the best predictor — [Cornea-Madeira, Hommes, Massaro (2019), accepted manuscript](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf).
- A constant C_j in the fitness can be read as the cost of predictor j or, following Branch (2004), as a predisposition effect. Branch-McGough set the adaptive predictor's cost to 0, so C is the relative cost of rationality — [Branch-McGough (2010)](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf).
- A many-type extension was circulated as Brock, Hommes and Wagener (2001), "Evolutionary dynamics in financial markets with many trader types", CeNDEF WP 01-01 (working paper) — [Branch (2004) reference list](https://sites.socsci.uci.edu/~wbranch/Templates/EJ2004July.pdf).

#### Anufriev and Hommes (2012): four heuristics
- Bibliographic: Anufriev, M. and Hommes, C. (2012), "Evolutionary selection of individual expectations and aggregate outcomes in asset pricing experiments", *AEJ: Microeconomics* 4(4), 35-64 — [IDEAS](https://ideas.repec.org/a/aea/aejmic/v4y2012i4p35-64.html). Companion with the same four-heuristic model: "Evolution of market heuristics", *Knowledge Engineering Review* (2012), DOI 10.1017/S0269888912000161 — [KER PDF](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf).
- Timing: the forecast of p_{t+1} is submitted before p_t is known, so the last observed price is p_{t-1}, while the agent's own last forecast p^e_t is known — [KER PDF](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf).
- Heuristics (KER eqs. 4-8) — [KER PDF](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf):
  - ADA (adaptive): `p^e_{t+1,1} = 0.65 p_{t-1} + 0.35 p^e_{t,1}`
  - WTR (weak trend): `p^e_{t+1,2} = p_{t-1} + 0.4 (p_{t-1} - p_{t-2})`
  - STR (strong trend): `p^e_{t+1,3} = p_{t-1} + 1.3 (p_{t-1} - p_{t-2})`
  - LAA (learning anchoring and adjustment): `p^e_{t+1,4} = 0.5 (p^av_{t-1} + p_{t-1}) + (p_{t-1} - p_{t-2})`, with p^av_{t-1} the sample average of all past prices. It comes from the AA rule `0.5 (p^f + p_{t-1}) + (p_{t-1} - p_{t-2})`, with the unknown fundamental p^f replaced by the sample mean. Some subjects' estimated individual rules were AR(2) rules close to AA.
- Performance and switching (KER eqs. 9-10): `U_{t,h} = -(p_t - p^e_{t,h})^2 + η U_{t-1,h}` and `n_{t,h} = δ n_{t-1,h} + (1-δ) exp(β U_{t-1,h}) / Z_{t-1}`, where Z_{t-1} = Σ_h exp(β U_{t-1,h}). δ is inertia (the fraction who keep last period's rule, i.e. asynchronous updating) and η is memory — [KER PDF](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf).
- Benchmark parameters: β = 0.4, η = 0.7, δ = 0.9, held fixed across groups. Simulations differ only in the initial prices and initial shares, and no fitting exercise was performed (path dependence reproduces convergence, persistent oscillation and dampened oscillation) — [KER PDF](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf).
- Lab context: in the Hommes et al. (2005) learning-to-forecast asset market (p^f = 60, r = 0.05, mean dividend 3), subjects used simple linear rules (naive, ADA, two-lag trend extrapolation) — [KER PDF](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf).

#### Hommes (2011, JEDC) and Hommes (2021, JEL)
- Hommes, C. (2011), "The heterogeneous expectations hypothesis: Some evidence from the lab", *JEDC* 35(1), 1-24, DOI 10.1016/j.jedc.2010.10.003 (earlier CeNDEF WP 10-06). It reviews learning-to-forecast experiments in which the realized price is the aggregate outcome of everyone's forecasts — [UvA DARE record](https://dare.uva.nl/id/e0a317cc-ae68-4c57-a1db-904ff8043d51).
- Hommes, C. (2021), "Behavioral and experimental macroeconomics and policy analysis: A complex systems approach", *Journal of Economic Literature* 59(1), 149-219 — [HMOZ (BoC SWP 2022-42) reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf). HMOZ cite it as a survey of laboratory evidence for simple heuristics such as AR(1) rules — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- NK macro experiment with switching: Assenza, Heemeijer, Hommes and Massaro (2021), "Managing self-organization of expectations through monetary policy: A macro experiment", *JME* 117, 170-186 — [HMOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### De Grauwe: optimists/pessimists and targeters/extrapolators
- De Grauwe, P. (2011), "Animal spirits and monetary policy", *Economic Theory* 47(2-3), 423-457, DOI 10.1007/s00199-010-0543-0. Agents use biased heuristics and learn from errors; correlated biased beliefs produce endogenous waves of optimism and pessimism, and strict inflation targeting is found to be suboptimal — [LSE eprints](https://eprints.lse.ac.uk/45124). Earlier as CESifo WP 2418 (2008) — [CESifo](https://www.cesifo.org/en/publications/2008/working-paper/animal-spirits-and-monetary-policy).
- A variant with other heuristics is in De Grauwe (2012), *Lectures on Behavioral Macroeconomics* (Princeton UP) — [Jang-Sacht (2016) footnote 4](https://www.econ.nagoya-cu.ac.jp/wp-content/uploads/2015/01/Jang_Sacht_Animal_Spirits.pdf).
- Formulas as implemented by Jang-Sacht (2016), eqs. 6-18 — [Jang-Sacht PDF](https://www.econ.nagoya-cu.ac.jp/wp-content/uploads/2015/01/Jang_Sacht_Animal_Spirits.pdf):
  - Output gap: optimists `E^O_t y_{t+1} = d_t`, pessimists `E^P_t y_{t+1} = -d_t`, with `d_t = 0.5 [β + δ λ_{y,t}]` ("divergence in beliefs"; β is a bias, λ_{y,t} the unconditional standard deviation of the output gap). Market forecast `(α^O_t - α^P_t) d_t`.
  - Fitness `U^k_t = ρ U^k_{t-1} - (1-ρ)(E^k_{t-1} y_t - y_t)^2`; shares are a two-type logit with intensity γ.
  - Inflation: targeters `E^tar_t π_{t+1} = π̄` (the announced target, 0 in gap form) and extrapolators `E^ext_t π_{t+1} = π_{t-1}`, with the same memory ρ and intensity γ as for output.

#### Branch and McGough (2009, 2010)
- Branch, W.A. and McGough, B. (2009), "A New Keynesian model with heterogeneous expectations", *JEDC* 33, 1036-1051 — [author-hosted PDF](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2009_heteronk.pdf). They use axioms A1-A7 on the expectations operators so that the log-linear IS and AS curves depend on a convex combination `Ê = α E^1 + (1-α) E^2`. A7, which concerns agents agreeing on limiting wealth distributions, is what allows aggregation; without it, adding heterogeneous expectations "requires considerably more than replacing the rational expectations operator with a convex sum" — [BM 2009](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2009_heteronk.pdf).
- BM 2009 result: with a share of rational and a share of adaptive agents, the effect on indeterminacy "depends critically on how the adaptive predictor weighs past data". Discounting past data can be stabilizing; placing greater weight on past data can produce indeterminacy under rules that are determinate under RE — [BM 2009](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2009_heteronk.pdf).
- Branch, W.A. and McGough, B. (2010), "Dynamic predictor selection in a New Keynesian model with heterogeneous expectations", *JEDC* 34, 1492-1508 — [IDEAS](https://ideas.repec.org/a/eee/dyncon/v34y2010i8p1492-1508.html). Predictors: type 1 "rational" (perfect foresight for one-step forecasts) at cost C; type 2 adaptive, `E^2_t x_{t+1} = θ_x^2 x_{t-1}`, derived from the PLM `x_t = θ_x x_{t-1}`. Aggregate `Ê_t x_{t+1} = n^x_t x_{t+1} + (1 - n^x_t) θ_x^2 x_{t-1}`, with separate shares for output and inflation; the law of motion uses n_{t-1}, and agents ignore the future evolution of shares (Euler-equation behavior) — [BM 2010 PDF](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf).
- BM 2010 result: low C keeps the steady state stable; higher C can destabilize it and produce bifurcations, periodic orbits and complex dynamics, even under a Taylor-principle rule that is determinate under RE — [IDEAS abstract](https://ideas.repec.org/a/eee/dyncon/v34y2010i8p1492-1508.html). In Branch and Evans (2006), heterogeneity survives even as the intensity of choice goes to infinity — [BM 2010 footnote 8](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf).

#### Massaro (2013): infinite-horizon heterogeneous expectations
- Massaro, D. (2013), "Heterogeneous expectations in monetary DSGE models", *JEDC* 37(3), 680-692, DOI 10.1016/j.jedc.2012.11.001. Micro-founded NK model with some boundedly rational agents (who revise beliefs as data arrive) and some RE agents; the reduced form nests the RE representative-agent model; determinacy under different rules is studied — [UvA DARE](https://dare.uva.nl/id/b47af7f2-7195-4f4e-ac43-a5f34639b52b).
- A secondary source contrasts it with Branch-McGough (2009): in Massaro, aggregate dynamics depend on long-horizon (infinite-horizon) forecasts, not one-period Euler-equation forecasts — [Dynare WP 54](https://www.dynare.org/wp-repo/dynarewp054.pdf).

#### Cornea-Madeira, Hommes and Massaro (2019): estimated switching for US inflation
- *JBES* 37(2), 288-300, DOI 10.1080/07350015.2017.1321548 — [IDEAS](https://ideas.repec.org/a/taf/jnlbes/v37y2019i2p288-300.html).
- Model: `π_t = δ (n_{f,t} E^f_t π_{t+1} + (1 - n_{f,t}) E^n_t π_{t+1}) + γ mc_t + u_t`. Fundamentalists forecast the present value of expected real marginal costs from a VAR(4) in the labor share and output gap, re-estimated recursively (no look-ahead; initialized with data from 1947Q2). Naive agents use `E^n_t π_{t+1} = π_{t-1}`. Fitness is the average squared error over K = 4 quarters; δ = 0.99 fixed; estimation by NLS — [CHM accepted manuscript](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf).
- Estimates (Table 1): intensity of choice β = 5.040 (s.e. 1.641), γ = 0.001 (s.e. 0.0002), R² = 0.82. Fundamentalist share n_f: mean 0.353, median 0.276, max 0.924, min 0.019, first-order autocorrelation 0.887 — [CHM](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf).
- On average about 65% of firms are naive. n_f falls almost to 0 after the 1973 oil shock; fundamentalists dominate the late 1980s and early 1990s; the naive share rises over 1992-2004; n_f peaks near 0.9 after 2007/08 — [CHM](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf).
- Model selection (Table 3): BIC -1690 for the switching model, against -1681 (fixed estimated weights), -1584 (all fundamentalist), -1394 (all naive) and -1675 (β = 0, n_f = 0.5). Non-nested P-tests do not reject the switching model against any alternative and reject each alternative against it. An appendix also beats representative-agent constant-gain models — [CHM](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf).
- The authors warn that the magnitude of β "is more difficult to interpret as it is conditional on the functional form of the performance measure" (footnote 15). The abstract says the switching model is estimated "using aggregate and survey data" (SPF forecasts used as evidence of heterogeneity) — [CHM](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf).

#### Hommes and Lustenhouwer (2019): fundamentalists who believe the target
- *JME* 107, 48-62, DOI 10.1016/j.jmoneco.2019.01.027 — [UvA accepted PDF](https://pure.uva.nl/ws/files/44671470/1_s2.0_S0304393219300170_main.pdf); earlier BoC SWP 2019-9 (working paper) — [BoC](https://www.bankofcanada.ca/wp-content/uploads/2019/02/swp2019-9.pdf).
- Heuristics: fundamentalists ("trust the central bank") expect inflation and the output gap to equal the targets; naive agents use the last observation. The fundamentalist share is interpreted as central bank credibility — [HL JME](https://pure.uva.nl/ws/files/44671470/1_s2.0_S0304393219300170_main.pdf).
- Results: the region of admissible policy parameters is strictly larger than under RE. With the ZLB, self-fulfilling deflationary spirals can occur depending on credibility; a high inflation target and aggressive easing prevent them — [HL JME](https://pure.uva.nl/ws/files/44671470/1_s2.0_S0304393219300170_main.pdf).
- HL summarize Branch (2004, 2007) as fitting switching models (including naive and VAR-type heuristics) to Michigan survey data, with clear evidence of performance-based switching — [HL JME](https://pure.uva.nl/ws/files/44671470/1_s2.0_S0304393219300170_main.pdf).
- Follow-up: Goy, Hommes and Mavromatis (2022), "Forward guidance and the role of central bank credibility under heterogeneous beliefs", *JEBO* 200, 1240-1274 — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).

#### Jang and Sacht
- Jang, T.-S. and Sacht, S. (2016), "Animal spirits and the business cycle: Empirical evidence from moment matching", *Metroeconomica* 67(1), 76-113 — [IfW Kiel record](https://www.ifw-kiel.de/publications/animal-spirits-and-the-business-cycle-empirical-evidence-from-moment-matching-23481).
- SMM on **euro-area** data, 1975Q1-2009Q4; hybrid NK with De Grauwe heuristics; target moments are auto- and cross-covariances of the output, inflation and interest-rate gaps (lags up to two years). The intensity of choice is **not estimated**: it is varied over γ ∈ {0.1, 1, 10, 100}, while the bias β and divergence δ are estimated. J-test degrees of freedom are 66 (BR) versus 68 (RE) — [Jang-Sacht PDF](https://www.econ.nagoya-cu.ac.jp/wp-content/uploads/2015/01/Jang_Sacht_Animal_Spirits.pdf).
- Later working paper: "Macroeconomic dynamics under bounded rationality: On the impact of consumers' forecast heuristics", Kiel Economics WP 2018-10 (working paper) — [IDEAS](https://ideas.repec.org/p/zbw/cauewp/201810.html).

#### Elias: Bayesian-estimated three-type learning models
- Elias, C.J. (2022), "Bayesian estimation of a small-scale New Keynesian model with heterogeneous expectations", *Macroeconomic Dynamics* 26(4), 920-944, DOI 10.1017/S1365100520000401. Euler-equation adaptive learning; type A agents use a correctly specified model, types B and C misspecified ones. Quarterly US data from the pre-Great Moderation and Great Moderation periods are used to jointly estimate the degree of heterogeneity, the learning parameters and the deep parameters; the HE model fits better than homogeneous learning — [IDEAS abstract](https://ideas.repec.org/a/cup/macdyn/v26y2022i4p920-944_3.html).
- Medium-scale version: "Adaptive learning with heterogeneous expectations in an estimated medium-scale New Keynesian model", *Journal of Macroeconomics* (2022) — [EMU Commons](https://commons.emich.edu/fac_sch2022/42). Recession forecasting with these models: *Applied Economics Letters* 30(9), 1218-1221 (2023) — [IDEAS](https://ideas.repec.org/a/taf/apeclt/v30y2023i9p1218-1221.html).

#### Kostyshyna, Özden and Zhang (2024): estimated RE/AR(1) switching in a medium-scale DSGE (Canada)
- Bank of Canada SWP 2024-14 (working paper), "Endogenous credibility and wage-price spirals", last updated May 14, 2024 — [BoC PDF](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). Formulas are under Question 3.
- Estimation design: the baseline **RE** model is estimated with standard Bayesian likelihood methods (SW07 priors) on seven Canadian observables (real GDP, consumption and business-investment growth, core inflation, the nominal rate, nominal wage growth, hours). The learning and switching parameters are **calibrated**: memory ω = 0.62, intensity χ = 0.51 and initial gain γ_0 = 0.059 from Özden (the text cites "Ozden (2024)", the calibration table "Ozden, 2023"), and the step size μ = 0.001 from Kostyshyna (2012). The learning model is then validated by pseudo in-sample forecasts (up to eight quarters ahead, from 1976Q2), comparing RMSEs against RE for inflation, wage growth and Business Outlook Survey inflation and wage expectations — [KOZ, Section 4 and Table 1](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).

### Inferences
- Estimated so far, by method and data: CHM (NLS, single-equation US NKPC, two types); Branch (2004) (ML discrete choice on Michigan microdata, three predictors); Jang-Sacht (SMM, euro area, two types per variable, intensity on a grid); Elias (2022) (Bayesian, US, three learning types, apparently fixed shares); KOZ (2024) (RE baseline estimated by Bayesian methods on Canadian data, learning and switching block calibrated and then judged by forecast RMSE); HMOZ (Bayesian SW07, but BLE rather than switching). AH (2012) is calibrated to the lab.
- Intensity-of-choice values cannot be compared across papers: CHM's 5.04 uses a four-quarter average squared error, with inflation apparently in decimals (Figure 1 is on a 0.01 scale), KOZ's 0.51 uses an exponentially weighted error, and AH's 0.4 uses an unnormalized discounted sum `U_t = -e_t^2 + η U_{t-1}`, which is 1/(1-η) times larger than a (1-η)-weighted average. hetlearn should fix one fitness normalization (for example the (1-η)-weighted mean of squared errors in percentage points) and document how to translate the published β values.
- The AH inertia parameter δ is a separate mechanism from memory η. It is cheap to add (one line) and gives share persistence without high memory, which may help identification.
- Several HSM types forecast with fixed rules: naive (random walk), target believer (E = π*), De Grauwe optimist/pessimist (±d_t), extrapolator, weak or strong trend. In hetlearn they would all be one new "fixed-rule BR" class with a few parameters, but most of these models need more than two types or a non-RE second slot (for example HL has fundamentalists plus naive with no RE type).
- Branch-McGough's adaptive predictor `θ^2 x_{t-1}` is exactly hetlearn's "AR(1) without constant, held fixed" with t-1 information, so BM 2010 can be reproduced in the current two-type structure if the RE type can be given a cost or predisposition term in the fitness.

### Gaps
- Assenza et al. (2021): I did not check whether they fit the four-heuristic HSM to the NK experiment, or what the estimates are.
- Massaro (2013): full text not read; the aggregation assumptions and the role of infinite-horizon forecasts are from the abstract and a citing paper.
- Elias (2022): whether shares are fixed (estimated constants) or switch is not stated in the abstract; the estimated shares are not reported here.
- Branch (2004): estimated intensity of choice and costs were not extracted.
- Hommes and Lustenhouwer also have a JEDC (2019) paper on unanchored expectations and liquidity traps (title from memory: "Managing unanchored, heterogeneous expectations and liquidity traps"); not verified.
- Brock-Hommes-Wagener many-type paper: journal version not verified.
- Jang-Sacht's later "horse race" of consumer forecast heuristics (possibly JEBO 2021): not verified; only the 2018 Kiel WP listing was found.

---

## 2. Behavioral learning equilibria and SAC learning: formulas, estimates, and how SAC differs from RLS

### Takeaway
In a BLE, agents use univariate AR(1) rules whose mean and first-order autocorrelation equal those of the realized process. SAC learning updates exactly those two moments recursively (sample mean, sample first-order autocorrelation and sample variance, with gain 1/(t+1) or a constant κ). The autocorrelation stays in [-1, 1] by construction, so no projection facility is needed. In SW07 on US data (1966Q1-2007Q4), BLE beats RE by a log10 Bayes factor of 6.87 and SAC learning by 9.30. BLE alone accounts for about 75% of SAC's gain, and SAC fits best once SPF inflation expectations are added.

### Cited Findings

#### Bibliography
- Hommes, C. and Zhu, M. (2014), "Behavioral learning equilibria", *JET* 150, 778-814. BLE was introduced in a one-dimensional linear stochastic model driven by an exogenous AR(1) — [HMOZ reference list and text](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Hommes, C., Mavromatis, K., Özden, T. and Zhu, M. (2023), "Behavioral learning equilibria in New Keynesian models", *Quantitative Economics* 14(4), 1401-1445, DOI 10.3982/QE1533 — [QE](https://doi.org/10.3982/QE1533). Earlier versions: DNB WP 654 (2019, titled "...in the New Keynesian model") — [DNB](https://www.dnb.nl/en/publications/research-publications/working-paper-2019/behavioral-learning-equilibria-in-the-new-keynesian-model/); BoC SWP 2022-42 — [BoC PDF](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf). Numbers below are from BoC SWP 2022-42.
- SAC learning originates in Hommes and Sorger (1998), *Macroeconomic Dynamics* 2(3), 287-321 — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### SAC formulas (HMOZ eqs. 2.6-2.8)
- Batch form, for observations x_0..x_t: `α_t = (1/(t+1)) Σ_{k=0}^{t} x_k` and `β_t = Σ_{k=0}^{t-1} (x_k - α_t)(x_{k+1} - α_t) / Σ_{k=0}^{t} (x_k - α_t)^2`. Define `R_t = (1/(t+1)) Σ_{k=0}^{t} (x_k - α_t)^2`. Whatever the initial values, β_1 = -1/2 and β_t ∈ [-1, 1] for all t ≥ 1 — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Recursive form (reconstructed from the extracted text of eq. 2.8; check brackets against the paper) — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf):
  - `α_t = α_{t-1} + (1/(t+1)) (x_t - α_{t-1})`
  - `β_t = β_{t-1} + (1/(t+1)) R_t^{-1} [ (x_t - α_{t-1}) ( x_{t-1} + x_0/(t+1) - ((t^2+3t+1)/(t+1)^2) α_{t-1} - x_t/(t+1)^2 ) - (t/(t+1)) β_{t-1} (x_t - α_{t-1})^2 ]`
  - `R_t = R_{t-1} + (1/(t+1)) [ (t/(t+1)) (x_t - α_{t-1})^2 - R_{t-1} ]`
- This is a decreasing-gain algorithm. The constant-gain version replaces 1/(t+1) by a small constant κ (details in the online appendix of Hommes and Zhu 2014) — [HMOZ footnote 9](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- PLM and forecast with t-1 timing (eq. 3.2): `x_t = α_{t-1} + β_{t-1}(x_{t-1} - α_{t-1})` and `E_t x_{t+1} = α_{t-1} + β_{t-1}^2 (x_{t-1} - α_{t-1})`. The ALM under SAC is `x_t = F(α_{t-1} + β_{t-1}^2 (x_{t-1} - α_{t-1}), x_{t-1}, u_t, v_t)` — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- For comparison, constant-gain RLS on an AR(2) PLM (Slobodyan-Wouters 2012a, HMOZ eq. 3.3): `R_t = R_{t-1} + γ (Y_t Y_t' - R_{t-1})` and `θ_t = θ_{t-1} + γ R_t^{-1} Y_t (x_t - θ_{t-1}' Y_t)`, with `Y_t = [1, x_{t-1}, x_{t-2}]'` — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf). The AR(1) RLS used by KOZ (eq. 8) has the same structure with `[1, x_{t-1}]` — [KOZ](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).
- A generalization of SAC learning to other PLMs such as AR(2) is in Branch, Evans and McGough (2014), "Perpetual learning and stability in macroeconomic models", University of Oregon mimeo (unpublished) — [HMOZ footnote 18 and references](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### BLE existence, stability and computation
- In a general linear framework, at least one BLE exists, with mean α* equal to the steady state x*. Proposition 2: a BLE is E-stable under SAC learning if (i) all eigenvalues of `(I - b_1 β*^2 - b_2)^{-1}(b_1 + b_2 - I)` have negative real parts and (ii) all eigenvalues of the Jacobian DG_β(β*) have real parts below 1. In the simple NK model the Taylor principle is sufficient for existence. At standard parameters the unique E-stable BLE is (β*_y, β*_π) = (0.9, 0.9592) — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- The fixed-point iteration HMOZ use to compute a BLE eliminates E-unstable equilibria "without additional computational steps", so a BLE found this way is stable under constant-gain RLS and SAC learning — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### SW07 estimation (US) and results
- Data: quarterly US 1966Q1-2007Q4, the seven SW07 observables with CPI inflation instead of the GDP deflator (to match the SPF); a second exercise adds SPF one-quarter-ahead inflation expectations. Thirteen equations with seven forward-looking variables; 35 estimated parameters including the gain; csminwel mode, then two random-walk MH chains of 500,000 draws (half burned); marginal likelihood by modified harmonic mean (MHM) — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Timing: shocks realize, then expectations are formed from x_{t-1}, u_{t-1} and θ_{t-1}, then states realize, then beliefs update. This "t-1 timing" keeps the model conditionally linear, so the standard Kalman filter evaluates the likelihood. HMOZ apply t-1 timing to both expectations and beliefs; Milani (2005) and Slobodyan-Wouters (2012b) instead combined t-1 beliefs with jointly determined expectations, which HMOZ call a timing inconsistency — [HMOZ, Section 3.1 and footnote 21](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Initial beliefs: regressions on data simulated from the estimated BLE (for SAC and AR(2) learning) or REE (for MSV and VAR(1) learning). The projection facility discards belief updates that imply unstable ALMs, but SAC learning needs none because its coefficients stay in [-1, 1] — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Table 1 (posterior means, seven observables, no survey data), in the order REE / BLE / SAC / pseudo-MSV / VAR(1) / AR(2) — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf):
  - Log-likelihood at the mode: -1069.08 / -1049.35 / -1043.59 / -1055.02 / -1049.40 / -1049.34
  - MHM: -1143.09 / -1127.26 / -1121.66 / -1132.21 / -1122.34 / -1130.82
  - log10 Bayes factor vs REE: 0 / 6.87 / 9.30 / 4.72 / 9.01 / 5.33
  - The "constant gain" row lists 0.006, 0.008, 0.024, 0.008 for the four learning columns (presumably SAC, MSV, VAR(1), AR(2) in that order).
- Parameter shifts relative to REE: capital adjustment cost φ falls from 5.68 (REE) to 2.12 (BLE) and 1.38 (SAC); σ_c falls from 1.3 to 0.5 (BLE); price indexation rises from 0.20 to 0.50 (BLE); wage mark-up persistence falls from 0.84 to 0.30 (BLE), and investment-shock persistence from 0.80 to 0.44 (BLE) — [HMOZ Table 1](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- BLE explains about 75% of the improvement under SAC learning (Bayes factors 6.87 vs 9.30). Pseudo-MSV learning (4.72) falls between the Bayes factors implied by Milani (2007) (2.8) and Slobodyan-Wouters (2012b) (5.1) — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- SAC learning of optimal AR(1) beliefs fits best when short-term survey inflation expectations are included, and optimal Taylor rules need less interest-rate smoothing under BLE than under RE — [QE abstract](https://doi.org/10.3982/QE1533). The smoothing result carries over to SAC learning, while pseudo-MSV learning stays closer to the REE benchmark — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Related equilibrium concepts cited by HMOZ: Lansing (2009, RED 12(2), 304-326) builds a consistent expectations equilibrium in which agents use the optimal Kalman gain within their misspecified class; Lansing and Ma (2017, JIMF 70, 62-87) apply CEE to exchange rates; "natural expectations" (Fuster et al.) underestimate mean reversion by using too-low-order AR models, so a BLE is "the simplest case of natural expectations" — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### Özden-Wouters (requested check) and related Wouters work
- KOZ (2024) cite "Ozden, T., 2024. Heterogeneous Expectations and the Business Cycle at the Effective Lower Bound. Technical Report" and "Ozden (2023)" for the switching calibration — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). This may be an earlier title of Özden (2025, IJCB).
- Wouters' RePEc profile lists a 2023 CERGE-EI working paper (wp766) with Rychalovska and Slobodyan on professional survey forecasts and expectations in DSGE models (working paper; exact title not verified) — [RePEc profile](https://ideas.repec.Org/e/pwo72.html).

### Inferences
- SAC versus RLS on an AR(1) PLM, as an implementer would see it. (i) SAC tracks moments (mean, variance, lag-1 autocovariance) and sets β = autocovariance/variance around the running mean, while RLS regresses x_t on [1, x_{t-1}] and estimates the intercept and slope jointly. Both target the first-order autocorrelation of a stationary process, so their limit points should coincide, but the transition paths differ. (ii) The SAC β is bounded in [-1, 1]; the RLS slope is not, which is why RLS needs a projection facility. (iii) The SAC recursion carries finite-sample correction terms (x_0/(t+1), (t^2+3t+1)/(t+1)^2) that vanish as t grows, so a constant-gain SAC is close to a constant-gain moment tracker. (iv) Under BLE the forecast uses β^2 (two steps ahead with t-1 information), the same as hetlearn's AR(1) PLM under t-1 timing.
- BLE fits hetlearn as a BR type whose AR(1) coefficients are fixed at the fixed point (α*, β*) for each parameter draw. That means solving the fixed point inside every likelihood evaluation, with fixed-point iteration doubling as an E-stability filter, as in HMOZ. Difficulty: medium. SAC learning is a new updating rule for the existing AR(1) PLM (state: α, β, R per variable). Difficulty: easy.
- The HMOZ ranking (SAC ≈ VAR(1) > BLE > AR(2) > MSV > REE) suggests that knowing the mean and persistence of each forecast variable matters more than knowing the cross-equation structure. This supports hetlearn's univariate PLMs as the default BR type.

### Gaps
- No Özden-Wouters paper was found. The brief's "Ozden and Wouters? (check)" may refer to an unpublished or forthcoming manuscript, or may be a confusion with Slobodyan-Wouters or Rychalovska-Slobodyan-Wouters. Ask the user.
- The published QE tables may differ from the BoC WP 2022-42 numbers used here. The survey-data estimation table (with SPF) was not extracted.
- The column assignment of the four "constant gain" values in HMOZ Table 1 is inferred from column order.

---

## 3. Endogenous gains, anchoring and credibility: gain formulas and US estimates

### Takeaway
Four families of endogenous gain exist. (1) Threshold switching between a decreasing gain and a constant gain: Marcet-Nicolini (2003) and Milani (2014), the latter with an estimated US constant gain of 0.082 for inflation. (2) The same switch triggered by a model-consistency criterion: Carvalho-Eusepi-Moench-Preston (CEMP, 2023), unanchored gain 0.145, estimated on inflation and short-term professional forecasts only. (3) A smooth "anchoring function" k_t = g(f_t): Gáti (2023), estimated nonparametrically by SMM on 1981Q3-2020Q1 US data, with gains from 0 to 0.82 that are larger for big and negative surprises. (4) An adaptive step-size "gain on the gain": Kostyshyna (2012), as used in KOZ (2024). Constant-gain estimates on US data cluster around 0.018-0.02.

### Cited Findings

#### Constant-gain benchmarks
- Milani (2007), "Expectations, learning and macroeconomic persistence", *JME* 54(7), 2065-2082 — [HMOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf). Gáti reports Milani's constant gain as 0.0183 — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf); Milani (2011) itself quotes g = 0.0187 for Milani (2007a) — [Milani (2011), author version](https://sites.socsci.uci.edu/~fmilani/ESL.pdf). The two figures conflict slightly.
- Literature range collected by Gáti: consensus constant gains of 0.01-0.05; Branch and Evans (2006) 0.062 for inflation; Erceg and Levin (2003) 0.13 from SPF signal-to-noise ratios; Mertens (2016) time-varying Kalman gains for CPI inflation of 0.1-0.8; Eusepi and Preston (2011) find 0.002 enough to change RBC dynamics — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).

#### Marcet and Nicolini (2003)
- Marcet, A. and Nicolini, J.P. (2003), "Recurrent hyperinflations and learning", *AER* 93, 1476-1498 — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). Agents switch between a constant and a decreasing gain according to a switching criterion — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf); [KOZ](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). On returning to the decreasing gain, agents restart from the previous constant-gain value rather than from t = 1 — [Milani (2014) WP, describing MN](https://sites.socsci.uci.edu/~fmilani/MacroVola_stls2.pdf).

#### Milani (2014): estimated switching gain
- Milani, F. (2014), "Learning and time-varying macroeconomic volatility", *JEDC* 47, 94-114 — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). Formulas and numbers below are from the author-hosted working-paper version — [Milani WP](https://sites.socsci.uci.edu/~fmilani/MacroVola_stls2.pdf).
- RLS with variable-specific gains (eqs. 2.5-2.7): `φ_t = φ_{t-1} + g_{t,y} R_{t-1}^{-1} X_t (Z_t - φ_{t-1}' X_t)'` and `R_t = R_{t-1} + g_{t,y}(X_t X_t' - R_{t-1})`, with
  `g_{t,y} = (g_{t-1,y}^{-1} + 1)^{-1}` if `(1/J) Σ_{j=0}^{J} |y_{t-j} - E_{t-j-1} y_{t-j}| < υ^y_t`, and `g_{t,y} = ḡ_y` otherwise, for y ∈ {π, x, i}.
  The threshold υ^y_t is the mean absolute deviation of historical forecast errors, updated recursively. The PLM is a VAR with t-1 information, `Ê_{t-1} Z_{t+1} = a_{t-1}(I + b_{t-1}) + b_{t-1}^2 Z_{t-1}` — [Milani WP](https://sites.socsci.uci.edu/~fmilani/MacroVola_stls2.pdf).
- Bayesian estimates: the constant gain agents switch to is 0.082 for inflation and 0.073 for output, with a very low gain for the interest rate. With J treated as a parameter (prior mean 12), its posterior mean is 4. Robustness runs give 0.065/0.064, 0.096/0.042 and 0.117/0.058/0.024 (π/x/i). Agents use the high constant gain through most of the 1970s and early 1980s and the decreasing gain later; the implied volatility pattern roughly matches the Great Moderation — [Milani WP](https://sites.socsci.uci.edu/~fmilani/MacroVola_stls2.pdf). Gáti also quotes 0.082 as Milani's maximal gain — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).

#### Carvalho, Eusepi, Moench and Preston (2023)
- "Anchored inflation expectations", *AEJ: Macroeconomics* 15(1), 1-47 — [AEA](https://www.aeaweb.org/doi/10.1257/mac.20200080); [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). Earlier CEPR DP13900 (2019, working paper) — [IDEAS](https://ideas.repec.org/p/cpr/ceprdp/13900.html).
- Long-run inflation expectations are endogenous: they move with short-run surprises, with a sensitivity that depends on recent forecasting performance and on monetary policy. The model is estimated on US (and other countries') postwar data using **only inflation and short-term professional survey forecasts**; it predicts observed long-term expectations out of sample and dates episodes of unanchored expectations — [AEA abstract via search](https://www.aeaweb.org/doi/10.1257/mac.20200080).
- Gain mechanism (as restated in Gáti's Appendix C, with matrix generalizations of CEMP's scalar versions): for a criterion θ_t and threshold θ̃, the gain follows the decreasing-gain recursion if θ_t < θ̃ and equals the constant ḡ otherwise. The extracted text of eq. C.1 reads "(k_{t-1}+1)^{-1}"; with k as the gain this should read `k_t = (k_{t-1}^{-1} + 1)^{-1}`. Baseline criterion: `θ_t = max |Σ^{-1}(φ_{t-1} - [F_{t-1} G_{t-1}])|`, the absolute difference between subjective and model-consistent (ALM) coefficients scaled by the shock covariance. Alternative CUSUM-type criterion: `ω_t = ω_{t-1} + κ̃ k_{t-1}(f_{t|t-1} f_{t|t-1}' - ω_{t-1})` and `θ_t = θ_{t-1} + κ̃ k_{t-1}(f_{t|t-1}' ω_t^{-1} f_{t|t-1} - θ_{t-1})` — [Gáti ECB WP, App. C](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- CEMP's estimate of the unanchored constant gain is ḡ = 0.145 (Gáti cites the 2021 WP vintage) — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf). CEMP combine t-timing of expectations in the learning model with a particle filter to handle the fully nonlinear structure — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### Gáti (2023): smooth anchoring function
- Gáti, L. (2023), "Monetary policy & anchored expectations: An endogenous gain learning model", *JME* 140 (Supplement), S37-S47 — [IDEAS](https://ideas.repec.org/a/eee/moneco/v140y2023isps37-s47.html); ECB WP 2685, July 2022 (working paper) — [ECB](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- PLM (eqs. 15-18): `Ê_t z_{t+1} = a_{t-1} + b_{t-1} s_t`, under anticipated utility, so `Ê_t z_{t+k} = a_{t-1} + b_{t-1} h^{k-1} s_t`; the first element of a is long-run inflation expectations π̄. RLS with gain k_t, which is set by the anchoring function `k_t = g(f_{t|t-1})` (eq. 22), smooth and convex (g_ff ≥ 0, eq. 23), so both large positive and large negative surprises raise the gain. g nests the decreasing gain (t^{-1}) and the constant gain ḡ — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- Assumption 1 (used throughout): only the inflation intercept is learned; slopes are fixed at their RE values and the other intercepts at 0. Updating collapses to `π̄_t = π̄_{t-1} + k_t f_{t|t-1}`, with `f_{t|t-1} = π_t - (π̄_{t-1} + b_1 s_{t-1})` and forecasts `Ê_t π_{t+k} = π̄_{t-1} + b_1^k s_t` (eqs. 26-28) — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- Estimation: with the NK block calibrated (β = 0.98, σ = 1, α = 0.5, κ = 0.0842, ψ_π = 1.5, i.i.d. shocks), g is a piecewise-linear function with 5 knots estimated by SMM on Baxter-King filtered autocovariances at lags 0-4 (80 moments) of CPI inflation, the CBO output gap, the federal funds rate and SPF 12-month-ahead CPI inflation forecasts, quarterly 1981Q3-2020Q1 — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- Estimated knot values: γ̂ = (0.82, 0.61, 0, 0.33, 0.45). A -4 pp inflation surprise gives a gain of 0.82, a downward revision of long-run expectations of about 3.2 pp, against 0.1 pp under a constant gain of 0.05 — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf). The published abstract describes unanchoring as nonlinear and asymmetric, with expectations more sensitive to large or downside surprises — [IDEAS](https://ideas.repec.org/a/eee/moneco/v140y2023isps37-s47.html).
- Policy: optimal policy moves rates aggressively when expectations unanchor and accommodates inflation fluctuations when they are anchored — [IDEAS](https://ideas.repec.org/a/eee/moneco/v140y2023isps37-s47.html).

#### Kostyshyna (2012) and Kostyshyna-Özden-Zhang (2024): adaptive step-size gain
- Kostyshyna, O. (2012), "Application of an adaptive step-size algorithm in models of hyperinflation", *Macroeconomic Dynamics* 16, 355-375 — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf). Agents use a Kushner-Yin (2003) algorithm to choose the gain — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- KOZ (2024), BoC SWP 2024-14 (working paper) — [BoC PDF](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf):
  - Types: fundamentalists use the MSV RE solution of the NK model and ignore the adaptive agents, so their expectations stay anchored at target. Adaptive agents use AR(1) PLMs for inflation and nominal wage growth only; all other expectations are RE. Aggregate `E_t X_{t+1} = n^L_{t-1} E_t X^L_{t+1} + n^RE_{t-1} E_t X^RE_{t+1}`.
  - Switching (eqs. 6-7): `n^RE_t = exp(-χ ζ^RE_t) / (exp(-χ ζ^RE_t) + exp(-χ ζ^L_t))`, with `ζ^j_t = (1-ω) FE^j_t + ω ζ^j_{t-1}` and FE^j the inflation forecast errors of rule j.
  - RLS (eq. 8): `R^x_t = R^x_{t-1} + γ_{t-1}(x̃_{t-1} x̃_{t-1}' - R^x_{t-1})` and `Φ^x_t = Φ^x_{t-1} + γ_{t-1} (R^x_t)^{-1} x̃_{t-1}(x̃_t - Φ_{t-1} x̃_{t-1})'`, with x̃ = [1, x]' and a common gain for both variables.
  - Endogenous gain (eq. 9): `γ_t = γ_{t-1} + μ R^γ_{t-1} FE^L_t` and `R^γ_t = (1 - γ_{t-1}) R^γ_{t-1} + FE^L_t`, with μ the step size ("gain on the gain"). The gain rises when the newest error has the same sign as accumulated past errors and falls otherwise.
  - Calibration: ω = 0.62, χ = 0.51, γ_0 = 0.059 (from Özden; cited as 2023 in the table and 2024 in the text), μ = 0.001 (from Kostyshyna 2012); R_0 is an identity matrix scaled by a small coefficient. Only the structural parameters come from a Bayesian estimation, and that estimation is of the RE baseline.
  - Sample: Canada; the text gives 1973Q1-2023Q1, the figures plot 1975Q1-2023Q1. In forecast-RMSE comparisons the learning model beats RE, including over the post-pandemic surge. Unanchoring risk rises with the adaptive share, the gain and extrapolation (β^x > 1). A composite credibility index combines n^RE with the adaptive agents' 20-quarter-ahead inflation forecast, perceived persistence and gain (Section 3.5; the formula is garbled in the extracted text). A high gain, a high adaptive share and high inflation together can make the learning dynamics E-unstable.

### Inferences
- In hetlearn's vocabulary these are four gain rules, all functions of past forecast errors:
  - (a) MN/Milani threshold switch: needs a J-window of absolute errors and a recursive MAD threshold per variable. Easy.
  - (b) CEMP criterion: needs the distance between the current PLM coefficients and the implied ALM (F, G). hetlearn already re-solves the model each quarter, so the ALM is available. Medium.
  - (c) Gáti smooth g(f): piecewise-linear knots (or a logistic) as estimable parameters, which allows asymmetry. Easy.
  - (d) KOZ adaptive step size: already implemented.
- With t-1 information, all of these keep the model conditionally linear given the past, so the existing time-varying Kalman filter still applies (the HMOZ argument). CEMP's t-timing with a nonlinear gain is what forced a particle filter, so hetlearn should restrict endogenous gains to t-1 information or warn the user.
- Gáti's Assumption 1 (learn only the inflation intercept, RE slopes) is a hybrid between "RE anchored" and "BR": RE dynamics with a drifting long-run mean. It is cheap to add as a PLM ("intercept-only with RE slopes") and is the cleanest way to put a CEMP/Gáti anchoring mechanism into SW07.
- Variable-specific gains (Milani 2011, 2014) need per-variable gain states; KOZ's single common gain is a restriction.

### Gaps
- CEMP primary text not read: the threshold θ̃, the exact survey series (SPF horizon), the sample and the anchored-regime gain were not verified.
- The exact Marcet-Nicolini criterion (I recall a percentage forecast error compared with a threshold v) was not verified in this session.
- KOZ eq. 7: whether FE^j enters squared is not visible in the extracted text (footnote 9 not read).
- Gáti's JME version may report different knot estimates from the ECB WP.

---

## 4. Small forecasting models in Smets-Wouters (2007) and survey-disciplined learning: best PLMs and estimated gains

### Takeaway
In SW07 on US data, small univariate forecasting rules beat both RE and MSV-consistent learning. Slobodyan-Wouters (2012a) find AR(2) rules under Kalman-filter learning (or an equal-weight average of five small models) give the best marginal likelihood. Learning about the MSV parameters only (2012b) fits about as well as RE, and the gains come from initial beliefs. Estimated constant gains are small (about 0.006-0.03), except when survey data are used to discipline the inflation PLM, where Ormeño's estimates are 0.14-0.19. Adding SPF expectations as observables decides the RE-versus-learning comparison: Ormeño's posterior odds are about 9e27 in favor of learning.

### Cited Findings

#### Slobodyan and Wouters (2012a): small forecasting models with Kalman-filter learning
- *AEJ: Macroeconomics* 4(2), 65-101 — [HMOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf); replication files — [openICPSR 114246](https://www.openicpsr.org/openicpsr/project/114246/version/V1/view). Agents use simple AR and VAR forecasting models learned through the Kalman filter, combined by prediction-based or fixed weights; the learning model fits better than RE; changing inflation-persistence beliefs imply that inflation responses to shocks declined over 25 years; the expectations are close to survey inflation expectations — [AEJ: Macro article (abstract)](https://www.aeaweb.org/articles/pdf/doi/10.1257/mac.4.2.65). HMOZ summarize the published result as "an AR(2) forecasting rule under Kalman gain learning substantially improves the model fit without a large effect on parameter estimates" — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Numbers from the February 2008 preliminary draft ("Estimating a medium-scale DSGE model with expectations based on small forecasting models"), which may differ from the published paper — [SW draft](https://www.frbsf.org/slobodyan_wouters_rev.pdf):
  - Candidate models: AR(1); AR(1) plus lagged interest rate and inflation; AR(2); AR(1) plus inflation; AR(1) plus interest rate, inflation and output.
  - Marginal likelihoods: REE -922 (natural output gap) or -926 (TFP-based gap). KF learning with five models: equal weights -909 to -910, BIC selection -910 to -917. Constant beliefs (no learning): -916 (EW) and -920 (BIC). Kalman-filter parameters fixed at posterior means γ = 0.031 and σ = 0.003.
  - Single models: "the model with beliefs formed based on the AR(2) specification performed best" and was similar to the equal-weight combination.
  - Perceived inflation persistence peaked in the mid-1970s and around 1980, then settled near 0.6 from the mid-1980s.
  - KF learning: `P_{t+1|t} = F P_{t|t} F' + V`. KF and constant-gain RLS are asymptotically equivalent on average (Sargent-Williams 2005) but differ in transition, and the draft shows how to tie P_0 and V to the gain γ.

#### Slobodyan and Wouters (2012b): MSV/VAR learning with constant gain
- "Learning in an estimated medium-scale DSGE model", *JEDC* 36(1), 26-46 — [IDEAS](https://ideas.repec.org/a/eee/dyncon/v36y2012i1p26-46.html). When agents know the correct structure and learn only the parameters, learning and RE fit about equally well, and the improvement comes from transition dynamics under specific initial beliefs. With reduced information sets the marginal likelihood can improve significantly, depending on initial beliefs. The best-fitting learning models add persistence and narrow the gap to DSGE-VAR impulse responses, without systematically changing the estimated frictions — [IDEAS abstract via search](https://ideas.repec.org/a/eee/dyncon/v36y2012i1p26-46.html).
- 2007 conference draft: "the estimated gain parameter is estimated to be small which suggests a crucial role for the initial beliefs". In simulations, gains of 0.01, 0.02 and 0.05 (forgetting half-lengths of roughly 69, 34 and 14 quarters) make the projection facility discard 0.04%, 0.37% and 13.8% of observations (0.05%, 0.69% and 24.14% with a constant in the PLM) — [SW 2007 draft](https://files.stlouisfed.org/files/htdocs/conferences/learningconf/2007/Slobodyan.pdf).

#### HMOZ horse race (same data family)
- AR(2) constant-gain learning gives MHM -1130.82 (log10 BF 5.33) with gain 0.008, below SAC (9.30) and VAR(1) learning (9.01). HMOZ note that an AR(2) PLM can generate extrapolation bias (more weight on the latest observation, negative weight on the second lag) — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf). Gaus and Gibbs (2018, mimeo) find that within PLMs nesting the MSV solution, initial beliefs matter more for fit than time variation in beliefs; Berardi and Galimberti (2017, *JEBO* 144, 219-237) find equilibrium-based initialization more robust — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).

#### Ormeño and Molnár (2015): survey data to discipline the PLM
- "Using survey data of inflation expectations in the estimation of learning and rational expectations models", *JMCB* 47(4), 673-699, DOI 10.1111/jmcb.12224 — [IDEAS](https://ideas.repec.org:443/a/wly/jmoncb/v47y2015i4p673-699.html). In SW07, learning and RE fit macro data about equally; learning clearly wins when macro and survey data are fitted together; survey data carry information the macro data do not — [search summary of JMCB/NHH versions](https://ideas.repec.org:443/a/wly/jmoncb/v47y2015i4p673-699.html).
- Numbers from the single-author CESifo WP 3552 (2011) precursor, which may differ from JMCB — [CESifo WP 3552](https://www.cesifo.org/DocDL/cesifo1_wp3552.pdf):
  - 127 candidate inflation forecasting models are ranked by MSE against the SPF (1968Q4-2008Q2, initial conditions from 1950Q1-1968Q3). The best is inflation on its own lag plus an intercept, with constant gain 0.125 (MSE 0.0294).
  - Log marginal likelihoods: macro only, RE -146.78 vs learning -142.82. Macro plus SPF one-quarter-ahead GDP-deflator median, RE -19.14 vs learning 45.22, posterior odds 8.93e27 for learning.
  - The posterior gain on inflation falls from 0.188 to 0.141 when survey data are added. Under RE, adding survey data cuts price indexation from 0.327 to 0.052 and raises price mark-up persistence from 0.448 to 0.726.

#### Milani (2011): expectation shocks with learning, SPF as observables
- "Expectation shocks and learning as drivers of the business cycle", *EJ* 121(552), 379-401 — [HMOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf); CEPR DP7743 (working paper) — [CEPR](https://cepr.org/publications/dp7743).
- NK model with constant-gain learning, estimated with SPF expectations (mean across forecasters, real-time information sets). Expectation shocks (the part of observed expectations the learning model cannot reconcile) account for roughly half of business-cycle fluctuations. The posterior constant gain is 0.0196 (95% interval 0.015-0.025); with variable-specific gains, 0.0179 (inflation), 0.0296 (output) and 0.005 (policy rate) — [Milani (2011), author version](https://sites.socsci.uci.edu/~fmilani/ESL.pdf).
- Related: Cole and Milani, "The misspecification of expectations in New Keynesian models: A DSGE-VAR approach" (CESifo WP 6099, 2016; UCI WP 2014), test whether NK models match the joint dynamics of macro variables and survey expectations — [CESifo WP 6099](https://www.cesifo.org/DocDL/cesifo1_wp6099.pdf).

### Inferences
- Best-fitting PLMs in SW07 (US) across papers: univariate AR(1) with intercept (SAC or RLS) and AR(2) (KF), with VAR(1) on state variables as an alternative. MSV-consistent learning adds little beyond initial beliefs.
- Estimated US constant gains: 0.006-0.024 (HMOZ, by PLM), 0.0187-0.0196 (Milani), about 0.03 (SW KF), and 0.14-0.19 for inflation when the PLM is disciplined by the SPF (Ormeño). Survey data push the inflation gain up, toward Gáti's and CEMP's unanchored values.
- Two hetlearn features follow. (i) A measurement equation for survey expectations (the aggregate mix, or a chosen type, mapped to SPF horizons) should be standard; three of the papers above find survey data decide the model comparison. (ii) SW 2012a's averaging over five small models is an N-type structure with fixed equal shares (or BMA weights); it needs the N-type generalization but no switching.
- The projection-facility numbers in SW (2007) imply that gains above about 0.05 trigger projections frequently in SW07. A prior on gains should keep most mass below that unless the PLM is bounded (SAC) or mean-only.

### Gaps
- Published SW 2012a marginal likelihoods and gains were not extracted (only the 2008 draft). The published 2012b gain estimates were not found.
- The JMCB Ormeño-Molnár numbers were not verified; the CESifo WP numbers are from a single-author precursor.

---

## 5. Experience-based learning (Malmendier-Nagel, Nagel-Xu) and macro applications

### Takeaway
Malmendier-Nagel (2016) give each birth cohort a decreasing gain γ_{t,s} = θ/(t-s) in age, not calendar time, applied to recursive AR(1) estimation of inflation from lifetime data. θ is estimated at about 3 on Michigan survey data. Averaged over cohorts, the result looks like constant-gain learning with γ ≈ 0.018 per quarter, which Nagel-Xu (2022) adopt as a fading-memory gain in asset pricing. I found no DSGE that embeds cohort-specific experience learning.

### Cited Findings
- Malmendier, U. and Nagel, S. (2016), "Learning from inflation experiences", *QJE* 131(1), 53-87, DOI 10.1093/qje/qjv037 — [DOI](https://doi.org/10.1093/qje/qjv037). Numbers below are from the 2012 working draft — [MN draft](https://eml.berkeley.edu/~webfac/obstfeld/ulrike.pdf).
- Mechanism: cohort s at time t recursively estimates an AR(1) for inflation using only data from its lifetime, with gain `γ_{t,s} = θ/(t-s)` if t-s ≥ θ and `1` if t-s < θ (eq. 4). The gain is decreasing in age, not time, unlike Marcet-Sargent (1989). θ = 1 weights lifetime data equally; θ > 1 down-weights early-life data — [MN draft](https://eml.berkeley.edu/~webfac/obstfeld/ulrike.pdf).
- Estimates (NLS of Michigan Survey one-year expectations on learning-from-experience forecasts, 1953-2009 with gaps, two-way clustered s.e.): θ = 3.006 (0.249) baseline with sensitivity β ≈ 0.65; 3.097 (0.272) without imputed data; 3.991 with the f_t = SPF_{t-1} restriction; 4.192 (0.445) with β = 1. The constant gain that best matches the average weights is γ = 0.0175, "quantitatively very similar" to the gains estimated by Orphanides-Williams (2005) and Milani (2007) — [MN draft](https://eml.berkeley.edu/~webfac/obstfeld/ulrike.pdf).
- Nagel, S. and Xu, Z. (2022), "Asset pricing with fading memory", *RFS* 35(5), 2190-2245, DOI 10.1093/rfs/hhab086 — [DOI](https://doi.org/10.1093/rfs/hhab086); NBER WP 26255 — [NBER](https://www.nber.org/papers/w26255).
- Nagel-Xu use a representative agent who learns the mean of i.i.d. endowment or payout growth with constant gain ν, weighting past observations by (1-ν)^j, and set ν = 0.018 per quarter because "Malmendier and Nagel (2016) show that ν = 0.018 for quarterly data fits the dynamics of the average belief in inflation expectations microdata". Fading memory comes from reliance on lifetime experience, not from structural change, and the gain is tied to microdata rather than fitted to prices. Results: a high and strongly countercyclical objective equity premium with an almost constant subjective premium; experienced payout growth predicts low future excess returns — [NBER WP 26255](https://www.nber.org/papers/w26255.pdf).
- Policy-maker application: Malmendier, Nagel and Yan, "The making of hawks and doves: Inflation experiences on the FOMC" — [SSRN 2935433](https://papers.ssrn.com/abstract=2935433).

### Inferences
- For an aggregate DSGE such as SW07, experience-based learning can be approximated by a mean-only (or AR(1)) PLM with constant gain 0.018. Easy in hetlearn, and the gain value is externally disciplined, so it could be fixed rather than estimated.
- A genuine cohort version needs one BR type per cohort (or age bin), each with a deterministic age-dependent gain schedule, aggregated with fixed demographic weights. That needs N types plus a deterministic gain path per type; switching is not needed. Interpreting heterogeneous savings plans also runs into Branch-McGough's aggregation axiom A7 on wealth distributions. Hard.

### Gaps
- The published QJE value of θ was not extracted (the draft gives 3.006).
- I found no macro DSGE or NK estimation with cohort-specific experience-based learning (searches were limited); this remains open.
- The publication details of Malmendier-Nagel-Yan (I believe JME 2021) were not verified.

---

## 6. Restricted perceptions, consistent expectations and misspecification equilibria

### Takeaway
Restricted-perceptions and consistent-expectations equilibria (CEE) fix beliefs within a misspecified class (for example AR(1)) at values consistent with selected moments of the actual process: the sample mean and autocorrelations in Hommes-Sorger (1998), or the projection or optimal Kalman gain in Lansing (2009). BLE is the n-dimensional linear version. Branch (2004) is the main empirical misspecification-and-switching paper: naive, adaptive and VAR predictors on Michigan survey data, with dynamic switching on relative MSE.

### Cited Findings
- Hommes, C. and Sorger, G. (1998), "Consistent expectations equilibria", *Macroeconomic Dynamics* 2(3), 287-321 — [IDEAS](https://ideas.repec.org/a/cup/macdyn/v2y1998i03p287-321_00.html). A CEE requires the sample average and sample autocorrelations of the actual dynamics to equal those of the agents' AR(1) perceived law of motion; the paper studies steady-state, two-cycle and chaotic CEE — [search summary of IDEAS abstract](https://ideas.repec.org/a/cup/macdyn/v2y1998i03p287-321_00.html).
- Stochastic CEE: a CeNDEF working paper generalizes CEE to nonlinear stochastic systems, where the invariant measure has mean and autocovariances equal to those of the linear process agents believe in, and studies convergence of OLS and SAC learning to CEE (working paper; authorship not confirmed, the search summary attributes it to Hommes, 2001) — [EconPapers](https://econpapers.repec.org/RePEc:ams:cdws01:po1). Branch and McGough (2005, JEDC) also treat CEE in stochastic nonlinear economies (author-hosted PDF "jedc_cee_2005"; title not verified) — [UCI PDF](https://www.economics.uci.edu/files/docs/faculty_review/jedc_cee_2005.pdf).
- Lansing (2009, *RED* 12(2), 304-326) builds a CEE in which agents use the optimal Kalman gain within their misspecified class — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Branch, W.A. (2004), "The theory of rationally heterogeneous expectations: Evidence from survey data on inflation expectations", *EJ* 114(497), 592-621 — [IDEAS](https://ideas.repec.org/a/ecj/econjl/v114y2004i497p592-621.html). Predictors: naive (annualized latest monthly inflation), adaptive (exponential smoothing with the smoothing parameter chosen by MSE over 1947.01-1999.04) and a 12-lag VAR (lag length by AIC), all with fixed parameters. Multinomial-logit shares with intensity β and predictor costs C_j for j ∈ {N, A, V}, estimated by ML on Michigan survey microdata — [Branch (2004) PDF](https://sites.socsci.uci.edu/~wbranch/Templates/EJ2004July.pdf).
- Branch (2004) results: the share using each predictor varies inversely with its MSE, so switching is dynamic, and on average agents use the VAR more often than adaptive or naive — [Branch (2004) PDF](https://sites.socsci.uci.edu/~wbranch/Templates/EJ2004July.pdf).
- Branch's survey chapter "Restricted perceptions equilibria and learning in macroeconomics" is in *Post Walrasian Macroeconomics: Beyond the Dynamic Stochastic General Equilibrium Model*, pp. 135-160. HMOZ date it 2004; the brief says 2006 — [HMOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- Branch and Evans (2006), "A simple recursive forecasting model", *Economics Letters* 91(2), 158-166 — [HMOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf). In Branch-Evans (2006), heterogeneity survives as the intensity of choice goes to infinity (an intrinsic-heterogeneity, misspecification-equilibrium result) — [BM 2010 footnote 8](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf).
- Regime-switching application: a ZLB paper models restricted perceptions in which agents omit the regime state and forecast with an under-parameterized model (authors not confirmed in my search) — [arXiv 2208.02073](https://arxiv.org/pdf/2208.02073).

### Inferences
- In hetlearn, an RPE, CEE or BLE type is a BR type with beliefs fixed at an equilibrium value of a misspecified PLM, solved as a fixed point for each parameter vector. One fixed-point routine covers all three; they differ only in the moment condition (projection orthogonality for RPE, mean plus autocorrelation for CEE/BLE, optimal Kalman gain for Lansing). Medium.
- Branch-Evans misspecification equilibria with endogenous shares (shares and beliefs jointly in equilibrium) need N types and a joint fixed point in beliefs and shares. Hard.
- Branch (2004) is the natural template for estimating switching on survey microdata. With a survey measurement equation hetlearn could estimate shares from the SPF or Michigan cross-sectional dispersion, but only with a likelihood for the cross-section, which is a separate extension.

### Gaps
- Authorship and publication of the stochastic-CEE working paper (EconPapers ams:cdws01:po1) were not confirmed; the "Hommes, Sorger and Wagener" attribution in the brief is unverified.
- The Branch-Evans (2006, JET) "intrinsic heterogeneity" paper is cited only indirectly; bibliographic details not verified.
- Branch (2004) numeric estimates (β, C_j) not extracted.

---

## 7. Mean-only (steady-state) learning and adaptive expectations

### Takeaway
Mean-only learning, x^e_t = x^e_{t-1} + g(x_{t-1} - x^e_{t-1}), is constant-gain learning of an intercept-only PLM, i.e. exponential smoothing. It appears under several names: the ADA heuristic (gain 0.65 in Anufriev-Hommes), Branch's adaptive predictor, Nagel-Xu fading memory (ν = 0.018), and, combined with RE slopes and an endogenous gain, the CEMP and Gáti models of long-run inflation anchoring. It is the cheapest PLM in hetlearn and gives the most direct link to the anchoring literature.

### Cited Findings
- ADA heuristic `p^e_{t+1} = 0.65 p_{t-1} + 0.35 p^e_t`, i.e. `p^e_{t+1} = p^e_t + 0.65 (p_{t-1} - p^e_t)`: adaptive expectations with gain 0.65 and t-1 information — [Anufriev-Hommes KER](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf).
- Branch (2004) estimates an adaptive (exponential-smoothing) inflation predictor with the smoothing parameter chosen by MSE — [Branch (2004) PDF](https://sites.socsci.uci.edu/~wbranch/Templates/EJ2004July.pdf).
- Nagel-Xu fading memory: the subjective mean growth μ̃_{d,t} is updated with the surprise (Δd_{t+1} - μ̃_{d,t}) scaled by ν = 0.018 per quarter — [NBER WP 26255](https://www.nber.org/papers/w26255.pdf).
- Gáti's Assumption 1 (only the inflation intercept learned, RE slopes, `π̄_t = π̄_{t-1} + k_t f_{t|t-1}`) is "the smallest possible deviation from rational expectations that has enough flexibility to study the unanchoring of inflation expectations" — [Gáti ECB WP](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2685~95e6d7b379.en.pdf).
- CEMP: long-run inflation expectations respond to short-run surprises with a performance-dependent sensitivity, estimated on inflation and short-term survey forecasts — [AEA](https://www.aeaweb.org/doi/10.1257/mac.20200080).
- Averaged across cohorts, experience-based expectations resemble constant-gain learning — [MN draft](https://eml.berkeley.edu/~webfac/obstfeld/ulrike.pdf).
- Naive (random-walk) expectations are the gain-1 limit. HL note that they are nearly rational for near-unit-root inflation and add persistence without serially correlated shocks — [HL JME](https://pure.uva.nl/ws/files/44671470/1_s2.0_S0304393219300170_main.pdf).

### Inferences
- In hetlearn, a mean-only PLM is RLS with regressor [1]: R = 1, so `ā_t = ā_{t-1} + g (x_t - ā_{t-1})` and, with t-1 information, `E_t x_{t+1} = ā_{t-1}`. It needs no projection facility (beliefs are a convex combination of data) and supports every gain rule above. Easy.
- Three variants are worth exposing separately:
  - (i) pure mean (adaptive expectations);
  - (ii) intercept-only with RE slopes (Gáti/CEMP style, an anchored RE type with a drifting long-run mean);
  - (iii) a mean fixed at target, which is the HL fundamentalist / De Grauwe targeter and also hetlearn's "fixed rule" with the mean equal to π*.
- Variant (ii) is also the natural way to nest Özden-style RE/BR switching with CEMP-style anchoring: the RE type's long-run inflation belief drifts with an endogenous gain while its slopes stay model-consistent.

### Gaps
- Steady-state learning in DSGE (for example the Evans-Honkapohja-Mitra line of work, or Eusepi-Preston 2011) was not reviewed in detail. KOZ cite Evans, Honkapohja and Mitra (2022, *IER* 63, 1397-1425) — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf) — but I did not check whether it uses steady-state learning.
- Lansing (2009) specifics (estimated gain, PLM) not verified.

---

## 8. Mapping to hetlearn: difficulty, reused components, and the N-type generalisation

### Takeaway
Most extensions slot into components hetlearn already has (PLM, updating rule, gain rule, fixed-rule BR type) and are easy or medium. The structural bottleneck is the two-type restriction. Anufriev-Hommes, Branch (2004), De Grauwe with RE, Elias, SW (2012a) model averaging, Hommes-Lustenhouwer alongside RE, and cohort-based experience learning all need K ≥ 3 types or several non-RE types. Generalizing to a list of K type objects with a multinomial-logit (plus inertia and cost) share rule is the most valuable single change.

### Cited Findings
(Facts used in the mapping; sources as in the sections above.)
- Multinomial logit over I rules with intensity β, where β = 0 gives equal shares — [CHM](https://eprints.whiterose.ac.uk/116520/1/CHM_JBES_March_2017.pdf). AH add inertia `n_{t,h} = δ n_{t-1,h} + (1-δ) softmax(β U_{t-1})` and memory η — [AH KER](https://maxapress.com/data/article/ker/preview/pdf/S0269888912000161.pdf). Costs or predisposition enter as constants in fitness — [BM 2010](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf).
- Variable-specific shares: separate n^y and n^π (BM 2010) — [BM 2010](https://www.economics.uci.edu/files/docs/faculty_review/jedc_2010_nkdyn.pdf); separate O/P shares for output and tar/ext shares for inflation, with common ρ and γ (Jang-Sacht/De Grauwe) — [Jang-Sacht](https://www.econ.nagoya-cu.ac.jp/wp-content/uploads/2015/01/Jang_Sacht_Animal_Spirits.pdf); one share driven by inflation errors applied to inflation and wage expectations, with a common gain (KOZ) — [KOZ](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).
- t-1 timing keeps learning models conditionally linear and Kalman-filter estimable — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf); CEMP's t-timing needed a particle filter — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf).
- SAC beliefs stay in [-1, 1], so no projection facility is needed — [HMOZ](https://www.bankofcanada.ca/wp-content/uploads/2022/09/swp2022-42.pdf); projection frequency rises steeply with the gain in SW07 — [SW 2007 draft](https://files.stlouisfed.org/files/htdocs/conferences/learningconf/2007/Slobodyan.pdf).
- An alternative updating rule cited in KOZ: Evans, Honkapohja and Williams (2010), "Generalized stochastic gradient learning", *IER* 51, 237-262 — [KOZ reference list](https://www.bankofcanada.ca/wp-content/uploads/2024/05/swp2024-14.pdf).

### Inferences

#### Mapping table
Difficulty: E = easy (a new function in an existing slot), M = medium (new state or a fixed point inside the likelihood), H = hard (model rewrite or a new equilibrium concept). "N-type?" marks items that need more than one non-RE type, or K ≥ 3 types.

| Family / feature | What to add in hetlearn | Reuses | Difficulty | N-type? |
|---|---|---|---|---|
| Naive / random walk, target believer (E = π*), constant optimist/pessimist (±d_t), extrapolator E = x_{t-1}, BM adaptive E = θ^2 x_{t-1} | fixed-rule BR class (parameterized) | fixed-rule BR type (exists as a held-fixed PLM) | E | Yes, if used alongside RE plus another BR type (HL, De Grauwe, BH cobweb) |
| AH trend rules WTR/STR: x_{t-1} + c(x_{t-1} - x_{t-2}) | fixed AR(2)-in-levels rule (t-1 info) | fixed-rule BR, AR(2) PLM | E | Yes (K = 4 for AH) |
| AH ADA (needs own lagged forecast) and LAA (needs running sample mean) | extra belief states: own past forecast, running mean | mean-only PLM (for LAA anchor) | M | Yes |
| Brock-Hommes costs/predisposition C_k | constant per type in fitness | discrete choice | E | No |
| AH inertia δ and unnormalized memory | `n_t = δ n_{t-1} + (1-δ) softmax(·)`; a fitness-normalization option | discrete choice | E | No |
| N-type multinomial logit, variable-specific type sets and shares | type list of K objects; share vector per "share group"; log-sum-exp softmax | discrete choice, aggregator x_exp = Σ n_k E^k | M (structural) | This is the generalization |
| SAC learning (Hommes-Sorger / Hommes-Zhu) | updating rule for AR(1): (α, β, R) recursion, decreasing or constant κ | AR(1) PLM | E | No |
| BLE / RPE / CEE (Lansing) fixed beliefs | fixed-point solve of PLM coefficients for each parameter draw (iteration doubles as E-stability check) | fixed BR type + re-solve loop | M | No |
| Kalman-filter learning (SW 2012a) | updating rule with P_{t+1 given t} = F P F' + V | PLM layer | M | No |
| Small-model averaging (SW 2012a EW/BMA) | K BR types with fixed equal or BMA weights | N-type aggregator | M | Yes |
| MN/Milani threshold gain | gain rule: decreasing vs ḡ, J-window MAD threshold | gain-rule slot | E | No |
| CEMP criterion gain | gain rule using distance between PLM and the current ALM (F, G), or CUSUM statistic | gain-rule slot + ALM from re-solve | M | No |
| Gáti smooth anchoring g(f) | piecewise-linear or logistic gain in the forecast error (asymmetric) | gain-rule slot | E | No |
| KOZ adaptive step size | (exists) | — | done | No |
| Per-variable gains (Milani) | gain vector instead of scalar | gain-rule slot | E | No |
| Mean-only PLM, intercept-only with RE slopes | PLM with regressor [1]; option to inherit RE slopes | PLM layer, RE anchored | E | No |
| Experience learning, aggregate approximation | mean-only or AR(1) PLM with fixed g = 0.018 | PLM + constant gain | E | No |
| Experience learning, cohorts | K cohort types, deterministic age-gain schedules, demographic weights | N-type aggregator, gain schedule | H | Yes |
| CHM fundamentalists (PV of VAR-forecast marginal cost) | auxiliary recursively estimated VAR inside a type | VAR PLM | M | No (2-type with naive), but the second type is non-RE |
| Misspecification equilibrium with equilibrium shares (Branch-Evans) | joint fixed point in beliefs and shares | fixed-point routine + N-type | H | Yes |
| Infinite-horizon heterogeneous expectations (Massaro; Preston) | decision rules depend on discounted sums of many future forecasts, not one-step E_t x_{t+1} | none (hetlearn replaces one-step terms) | H | No |
| Survey expectations as observables (OM, Milani 2011, HMOZ, CEMP) | measurement equation from the aggregate (or a type's) k-step forecast to SPF horizons | Kalman filter | E-M | No |
| Expectation shocks (Milani 2011) | additive shock on E-terms or on the survey measurement | shocks | E | No |

#### Recommended N-type design (implementation inference)
- Represent each type k as a struct: `kind` ∈ {RE_anchored, RE_consistent, fixed_rule, learned_plm, equilibrium_belief}; `info` ∈ {t, t-1}; `plm`; `update` ∈ {RLS, SAC, KF, SG, none}; `gain` ∈ {const, decreasing, KOZ, MN-switch, CEMP, Gáti-g, age-schedule}; `cost` C_k; and `variables` (the subset of forward variables the type forecasts; other variables fall back to a designated default type, as in KOZ where non-inflation, non-wage expectations are RE).
- Shares: `n_{g,t} = δ_g n_{g,t-1} + (1-δ_g) softmax_k(β_g (U_{k,t-1} - C_k))` for each share group g, with `U_{k,t} = η U_{k,t-1} - (1-η) L_k(e_t)` and L_k a squared or absolute error on a chosen variable or weighted variable set. A switch for the AH unnormalized convention, `U_t = -e_t^2 + η U_{t-1}`, would make published parameter values reproducible.
- Aggregation for each variable i: `x_exp_i = Σ_k n_{g(i),k,t-1} E^k_t x_{i,t+1}`, using lagged shares (BM 2010 and KOZ both use n_{t-1}), which keeps the model conditionally linear for the Kalman filter.
- Identification: CHM estimate β by NLS, Jang-Sacht fix it on a grid, KOZ calibrate it. With K > 2, expect weak identification of (β, η, δ, C_k); use informative priors and a fixed fitness scale, and consider estimating one intensity per share group with type costs fixed.
- Unit tests that the N-type code must reproduce: (i) K = 2 with RE + AR(1) reproduces current hetlearn; (ii) AH four-heuristic simulation with β = 0.4, η = 0.7, δ = 0.9 reproduces the KER figures in a simple asset-pricing model; (iii) HL fundamentalists plus naive reproduce the larger stability region.

#### Priority ordering (judgment)
1. N-type generalization (unlocks AH, Branch 2004, De Grauwe, HL, Elias, model averaging, cohorts).
2. Mean-only / intercept-only-with-RE-slopes PLM plus Gáti and MN/Milani gain rules (cheap, and gives the anchoring literature).
3. SAC learning and BLE fixed beliefs (the best-fitting SW07 results; the user's own line of work).
4. Survey measurement equation and expectation shocks (the evidence above says survey data decide model comparisons).
5. CEMP criterion and KF learning (medium).
6. Cohort experience learning, misspecification equilibria, infinite-horizon HE (hard; research projects rather than features).

### Gaps
- I found no published Bayesian estimation of an N > 2 switching model in a medium-scale DSGE on US data, so no benchmark exists for identification or runtime of the proposed N-type estimator.
- Whether the AH lab heuristics, which forecast two periods ahead with t-1 information in asset markets, transfer to NK forecasting in Assenza et al. (2021) was not checked.
- Computational cost of a per-draw BLE/RPE fixed point inside the SW07 likelihood is not documented in the sources read (HMOZ report the method, not timings).
