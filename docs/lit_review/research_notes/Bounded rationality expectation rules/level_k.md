# Level-k thinking, cognitive hierarchy and iterative reasoning as expectation rules in macroeconomics (DSGE / New Keynesian)

## Q1. Which Paul Beaudry paper uses level-k thinking, and what are its specification and results?

### Takeaway
The paper is Paul Beaudry, Thomas J. Carter and Amartya Lahiri, "The Central Bank's Dilemma: Look Through Supply Shocks or Control Inflation Expectations?". It circulated as Bank of Canada Staff Working Paper 2022-41 under an earlier title, then as NBER Working Paper 31741 (September 2023) and IMF Working Paper WP/26/97 (May 2026). I found no journal version. Level 0 is adaptive: last period's inflation and employment gaps. Level k pushes that seed k times through the Phillips curve and the announced policy feedback rule, so expectations equal (1-θ_t)^(k-1) times the adaptive seed. k = 0 gives adaptive expectations and k → ∞ gives RE. With k = 2 calibrated to annual Canadian data, the optimal policy looks through supply shocks until an overheating threshold of about 4% and then jumps to a hawkish stance (a "pivot").

### Cited Findings
**Bibliographic trail**
- NBER Working Paper No. 31741, September 2023, JEL E40, E50. Authors: Paul Beaudry (UBC and NBER), Thomas J. Carter (Bank of Canada), Amartya Lahiri (UBC). The paper says: "A previous version of this paper circulated under the title 'Looking through supply shocks versus controlling inflation expectations: understanding the central bank dilemma'". Beaudry and Carter were Bank of Canada employees when most of it was written. — [NBER WP 31741 (PDF)](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf); [NBER page](https://www.nber.org/papers/w31741)
- The earlier version is Bank of Canada Staff Working Paper 2022-41. I took this from a search-result listing and did not open the paper. — [EconPapers, BoC SWP 22-41](https://econpapers.repec.org/paper/bcabocawp/22-41.htm)
- IMF Working Paper WP/26/97, May 2026 (Monetary and Capital Markets Department), same title and authors. The reworded abstract says: "While our analysis covers a wide range of potential specifications, our baseline results focus on level-k thinking (LKT)". — [IMF WP/26/97 (PDF)](https://www.imf.org/-/media/files/publications/wp/2026/english/wpiea2026097-source-pdf.pdf)

**Model (NBER 2023 version, unchanged in structure in the 2026 version)**
- Wages are set one period ahead, before the productivity shock is seen. Prices are flexible: firms set a mark-up over wages and productivity after seeing the shock. Productivity is the only shock, a log random walk. The Phillips curve is π̂_t = E^WS_{t-1}(N̂_t) + E^WS_{t-1}(π̂_t) − ε̂_t, where ε̂_t is the productivity surprise. The authors stress that this residual is a true supply shock, not a mark-up shock. Section 4 switches to GHH preferences, which gives a slope κ (a function of the Frisch elasticity) on expected employment; the calibration sets κ = 0.092. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Policy is a feedback rule N̂_t = −θ_t π̂_t, with stance θ_t announced before productivity is observed. θ_t is read as the cumulated expected real-rate stimulus obtained by forward-solving the IS curve. The system (π̂, N̂, θ) solves recursively without the IS curve, so household expectations play no role in the main results. The expectations that matter are wage setters' (t-1)-dated forecasts of current-period π̂_t and N̂_t. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- The design deliberately plays down intertemporal (staggered-pricing) coordination. Prices and wages reset every period, and each wage setter must "forecast the forecasts" of the others, which gives "a static coordination game to which LKT can readily be applied". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)

**Level-k specification**
- Level-0 seed: E^0_{t-1}(π̂_t) = π̂_{t-1} and E^0_{t-1}(N̂_t) = N̂_{t-1}. Level 1 passes the seed through the Phillips curve and the feedback rule. LKT does not touch expectations of exogenous variables (E^k(ε̂_t) = 0). Iterating gives eqs. (3.14)–(3.15): E^k_{t-1}(π̂_t) = (1−θ_t)^(k−1)[E^0(N̂_t)+E^0(π̂_t)] and E^k_{t-1}(N̂_t) = −θ_t(1−θ_t)^(k−1)[E^0(N̂_t)+E^0(π̂_t)]. Equilibrium is π̂_t = (1−θ_t)^k(N̂_{t-1}+π̂_{t-1}) − ε̂_t and N̂_t = −θ_t[(1−θ_t)^k(N̂_{t-1}+π̂_{t-1}) − ε̂_t]. This equals AE at k = 0, and as k → ∞ it collapses to the RE outcome (π̂, N̂) = (−ε̂, θε̂) "so long that θ_t ∈ (0,1]". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- The baseline uses a single common k: all wage setters share common, possibly wrong, expectations. The law of iterated expectations fails "because each wage-setter believes that they are more sophisticated than all other wage-setters". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Benchmarks. Under RE any θ > 0 keeps expectations at target, so the optimum is a "vanishingly low" θ, i.e. full look-through. Under AE the optimal θ is constant (no pivots): zero for a myopic central bank, positive for a forward-looking one. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)

**Results**
- The policy problem uses an overheating state x_t ≡ π̂_t + N̂_t with law of motion x_t = (1−θ_t)[(1−θ_t)^k x_{t-1} − ε̂_t]. The loss is quadratic in inflation and employment gaps, and the central bank has RE and commits to θ_t. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Mechanism: LKT makes the loss non-convex. A "direct" channel (tightening cuts activity at given expectations) works against an "indirect" channel (tightening re-anchors expectations). Expectations under LKT "are more sensitive to changes in monetary policy if policy is already tight to begin with". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Proposition 3.1: the optimal stance rises with x²_{t-1}. Above a threshold on the employment weight μ it jumps discontinuously at a unique cutoff. Proposition 3.2: that threshold is strictly increasing in k and goes to infinity in the RE limit. Proposition 3.3: with k = 1, pivots leave expected employment unchanged (a "tough talk" strategy) but raise employment variance ("risky" or "narrow" soft landings). — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Calibration, annual periods: β_CB = 0.995, μ = 1, κ = 0.092 (Canadian estimates), and k = 2, "placing us in the middle of the range of k = 1 to 4 considered in Farhi and Werning (2019) and in line with the experimental literature". σ² matches the variance of Canadian CPI inflation since the mid-1990s inflation-target period. The model is solved by value function iteration. The pivot threshold is x_{t-1} ≈ 4%. With k ≤ 3, pivots occur at thresholds of 3–5%. With k = 40 there are no pivots even at x_{t-1} = 10%. Higher k gives smaller jumps, and a forward-looking central bank pivots earlier than a myopic one. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Appendix H of the 2026 version (alternative expectation models):
  - Reflective expectations: a continuous update on [0, k] from the adaptive seed gives E^WS_{t-1}(x_t) = exp(−kθ_t)x_{t-1}.
  - Cognitive hierarchy: k+1 levels, with level 0 adaptive. Level k̃ believes everyone else is at level k̃−1 or below, with true shares f and subjective shares normalized "consistent with this distribution" as in Camerer et al.
  - Pivots survive in both versions. — [IMF WP/26/97](https://www.imf.org/-/media/files/publications/wp/2026/english/wpiea2026097-source-pdf.pdf)
- Empirical illustration in the 2026 version:
  - Data: US 2020Q1–2023Q4 Michigan and Cleveland Fed one-year expectations, ECI wage growth, trimmed inflation and the fed funds rate.
  - The regression is reduced form: expected inflation on lagged trimmed inflation and V/U, over 1982Q1/1990Q1/2000Q1–2023Q4.
  - Residuals rise from about 2020Q2 until the 2022Q2 tightening and then revert, which matches the pivot mechanism.
  - The authors call this a positive test, not a normative one. — [IMF WP/26/97](https://www.imf.org/-/media/files/publications/wp/2026/english/wpiea2026097-source-pdf.pdf)

**Closely related work**
- Dupraz and Marx (Banque de France), "Anchoring Boundedly Rational Expectations", draft dated July 31, 2024. They use finite planning horizons plus long-term learning (Woodford). They describe BCL's level-k as "a midpoint between fully rational and fully backward-looking expectations" and state that their own optimal policy "does not display brusque reversals resembling a pivot". — [Dupraz & Marx (PDF)](https://www.clevelandfed.org/-/media/project/clevelandfedtenant/clevelandfedsite/events/inflation-dynamics-and-drivers/2024/dupraz_anchoringboundedlyrationalexpectations.pdf)

### Inferences
- BCL's LKT is level-k stacked on a naive learned level 0. In toolbox terms it is a level-0 PLM "forecast = last observation" with t−1 information, plus a T-map that is linear with slope (1−θ_t). The closed form (1−θ)^k is T^k applied to the seed.
- The structural difference from hetlearn matters. BCL apply level-k to a within-period nowcast (wage setters at t−1 forecasting period-t outcomes), not to E_t x_{t+1} in Euler equations. Policy moves expectations because the announced θ_t enters every level k ≥ 1 forecast while level 0 ignores it. A toolbox version needs the same split: announced rule changes enter level ≥ 1 beliefs but not the level-0 PLM.
- (1−θ)^k → 0 needs |1−θ| < 1, i.e. θ ∈ (0, 2). The authors restrict to θ ∈ (0, 1], where levels never alternate in sign. For θ ∈ (1, 2) the strategic interaction becomes substitutive and level forecasts oscillate. This is the "bug" Angeletos and Sastry and Angeletos and Lian criticize (Q4).
- k enters only as an exponent (or as exp(−kθ) in the reflective version), so treating k as continuous is natural. BCL calibrate k and do not estimate it.

### Gaps
- SSRN abstract 6802083 (listed in search results under this title) returned HTTP 403. I could not tell whether it is the IMF version or another revision.
- I did not read the 2022 Bank of Canada version, so how it differs from the NBER version is unverified.
- No journal publication found as of October 2026.
- I found no other Beaudry paper using level-k. His work with Hou and Portier on expectations and inflation turned up in searches but I did not check it, and it does not appear to use level-k.

## Q2. Which macro papers use level-k, cognitive hierarchy, reflective equilibrium or shallow reasoning?

### Takeaway
Most macro applications are deterministic, one-off "unfamiliar policy" experiments: interest-rate pegs, forward guidance, the ZLB, QE, fiscal stimulus at the ZLB. In these, level 0 is the status quo path. Two lines break that mould. Evans, Gibbs and McGough (2025) put level-k on top of adaptive learning and replicator dynamics. Qiu (2018, unpublished JMP) builds a recursive, state-contingent level-k DSGE and estimates k by Bayesian methods. Angeletos and coauthors supply the unifying theory: level-k, reflective equilibrium, cognitive hierarchy, shallow reasoning and incomplete information all damp general-equilibrium (GE) feedback.

### Cited Findings
**Macro applications**
- García-Schmidt, M., and M. Woodford (2019), "Are Low Interest Rates Deflationary? A Paradox of Perfect-Foresight Analysis", *American Economic Review* 109(1): 86–120; NBER WP 21614 (October 2015). They introduce "reflective equilibrium". An announced long peg can produce a reflective equilibrium that "need not resemble any PFE". A commitment to low rates "should raise inflation and output, though by less than some PFE analyses apply". — [GSW NBER WP 21614](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf); citation details in [EGM reference list](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Farhi, E., and I. Werning (2019), "Monetary Policy, Bounded Rationality, and Incomplete Markets", *AER* 109(11): 3887–3928; NBER WP 23281 (March 2017, revised February 2019). Level-k thinking interacts with incomplete markets (uninsurable risk, borrowing constraints) to produce "a powerful mitigation of the effects of monetary policy, which is more pronounced at long horizons", a possible rationalization of the forward guidance puzzle. "Each of these frictions, in isolation, would lead to no or much smaller departures". — [FW NBER WP 23281](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf); [EGM reference list](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Iovino, L., and D. Sergeyev (2023), "Central Bank Balance Sheet Policies Without Rational Expectations", *Review of Economic Studies* 90(6): 3119–3152; earlier CEPR DP 13100 (2018). QE and FX interventions are neutral under RE (Wallace) but effective under level-k / reflective equilibrium. They have first-order effects on asset prices and second-order effects on output. Interventions predict asset-price forecast errors. — [IDEAS (REStud)](https://ideas.repec.org/a/oup/restud/v90y2023i6p3119-3152..html); [REStud page](https://www.restud.com/paper/central-bank-balance-sheet-policies-without-rational-expectations/); [2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf); [CEPR DP13100](https://cepr.org/publications/DP13100)
- Bianchi-Vimercati, R., M. Eichenbaum, and J. Guerreiro (2024), "Fiscal Stimulus with Imperfect Expectations: Spending vs. Tax Policy", *Journal of Economic Theory* 217: 105814; NBER WP 29134 (2021); earlier title "Fiscal Policy at the Zero Lower Bound without Rational Expectations" (June 2021 draft). In an NK model with level-k agents, "The less sophisticated people are, the smaller is the size of the government-spending multiplier". Tax policy at the ZLB "is essentially undiminished", and how tax policy is communicated is critical. — [BEG 2021 draft](https://conference.nber.org/conf_papers/f152765/f152765.pdf); [NBER WP 29134](https://www.nber.org/papers/w29134); [IDEAS (JET)](https://ideas.repec.org/a/eee/jetheo/v217y2024ics0022053124000206.html)
- Farhi, E., M. Petri, and I. Werning (2020), "The Fiscal Multiplier Puzzle: Liquidity Traps, Bounded Rationality, and Incomplete Markets", mimeo. BEG cite it alongside Woodford and Xie (2019) for the result that the spending multiplier depends on cognitive sophistication. — [BEG reference list](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- Beaudry, Carter and Lahiri (2023/2026): see Q1. — [NBER WP 31741](https://www.nber.org/papers/w31741)
- Evans, G. W., C. G. Gibbs, and B. McGough (2025), "A Unified Model of Learning to Forecast", *American Economic Journal: Macroeconomics* 17(2): 101–133; University of Sydney WP 2021-10. They unify "adaptive learning, k-level reasoning, and replicator dynamics. Level-0 forecasts evolve over time via adaptive learning." They test the model in learning-to-forecast experiments (LtFEs) and apply it to forward guidance in the NK model. Data and code are on openICPSR project 198204. — [EGM final draft (PDF)](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf); [IDEAS (AEJ: Macro)](https://ideas.repec.org/a/aea/aejmac/v17y2025i2p101-33.html); [WP version](https://ideas.repec.org/p/syd/wpaper/2021-10.html); [openICPSR](https://www.openicpsr.org/openicpsr/project/198204/view)
- Qiu, Zhesheng (2018), "Level-k DSGE and Monetary Policy", University of Pennsylvania job market paper, dated 30 January 2018. A recursive level-k DSGE with incomplete markets "to guarantee the eductive stability of the equilibrium". k = 1.265 is identified from Michigan Survey growth and inflation expectations. Qiu's 2024 CV still lists it as a working paper. — [Qiu JMP (PDF)](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf); [Qiu CV 2024](https://econ.hkust.edu.hk/sites/economics/files/faculty/cv_zheshqiu_2024.pdf)

**Theory and surveys on "dampening GE"**
- Angeletos, G.-M., and C. Lian (2018), "Forward Guidance without Common Knowledge", *AER* 108(9): 2477–2512. Incomplete information, not level-k. EGM group it with FW as resolving the forward guidance puzzle "if agents are exogenously assumed to be low-level reasoners". — [EGM final draft](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Angeletos, G.-M., and K. A. Sastry (2021), "Managing Expectations: Instruments Versus Targets", *QJE* 136(4): 2467–2532. "Shallow reasoning": every agent believes only a fraction λ of others are rational and attentive like herself, and the rest are inactive. Whether to communicate instruments (rates) or targets (unemployment) "depends on the relative importance of partial versus general-equilibrium effects". They call level-k's oscillation under strategic substitutability a "bug". — [EGM reference list](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf); [BEG 2021 draft, summary of AS](https://conference.nber.org/conf_papers/f152765/f152765.pdf); [Angeletos & Lian handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)
- Angeletos, G.-M., and C. Lian, "Dampening General Equilibrium: Incomplete Information and Bounded Rationality", NBER WP 29776 (February 2022, revised August 2022), "prepared for the Handbook of Economic Expectations". It reviews incomplete information, "Level-k Thinking or a smooth variant thereof" (reflective equilibrium, cognitive hierarchy), heterogeneous priors / shallow reasoning, and cognitive discounting. — [NBER WP 29776](https://nber.org/papers/w29776); [PDF](https://nber.org/system/files/working_papers/w29776/w29776.pdf)
- Woodford, M. (2013), "Macroeconomic Analysis Without the Rational Expectations Hypothesis", *Annual Review of Economics* 5(1): 303–346; NBER WP 19368. It surveys alternatives in a log-linear NK model, including "rationalizable equilibrium dynamics" (eductive reasoning), restricted perceptions equilibria, decreasing- and constant-gain learning, and near-rational expectations. — [IDEAS (ARE)](https://ideas.repec.org/a/anr/reveco/v5y2013p303-346.html); [NBER WP 19368](https://www.nber.org/papers/w19368)
- Gibbs, C. G., and N. McClung (2023), "Does my model predict a forward guidance puzzle?", *Review of Economic Dynamics* 51: 393–423; Bank of Finland DP 19/2019. They give sufficient conditions for bounded forward-guidance responses. These match a special case of E-stability conditions, distinct from determinacy, and they diagnose the puzzle in medium-scale DSGE models. Search-result summaries of the published abstract call the criterion "iterative E-stability" (IE-stability). — [IDEAS (BoF DP)](https://ideas.repec.org/p/zbw/bofrdp/rdp019.html); [BoF repository](https://publications.bof.fi/handle/10024/53292); [CNB seminar slides](https://www.cnb.cz/export/sites/cnb/en/economic-research/.galleries/seminars_workshops/download/Gibbs.pdf)
- Evans, G. W., and R. Guesnerie (1993), "Rationalizability, strong rationality, and expectational stability", *Games and Economic Behavior* 5(4): 632–646. EGM credit it with formalizing the link between eductive stability and iterative E-stability. Evans, Guesnerie and McGough, "Eductive Stability in Real Business Cycle Models", *Economic Journal* 129(618): 821–852, show the RBC model is not eductively stable but is stable under adaptive learning. — [EGM final draft](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)

**Game-theory base and experiments (only what is needed)**
- Nagel, R. (1995), "Unraveling in Guessing Games: An Experimental Study", *AER* 85(5): 1313–1326. Level 0 is the midpoint of the guess range. Nagel (1995) and Duffy and Nagel (1997, *EJ* 107(445): 1684–1700) document "sluggish updating of reasoning depth" in repeated games. Other experimental references: Ho, Camerer and Weigelt (1998, *AER* 88(4): 947–969); Bosch-Domènech, Montalvo, Nagel and Satorra (2002, *AER* 92(5): 1687–1701); Costa-Gomes and Crawford (2006, *AER* 96(5): 1737–1768). — [EGM final draft](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Camerer, C. F., T.-H. Ho, and J.-K. Chong (2004), "A Cognitive Hierarchy Model of Games", *QJE* 119: 861–898. Step-0 players randomize, and step-k players best-respond to a population of lower steps. A Poisson distribution with mean τ ≈ 1.5 fits data from many games. — [CHC article copy](https://www.csc2.ncsu.edu/faculty/mpsingh/local/Social/f24/wrap/readings/Camerer+Ho+Chong-cognitive-hierarchy-of-games-2004.pdf); [BEG reference list](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- Mauersberger, F., and R. Nagel (2018), "Levels of reasoning in Keynesian Beauty Contests: a generative framework", *Handbook of Computational Economics* vol. 4: 541–634. Sutan and Willinger (2009, *JEDC* 33(5): 1123–1133) run level-k experiments with negative feedback. Bao and Duffy (2016, *EER* 83: 64–89) compare adaptive and eductive learning. Anufriev, Duffy and Panchenko (2022, *JET* 201: 105417) "argue that both AL and level-k reasoning are necessary to fit their data". Khaw, Stevens and Woodford (2019 WP, "Adjustment dynamics during a strategic estimation task") test for level-k and find heterogeneous depths. — [EGM final draft](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Mauersberger, F. (2021), "Monetary policy rules in a non-rational world: A macroeconomic experiment", *JET* 197: 105203. An NK LtFE in which subjects forecast their own optimal consumption and prices. The search-result summary describes noisy adaptive learning, reinforcement learning and Thompson-sampling fits, but no level-k analysis. — [IDEAS](https://ideas.repec.org/a/eee/jetheo/v197y2021ics002205312100020x.html)

### Inferences
- The literature splits by use case. Level-k with a frozen status-quo level 0 is built for one-time announcements and unprecedented scenarios. Level-k on a learned level 0 (EGM; BCL's adaptive seed; Qiu's backward-anchored level 0) fits recurrent business-cycle settings, which is where hetlearn and SW07 live.
- Shallow reasoning (Angeletos–Sastry) is the most tractable member of the family: in effect a horizon-invariant scalar λ on FIRE expectations of others' actions. It is a cheap benchmark to set beside a full level-k implementation.

### Gaps
- I found no Hommes-coauthored LtFE paper that estimates level-k shares. That literature mostly estimates heuristic switching (adaptive, trend-following, anchoring); see Q6.
- I did not open Angeletos–Lian (2018), Angeletos–Sastry (2021) or Gibbs–McClung (2023) in full. The characterizations above come from the Angeletos–Lian handbook chapter, BEG, EGM and abstracts.
- Woodford (2013) is characterized from its abstract only.

## Q3. How are level 0, level k and population shares specified in each paper?

### Takeaway
- **Level 0** takes one of three forms. It can be the status-quo (pre-shock) equilibrium path (FW, BEG, IS, GSW), a backward-looking rule (BCL adaptive; Qiu "anchored to the last period"), or a learned forecast (EGM, constant gain). Salient values (Nagel's midpoint; EGM's instruction-sheet price) appear only in experiments.
- **Level k** has two dynamic constructions:
  - (i) Path iteration in deterministic perfect-foresight experiments: level-k beliefs = the whole equilibrium path of the level-(k−1) economy (FW, GSW, BEG, IS).
  - (ii) Period-by-period temporary equilibrium with state-contingent rules: level-k perceived functions of the state = actual functions of the level-(k−1) economy (Qiu; EGM's Markov-state NK; BCL's static game each period).
- **Shares** take five forms:
  - one representative level (FW, BCL baseline, BEG baseline, Qiu with interpolation);
  - a fixed distribution of Nagel-type levels, e.g. Poisson (GSW, IS);
  - cognitive hierarchy with normalized beliefs (CHC; BCL appendix; BEG "generalized level-k");
  - shallow reasoning λ (Angeletos–Sastry);
  - endogenous shares via replicator dynamics on forecast errors (EGM).

### Cited Findings
**Indexing conventions differ**
- FW: "Level-1 thinking assumes that agents expect the path for future output to remain as in the original rational-expectations equilibrium". Their recursion starts at k = 0 with {Ŷ^0_t} = {Y_t}, the old REE path. — [FW NBER WP](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf)
- BEG: "level-1 people believe that output will stay at its pre-shock level, i.e., Y^{e,1}_t = 1. This assumption is consistent with the approach in Farhi and Werning (2019)". IS: level-1 beliefs = the "status quo", the REE without policy actions. — [BEG 2021 draft](https://conference.nber.org/conf_papers/f152765/f152765.pdf); [IS 2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf)
- BCL, EGM and Qiu call the naive rule "level 0" and its best response "level 1". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf); [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf); [Qiu](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- Angeletos–Lian: "For k = 0, behavior is exogenously specified". FW's normalization c^0 = 0 means "level-1 thinkers understand PE but not GE". — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)

**Level-0 choices**
- FW motivate the status quo as "a natural focal point to start to reason through the effects of the policy". They are "interested in relatively unfamiliar scenarios ... where learning protocols that converge to rational expectations cannot be naturally invoked ... Our modeling of expectations is entirely forward-looking and deductive." — [FW NBER WP](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf)
- GSW: reflection "starts from some initial 'naive' conjecture about average expectations e_t(0)", which "might be based on the forecasts that would have been correct, but for the occurrence of the unusual shock and/or the change in policy". — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)
- EGM: "Natural level-0 beliefs will depend on the model": a salient value (Nagel), the previous equilibrium before a structural change, or values "determined adaptively by looking at past data". In their dynamics, E^0_{t-1}y_t = a_{t-1} with a_t = a_{t-1} + γ(y_t − a_{t-1}). In the experiment the classification uses "the average of the two most recent prices", and results hold under five alternative level-0 definitions, including three constant-gain specifications. — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Qiu: "Level-0 households and firms fully anchor their spending [and] pricing decisions to the last period", invoking the principle that level-0 agents "should be as 'dumb' as possible". Timing is set so that agents do not update expectations until after decisions. This "isolates the eductive learning". — [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- BCL: the level-0 seed is the adaptive E^0_{t-1}(π̂_t) = π̂_{t-1}, E^0_{t-1}(N̂_t) = N̂_{t-1}. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)
- Angeletos–Lian: the level-0 choice is "a 'free variable'". With feedback outside (−1, 1), "the sensitivity of the level-k outcome to a free parameter (the arbitrarily chosen level-0 outcome) explodes". — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)

**Level k in dynamic models**
- FW (path iteration): "the level-k equilibrium {R̂_t, Ŷ^k_t} is defined as a temporary equilibrium given beliefs {Ŷ^{e,k}_t} = {Ŷ^{k-1}_t}". Each period solves Ŷ^k_t = C({R̂_{t+s}}, Ŷ^k_t, {Ŷ^{k-1}_{t+1+s}}), and current income is observed so markets clear. The setup has no aggregate uncertainty after t = 0 ("an MIT shock"), so RE equals perfect foresight. — [FW NBER WP](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf)
- GSW: a reflective equilibrium of degree n is a temporary equilibrium "using the average subjective expectations e_0(n) at the stage n at which the belief revision process is terminated". The entire path is realized only if reflection "is only undertaken once". "More generally, one might suppose that at each date the outcomes result from a process of reflection ... starting from an initial conjecture that may have been modified relative to the one used in previous periods". GSW analyze only the one-time process. — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)
- Qiu (state-contingent): "Perceiving others as one level below is equivalent to using the actual equilibrium objects of this level as perceived equilibrium objects". Level-(j+1) perceived objects (Y, π, W, D, R, H) = actual level-j objects, all functions of the aggregate state S. The perceived law of motion H^{e,(k)} is iterated forward for multi-step forecasts, a feature Qiu likens to Eusepi–Preston infinite-horizon learning. A temporary-equilibrium map T takes perceived objects to actual objects, and the result has a state-space representation. — [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- EGM in the NK model: "we, as usual, interpret E_t x_{t+1} and E_t π_{t+1} in (7) and (8) as the average expectations across agents ... the current period best response functions over which the agents do level-k deductions". They note this is standard in macro LtFEs (Mokhtarzadeh and Petersen 2021, *Experimental Economics* 24: 883–918; Kryvtsov and Petersen 2021, *JME* 117: 760–780), and that Preston (2005) gives an infinite-horizon alternative. Level-0 forecasts are not state-contingent ("E^0_{t-1}[y_t] = a^y_{t-1}, regardless of the value of z_t"), while level-k ≥ 1 forecasts condition on the Markov state z_t. — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- EGM footnote 7: "any changes to μ or β known at time t − 1 that occurs in time t are built directly into the forecasts of agents for which k ≥ 1". — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)

**Population shares**
- FW, BCL baseline and BEG baseline use one representative level k. — [FW](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf); [BCL](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf); [BEG](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- GSW: the belief-revision ODE integrates to e(n) = exp[n(Ψ − I)]e(0) = Σ_k s_k(n)e(k), with s_k(n) = e^{−n}n^k/k!. "Hence a reflective equilibrium of degree n involves the same average expectations ... as a model in which fraction s_k(n) of the population is made up of level-k thinkers", with n the mean level. GSW add that CHC "also define the discrete 'levels of thinking' in a different way than is standard in the 'level-k' literature". — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)
- IS: the population is divided into groups by level with mass f(k), Σf(k) = 1, "Following García-Schmidt and Woodford (2019)". Varying the mean of f gives continuous comparative statics. CH "can [be] incorporate[d] ... at the expense of tractability. The main results will be unchanged." — [IS 2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf)
- BEG "generalized level-k" (CH-based, representative agent): level k believes others are spread over levels 0..k−1 according to f_k(j). With the CH consistency condition and λ_k ≡ f_k(k−1), beliefs follow y^{e,k}_t = (1−λ_k)y^{e,k−1}_t + λ_k y^{k−1}_t. "Standard level-k thinking corresponds to the case of λ_k = 1". Illustrations use λ = 0.5. Level-0 agents keep acting as before the shock. — [BEG 2021 draft](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- BCL CH appendix: true shares f across k+1 levels, with subjective beliefs over lower levels normalized from f (Camerer et al.). — [IMF WP/26/97](https://www.imf.org/-/media/files/publications/wp/2026/english/wpiea2026097-source-pdf.pdf)
- Qiu allows non-integer k: "a level-1.3 agent perceiving 30% of the others as level-1 and the rest as level-0". This is implemented as linear interpolation of perceived objects between levels j and j+1, which "is different from [a] 30% probability that all others are level-1". — [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- Shallow reasoning (Angeletos–Sastry, as presented by Angeletos–Lian): every agent believes a fraction λ of others are like herself and 1−λ play c = 0. This is "equivalent ... to a variant of Cognitive Hierarchy in which the actual distribution of types has mass 1 at k = ∞, while the corresponding subjective beliefs have mass 1−λ at k = 0 and λ at k = ∞". — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)
- EGM endogenous shares: weights ω_k evolve by a replicator dynamic. The time-t optimal level is k̂(y_t) = min argmin_k |E^k_{t-1}y_t − y_t|, and weight moves from suboptimal levels to k̂ at a rate r(|forecast error|) (example r(x) = (2/π)arctan(ψx)). The largest level is endogenous: "agents are allowed to consider reasoning depths that have never been played". — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)

### Inferences
- For hetlearn the user's numbering (level 0 = PLM) matches BCL, EGM and Qiu. When comparing with FW, BEG or IS, shift their indices down by one.
- hetlearn re-solves every quarter with state-contingent forecast rules, so the construction that fits is (ii): Qiu's recursive level-k equilibrium and EGM's Markov-state version. Path iteration (i) is the right tool only for announced deterministic paths, such as forward-guidance IRFs (Q8).
- In a state-contingent linear model, "a Poisson mixture of Nagel-type levels" and "GSW's continuous ODE" are not exactly the same object. GSW's equivalence uses a map Ψ that is linear in the belief sequence. A T-map on forecast-rule coefficients is nonlinear, because current outcomes depend on coefficient-weighted current variables through an inverse (Q5). hetlearn should implement shares explicitly, as IS and BCL do, rather than via the ODE.

### Gaps
- I did not see a paper with CH shares that are both Poisson and estimated in a dynamic macro model.
- The CHC paper's exact definition of the normalized beliefs g_k(h) = f(h)/Σ_{l<k}f(l) is taken from BCL's and BEG's descriptions, not from my own reading of the CHC text.

## Q4. Does level k converge to RE as k grows, and when does it not (indeterminacy, E-stability links)?

### Takeaway
Discrete level-k converges to RE when the T-map is a contraction near the REE, i.e. iterative E-stability. With negative feedback (strategic substitutes, e.g. an aggressive policy rule) the levels can oscillate, and they explode if the derivative has modulus above one. Continuous reflection (GSW) converges under the weaker E-stability condition: eigenvalues of (Ψ − I) with negative real parts. In GSW's NK model this condition is equivalent to the Taylor principle, and it fails under a long peg. Level-k outcomes are unique for each finite k even when the REE is indeterminate, so level-k also works as an equilibrium-selection device.

### Cited Findings
- Angeletos–Lian: c^k = Σ_{j=0}^{k−1} α^j φ + α^k c^0. With α ∈ (−1, 1), c^k → c^FIRE "regardless of c0", but "for any k < ∞, c^k remains anchored to c0". With c^0 = 0 and α > 0, GE attenuation holds for every finite k. With α < 0 it holds only for odd k, and even-k thinkers "over-estimate the responses of others". Angeletos–Lian call this "a bug, not a feature" and show that reflective equilibrium removes it: the conjecture "never overshoots", and the weight Λ(k, α) rises monotonically from 0 to 1. Cognitive hierarchy "produces basically the same predictions for aggregate beliefs and aggregate outcomes" as reflective equilibrium. — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)
- GSW: the discrete sequence {e(k)} can "fail to converge as k is made large, owing to the existence of a negative eigenvalue of absolute value greater than one, resulting in explosive oscillations". The continuous process avoids this, "though ... it still allows for belief revision dynamics that may fail to converge". GSW tie their process to Evans–Honkapohja E-stability: a map from perceived to actual laws of motion plus a differential equation. In their NK model the Taylor principle is a sufficient condition for Tr[M − I] < 0 and, "given our other sign assumptions", necessary and sufficient for convergence to the forward-stable PFE. Under a permanent peg (zero response coefficients), M − I has a positive real eigenvalue, so beliefs diverge and approach no PFE. With finite reflection, a longer or lower peg still raises output and inflation, and PFE magnitudes "are likely to be upper bounds". — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)
- FW: "When prices are rigid, level-k converges to rational expectations when k goes to ∞. When prices have some degree of flexibility, each level-k equilibrium remains uniquely determined, but the convergence depends on the monetary policy rule. We obtain convergence with a Taylor rule." Level-k "sidesteps issues of indeterminacy" and acts as "a selection device which isolates a particular rational expectations equilibrium in the limit". — [FW NBER WP](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf)
- EGM (y_t = μ + β Σ ω_k E^k y_t). Unified dynamics converge to the REE if |β| < 1 and diverge if β > 1. With β < −1, "odd levels of reasoning introduce negative feedback while even levels result in positive feedback", and outcomes are hard to predict. Under the replicator with a fixed level 0 and |β| < 1, optimal levels and weight drift toward ever higher levels. Under adaptive dynamics with β < −1, stability depends on the weight system and the gain. — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Eductive stability is "closely related to the iterative expectational stability conditions developed in Evans (1985), a connection developed explicitly in Evans and Guesnerie (1993)". The RBC model is not eductively stable but is stable under adaptive learning (Evans, Guesnerie and McGough). — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Qiu: "The recursive level-k equilibrium is well defined only if it converges to the recursive competitive equilibrium when k → +∞. This property does not hold in real business cycles ... because households respond too aggressively to interest rate expectations". He adds incomplete markets (shorter planning horizons) to restore it. — [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- Gibbs–McClung: bounded forward-guidance responses are governed by conditions that are a special case of E-stability and "distinct from determinacy". CNB slides add that indeterminacy does not imply a forward guidance puzzle. — [IDEAS (BoF DP)](https://ideas.repec.org/p/zbw/bofrdp/rdp019.html); [CNB slides](https://www.cnb.cz/export/sites/cnb/en/economic-research/.galleries/seminars_workshops/download/Gibbs.pdf)
- BCL: the RE limit requires θ_t ∈ (0, 1]. Under RE with θ = 0 there are "uniqueness issues"; announcing a constant nominal rate "would lead to indeterminacy". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf)

### Inferences
- Linear-DSGE condition (derivation, see Q5). Take the T-map F ↦ (A0 − A2F)^{-1}A1 on the MSV coefficient F (t-dated information). Its Jacobian at the RE solution F* is vec(dT) = (F*′ ⊗ M A2) vec(dF), with M = (A0 − A2F*)^{-1}. The eigenvalues are products λ_i(F*)·μ_j(M A2).
  - Discrete level-k (IE-stability) converges near F* iff all |λ_i μ_j| < 1.
  - Continuous reflection, or a small damping step, converges iff all Re(λ_i μ_j) < 1. This is the usual E-stability test.
  - So IE-stability is stricter than E-stability. An SW07 parameterization can be E-stable, letting hetlearn's learners converge, yet not IE-stable, in which case high-level forecasts oscillate or explode.
- Practical guidance for hetlearn:
  - compute the spectral radius of the level-k Jacobian at the RE solution as a diagnostic;
  - cap K at a small number (the literature uses 1–4);
  - offer a damped or Poisson-mixture option (BEG λ, GSW) that only needs E-stability.
- Level-k outcomes stay unique for finite k under indeterminacy, as FW and GSW show. hetlearn could therefore simulate SW07 under pegs or passive policy with level-k agents, where an RE solver fails. This applies only if no model-consistent RE type is present, because that type needs a determinate fixed point.

### Gaps
- I did not find a published check of IE-stability for an estimated medium-scale model such as SW07 at its posterior mode. Gibbs–McClung claim scalability to medium-scale DSGE, but I did not read their quantitative section.
- The Jacobian formula above is my derivation and has not been checked against Gibbs–McClung's notation.

## Q5. The level-k expectation operator in linear form, and how to compute it

### Takeaway
In every paper, level k is the T-map applied k times to the level-0 belief: E^k = T(E^{k−1}), where T maps a belief to the outcome of an economy populated entirely by agents holding that belief. For a linear model with state-contingent rules this is a backward-looking temporary-equilibrium solve per level: a matrix inversion, with no Blanchard–Kahn step. The recursion is the standard fixed-point iteration for the MSV RE solution, stopped after k steps and started from the level-0 PLM.

### Cited Findings
- EGM (univariate, t−1 information): level-k beliefs "would be optimal if all other agents used level k − 1": E^1_{t-1}y_t = T(a) ≡ μ + βa and E^k_{t-1}y_t = T^k(a). The realized outcome is y_t = μ + β Σ_k ω_k T^k(a). — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- EGM (NK, rigid prices, Markov states S = stagnation and N = normal). Level 0 forecasts a^x_{t-1} in state S and a zero output gap in state N. The level-1 forecast in state S is the IS-curve best response to level-0 forecasts of next period's gap in S and in N, weighted by the transition probabilities, plus a term in the stagnation natural rate r^S. This gives a map that is affine in a^x, with E^k = T^k(a^x_{t-1}|S), and the realized gap x_t follows a closed-form T(a|S) (their eq. 10). The Greek symbols were lost in my text extraction, so I do not reproduce the coefficients. "Level-k deductions expand to include the forward guidance policy and to the multivariate case in the same way". — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- BCL closed form: E^k_{t-1}(π̂_t) = (1−θ_t)^{k−1}[E^0(N̂_t)+E^0(π̂_t)] (Q1). Reflective version: E(x_t) = exp(−kθ_t)x_{t−1}. — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf); [IMF WP/26/97](https://www.imf.org/-/media/files/publications/wp/2026/english/wpiea2026097-source-pdf.pdf)
- GSW (linear map on belief sequences): e(n) = exp[n(Ψ − I)]e(0) = Σ_k s_k(n)Ψ^k e(0), with Poisson weights s_k(n). — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)
- BEG damped recursion: y^{e,k} = (1−λ)y^{e,k−1} + λ y^{k−1}, where y^{k−1} is the outcome of the level-(k−1) economy. — [BEG 2021 draft](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- Qiu: perceived objects at level j+1 = actual objects at level j, all functions of the state. Forecasts iterate the perceived law of motion: S^{e,(k)}_{t+s|t} = H^{e,(k)}(S^{e,(k)}_{t−1+s|t}, ...). Non-integer k interpolates linearly between adjacent levels. — [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- Shallow reasoning (dynamic NK): replace average subjective expectations of others' future actions with λE_t[c_{t+k}], "just as tractable as the FIRE benchmark". Gabaix's cognitive discounting gives Ẽ_t[c_{t+k}] = m^k E_t[c_{t+k}]. — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)

### Inferences
All formulas below are my derivations for a hetlearn-style linear model, not taken from a single paper. They follow Qiu's "perceived = actual one level below" and EGM's T-map.

**Model.** A0 y_t = A1 y_{t−1} + A2 Ê_t y_{t+1} + B ε_t. Shocks with persistence sit inside y. Ê is the population-average subjective expectation, and only the rows/columns selected for heterogeneous expectations are replaced (selection matrix S); keep the rest at RE as hetlearn does now.

**Level 0.** E^0_t y_{t+1} = a_0 + F_0 y_t (t-information) or a_0 + F_0 y_{t−1} (t−1 information). (a_0, F_0) are the PLM coefficients embedded in full-state form, either fixed or RLS-updated each quarter. A univariate AR(1) PLM for x is a sparse F_0.

**Homogeneous level-j economy, t-information** (the temporary equilibrium solves the simultaneity):
- M_j = (A0 − A2F_j)^{-1}; c_j = M_j A2 a_j; H_j = M_j A1; G_j = M_j B, so that y_t = c_j + H_j y_{t−1} + G_j ε_t.
- Level-(j+1) agents believe this ALM and observe y_t, so E^{j+1}_t y_{t+1} = c_j + H_j y_t, i.e. a_{j+1} = c_j and F_{j+1} = H_j.
- Recursion: F_{j+1} = (A0 − A2F_j)^{-1}A1 and a_{j+1} = (A0 − A2F_j)^{-1}A2 a_j. This is the brute-force iteration for the MSV RE solution F = (A0 − A2F)^{-1}A1, stopped at k.

**t−1 information** (no simultaneity):
- H_j = A0^{-1}(A1 + A2F_j); c_j = A0^{-1}A2 a_j.
- Two-step forecast from t−1: E^{j+1}y_{t+1} = (I + H_j)c_j + H_j² y_{t−1}, so F_{j+1} = H_j² and a_{j+1} = (I + H_j)c_j.

**Fixed shares ω_0..ω_K of Nagel-type levels:**
- Ê_t y_{t+1} = Σ_k ω_k(a_k + F_k y_t).
- Actual ALM: y_t = (A0 − A2 Σ ω_k F_k)^{-1}(A1 y_{t−1} + A2 Σ ω_k a_k + B ε_t).
- Cost: K+1 inversions per period. This is hetlearn's n1·E^RE + n2·E^BR with "anchored RE" (forecast = F_RE·state) generalized to K+1 anchors F_0..F_K.

**Cognitive hierarchy:**
- Level k believes the population is the mix of levels 0..k−1 with g_k(h) = ω_h / Σ_{l<k} ω_l.
- F_k = (A0 − A2 Σ_{h<k} g_k(h)F_h)^{-1}A1, with the analogous a_k. Still K inversions per period.
- Poisson CH: ω_h = e^{−τ}τ^h/h!, truncated at K and renormalized.

**Damped / reflective variant:**
- F^{(j+1)} = F^{(j)} + λ[T(F^{(j)}) − F^{(j)}] (BEG-style). A small λ with many steps approximates GSW's ODE.
- This converges whenever the REE is E-stable (Q4), not only when it is IE-stable.

**Special cases:**
- If level 0 is the RE solution (F_0 = F*), all levels coincide (T(F*) = F*). Level-k matters only when level 0 differs from RE: a learned PLM, the steady state (a = 0, F = 0), an old-regime RE solution after a regime change, or beliefs that ignore an announced change.
- Higher levels forecast with the full state vector, including shocks, even when the level-0 PLM is a low-dimensional AR(1). Level ≥ 1 agents therefore carry the same strong information assumption as hetlearn's anchored-RE agents.

**Cost.** Per period, K inversions of an n×n matrix, roughly n ≈ 40–70 for SW07 with the flex-price block. Inside a Kalman filter at T ≈ 200 and K ≤ 5 this is negligible next to the existing per-quarter re-solve.

### Gaps
- No paper I read writes the multivariate state-contingent recursion in exactly this matrix form. Qiu's appendix "general algorithm" and EGM's appendix T-map for the bivariate NK case are the closest, and I did not read either appendix.
- How the law of iterated expectations fails for multi-step forecasts (Qiu: "the forecasts of the forecasts of others are not identical to the direct forecasts") matters only if hetlearn uses infinite-horizon (Preston) forecasting. I did not work it out.

## Q6. Has any level-k or cognitive-hierarchy DSGE been estimated on macro or survey data?

### Takeaway
Only one paper estimates a level-k DSGE on macro plus survey data with Bayesian methods: Qiu's 2018 job market paper, which is unpublished. It is small-scale, with k posterior mean 1.265 and 95% band [1.197, 1.327], identified with Michigan Survey forecasts. Iovino–Sergeyev back out an implied share of 86% "level-1" thinkers from Blue Chip forecast errors after mortgage purchases. EGM fit unified dynamics to lab data. BCL, FW and BEG calibrate (k = 1–4; λ = 0.5). I found no estimated medium-scale (SW07-size) level-k or CH model. The closest estimated bounded-rationality alternatives are finite-horizon planning (Gust–Herbst–López-Salido 2022) and cognitive discounting combined with learning (Meggiorini–Milani 2021).

### Cited Findings
**Qiu (2018)**
- Method: Bayesian, with a state-space system built on the actual and perceived laws of motion of the recursive level-k equilibrium.
- Data, five series: quarterly GDP growth, GDP-deflator inflation, the federal funds rate, one-year-ahead growth forecasts ("imputed from the aggregate index of business condition change"), and one-year-ahead inflation expectations. Measurement errors are on the two survey series.
- The planning-horizon parameter is set to 0.93 to match an unconstrained-household MPC of 7% (Kaplan–Violante).
- Prior on k: "Uniform 1/k", covering [1, ∞). Posterior mean k = 1.265, 95% band [1.197, 1.327]. Qiu notes it "is close to the results in experimental games as in Camerer et al. (2004)".
- Identification: "The missing co-movements for indirect channels identify k ∈ [1, 2], while the weakened direct channels help identify the exact value of k."
- As k → ∞ the model reduces to a basic NK model (Galí 2015).
- [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)

**Other estimates and fits**
- A search-result summary says Qiu's thesis version reports k = 1.334 "from similar data". I did not open the thesis. — [UPenn repository (Qiu)](https://repository.upenn.edu/entities/person/936cd1ba-f146-44d0-9805-d50000b1b32f)
- Iovino–Sergeyev:
  - Narratively identified GSE mortgage purchases (Fieldhouse–Mertens–Ravn) move mortgage rates and predict Blue Chip Financial Forecasts mortgage-rate forecast errors.
  - "Using these empirical estimates together with our stylized model, we calculate that the number of level-1 thinkers (those who do not change their expectations after policy interventions) in the data is 86 percent" (2019 draft).
  - [IS 2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf)
- EGM (lab):
  - Classification: within ±3 of a model-implied level-0..3 or REE forecast, 47.3% of forecasts are classified in the first announcement round and 64.4% and 66.0% in later announcements. The authors summarize this as "about half" rising to "approximately two-thirds".
  - Fit: models are fitted by grid search over the gain and the replicator parameter, minimizing price MSE. Unified-model MSE relative to RE is 0.45 (T1, β = −0.9), 0.93 (T2, β = −2) and 0.53 (T3, β = 0.5).
  - Comparison models: fixed level-k scores 0.94, 8.16 and 0.56; replicator-only 0.74, 1.37 and 1.33; adaptive learning 1.69, 1.22 and 1.36.
  - The authors conclude that "each of underlying mechanisms – adaptive learning, level-k and replicator dynamics – are needed".
  - [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- EGM's NK simulation uses gain 0.2 and replicator parameter 500. By period 10 "the use of level-0, 1, 2, and 3 forecasts is still above 30%", and low-level reasoning lowers the power of forward guidance. — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Calibrations elsewhere:
  - BCL use k = 2, citing FW's range of 1–4 and experimental "low single digits".
  - BEG illustrate with λ = 0.5.
  - GSW, FW and IS report comparative statics in n or k without estimation.
  - Sources: [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf); [BEG 2021 draft](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- CHC: τ ≈ 1.5 average steps fits many experimental games. — [CHC article copy](https://www.csc2.ncsu.edu/faculty/mpsingh/local/Social/f24/wrap/readings/Camerer+Ho+Chong-cognitive-hierarchy-of-games-2004.pdf)
- Caveat from games: Cooper, Fatas, Morales and Qi (AEJ: Micro 2024, per search-result summary) find depth of reasoning inconsistent across game classes. — [UEA eprints](https://ueaeprints.uea.ac.uk/id/eprint/93018)

**Nearby estimated alternatives**
- Gust, Herbst and López-Salido (2022), "Short-Term Planning, Monetary Policy, and Macroeconomic Persistence", *AEJ: Macro* 14: 174–209. Finite-horizon planning model estimated on aggregate data. Per the search-result summary of the abstract, it "outperforms rational expectations versions of the NK model ... as well as other behavioral NK models". Working-paper drafts report planning horizons under two years. — [AEA DOI page](https://www.aeaweb.org/doi/10.1257/mac.20200058); [FEDS version](https://www.federalreserve.gov/econres/feds/short-term-planning-monetary-policy-and-macroeconomic-persistence.htm); journal pages from the [Dupraz–Marx reference list](https://www.clevelandfed.org/-/media/project/clevelandfedtenant/clevelandfedsite/events/inflation-dynamics-and-drivers/2024/dupraz_anchoringboundedlyrationalexpectations.pdf)
- Meggiorini and Milani (2021), "Behavioral New Keynesian Models: Learning vs. Cognitive Discounting", CESifo WP 9039 / UC Irvine WP 202103. Per the search-result summary, under RE and infinite-horizon learning the data call for implausibly large myopia, while under Euler-equation learning "the model fits the data with little estimated myopia". — [CESifo page](https://www.cesifo.org/en/publications/2021/working-paper/behavioral-new-keynesian-models-learning-vs-cognitive-discounting)

### Inferences
- An estimated SW07 with level-k or CH expectations (k, τ or λ estimated jointly with learning gains and Brock–Hommes parameters) appears to be a genuine gap. Özden-style hetlearn estimation would be new.
- Identification is likely to need survey data. Qiu identifies k from survey forecasts' missing "indirect channels". Iovino–Sergeyev use forecast errors. EGM use individual forecasts. With macro data only, k (or τ) and the learning gain both govern how fast beliefs respond and may be weakly separated.
- Integer k is awkward for MCMC. Usable continuous embeddings are Qiu's interpolation, GSW/CH Poisson τ, BEG's λ, or BCL's exponent form.

### Gaps
- I did not find any estimation of reflective-equilibrium degree n on macro data.
- I did not check whether García-Schmidt and coauthors estimated a reflective-equilibrium model for Chile.
- I did not verify Gust–Herbst–López-Salido's exact horizon estimates or the details of Meggiorini–Milani beyond the abstract summaries.

## Q7. Can level-k be combined with adaptive learning (learned level 0, re-solved each period) and with cognitive discounting?

### Takeaway
Yes for learning, and this is published and experimentally supported. In EGM, level-0 forecasts are learned with a constant gain, levels k ≥ 1 are T^k of the learned level 0 each period, and replicator dynamics move shares across levels. BCL and Qiu also seed level-k with a backward-looking level 0. Iovino–Sergeyev show that letting level 0 learn makes the economy unravel to RE. The view that level-k and adaptive learning are alternatives fits only FW/GSW-style models with a frozen status quo. Cognitive discounting has been combined with learning (Meggiorini–Milani; Woodford's finite horizons with learning, as discussed by Dupraz–Marx). I found no paper combining cognitive discounting with level-k, and Angeletos–Lian treat it as a "close cousin" that delivers the same GE damping.

### Cited Findings
**Level-k with learning**
- EGM: "Level-0 forecasts evolve over time via adaptive learning. Agents revise over time their depth of reasoning in response to forecast errors, observed and counterfactual". They define "adaptive dynamics" (learning with fixed level-k weights), "replicator dynamics" (fixed level 0, evolving weights) and "unified dynamics" (both). "Because AL does not require knowledge of the model's structural parameters, it provides a natural level-0 benchmark". In their menu framing, the Brock–Hommes predictor menu "is the full set of level-k forecasts, with agents' choices based on recent forecast performance". — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- FW's closing remark, as quoted by EGM: "Modeling how level-k agents react when they see unexpected realizations would require some hybrid of level-k reasoning and learning that is beyond the scope of the current paper". EGM present their model as that hybrid. — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- EGM: with repeated structural change, low-level reasoners persist. This supports "macroeconomic models that rely on low levels of reasoning to moderate general equilibrium effects". — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- Iovino–Sergeyev, Appendix C.4: a simple learning process for the starting point produces "equilibrium unraveling" toward the REE. Asset purchases must then grow to keep a constant effect, so repeated rounds of QE "may turn out to be less effective". Adding RE agents does not restore neutrality and can amplify effects. — [IS 2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf)
- GSW: a discrete version of reflection can also be read as learning across repeated episodes of the same shock and policy scenario. There "it is the working of the economy that computes Ψ(e)". — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)
- Angeletos–Lian: "Level-k Thinking is significantly more manageable, as illustrated in Farhi and Werning (2019), because it shuts down any adjustment in beliefs". — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)
- BCL's level 0 is adaptive, so LKT "nests both adaptive and rational expectations". Qiu's level 0 is anchored to last period's decisions and deliberately "assumes away other forms of learning". — [NBER WP 31741](https://www.nber.org/system/files/working_papers/w31741/w31741.pdf); [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- Calculation equilibrium: Evans and Ramey (1992, 1995, 1998) let agents iterate on expected paths and weigh calculation costs against forecast errors, so depth is endogenous. FW and GSW both cite it as a precursor. — [FW NBER WP](https://www.nber.org/system/files/working_papers/w23281/w23281.pdf); [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf)

**Cognitive discounting**
- Angeletos–Lian: in Gabaix's (2020) model the behavioral agent perceives the law of motion as m·(Ax_{t−1} + Bε_t), which gives Ẽ_t[c_{t+k}] = m^k E_t[c_{t+k}]. This "shares with all the other approaches in this chapter" the under-reaction of expectations of others' actions. "One subtle difference is that this kind of under-reaction is predicted to increase with the horizon of forecasts", whereas under Angeletos–Sastry λ "is invariant to the forecast horizon". — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf); Gabaix (2020), *AER* 110: 2271–2327, per the [BEG reference list](https://conference.nber.org/conf_papers/f152765/f152765.pdf); [Gabaix NBER WP 22954](https://www.nber.org/system/files/working_papers/w22954/w22954.pdf)
- Dupraz–Marx: finite planning horizons plus long-term learning "generalizes both cognitive discounting models and learning models". Citing Gust, Herbst and López-Salido, they say it "does a very good job at capturing the dynamics of expectations in surveys". — [Dupraz & Marx](https://www.clevelandfed.org/-/media/project/clevelandfedtenant/clevelandfedsite/events/inflation-dynamics-and-drivers/2024/dupraz_anchoringboundedlyrationalexpectations.pdf)
- Meggiorini–Milani combine cognitive discounting with infinite-horizon or Euler-equation learning in an estimated NK model. The estimated myopia is sensitive to how expectations are modeled (search-result summary). — [CESifo page](https://www.cesifo.org/en/publications/2021/working-paper/behavioral-new-keynesian-models-learning-vs-cognitive-discounting)

### Inferences
- The user's statement "level-k and adaptive learning are alternatives, we have to pick one" is not borne out. The published unified model makes the adaptive learner level 0 and builds levels 1..K on it each period. hetlearn's BR learners are the natural level-0 agents. The real design choice is between two models:
  - **(a) Frozen status-quo level 0 (FW/GSW).** Suited to one-off announcements. hetlearn could set level 0 to the steady state or the pre-announcement RE solution.
  - **(b) Learned level 0 (EGM).** Suited to estimation on business-cycle data.
- Within (b), a second choice is whether shares are fixed (EGM's "adaptive dynamics") or move with forecast performance (replicator, or hetlearn's Brock–Hommes logit). In stationary environments with |feedback| < 1, EGM's results imply that switching drifts mass toward high levels, i.e. toward RE. Persistent low levels need repeated structural change or noise.
- Cognitive discounting can be layered on any agent's forecast as a multiplicative shrink, m^h on deviations from steady state. That is mechanically trivial in hetlearn. The user is right that it combines with either mechanism, but it overlaps conceptually with level-k: both damp GE feedback, and the main empirical difference is the horizon profile (m^h versus flat). With one-step-ahead (Euler-equation) expectations the horizon profile hardly shows, so m and k/τ may be poorly identified jointly. Meggiorini–Milani's finding that cognitive discounting and learning substitute in estimation points the same way.

### Gaps
- No paper found that combines level-k (or CH) with Gabaix cognitive discounting.
- No paper found that combines level-k with an endogenous-gain learner or with Brock–Hommes logit switching across levels. EGM use a replicator with an arctan rate function, not a logit.

## Q8. Mapping to hetlearn (anchored/model-consistent RE + PLM learners + Brock–Hommes switching + per-quarter re-solve + time-varying Kalman filter)

### Takeaway
A basic version is easy: for a given PLM, levels 0..K with user-chosen fixed shares. It reuses the per-quarter "solve for beliefs in force" step, which is the T-map, and the anchored-RE forecasting code with the anchor replaced by the ALM of the level-(k−1) economy. That costs K matrix inversions per quarter. The user's analogy (level-1 = anchored RE with a different anchor model) is correct. Medium effort: CH or Poisson shares, damped (reflective) levels, Brock–Hommes switching across levels, and continuous-k estimation. Hard: path-based level-k for announced policy paths, and identifying k separately from the learning gain without survey data.

### Cited Findings
- Qiu: "Perceiving others as one level below is equivalent to using the actual equilibrium objects of this level as perceived equilibrium objects". This is the anchored-RE-with-different-anchor construction. — [Qiu JMP](https://economics.sas.upenn.edu/system/files/2018-03/Zhesheng%20(JMP%2001-30).pdf)
- EGM: level 0 is learned adaptively, and levels k ≥ 1 incorporate structural changes known at t−1 that level 0 ignores. Expectations in the IS and Phillips curves are read as cross-agent averages over which level-k deductions are made, the same Euler-equation convention hetlearn uses. — [EGM](https://pages.uoregon.edu/gevans/EGM_Unified_Model_AEJM_Final_Dec2023.pdf)
- GSW/IS: shares as a distribution over levels, e.g. Poisson(n), with n the mean level and continuous. — [GSW NBER WP](https://www.nber.org/system/files/working_papers/w21614/w21614.pdf); [IS 2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf)
- BEG: the damped CH recursion with λ removes oscillation in their parameterization. — [BEG 2021 draft](https://conference.nber.org/conf_papers/f152765/f152765.pdf)
- Iovino–Sergeyev: RE agents can coexist with level-k agents. — [IS 2019 draft](https://www.suomenpankki.fi/globalassets/bof/en/research/seminars-and-conferences/conferences-and-workshops/documents/cepr2020/iovino_luigi_12518_41615_paper_1.pdf)
- Angeletos–Lian: incomplete information is computationally hard in dynamic settings, while level-k "is significantly more manageable". — [AL handbook chapter](https://nber.org/system/files/working_papers/w29776/w29776.pdf)

### Inferences
Difficulty ratings and reuse below are my assessment.

| Feature | Difficulty | What it reuses in hetlearn | Notes |
|---|---|---|---|
| Single representative level k on a fixed level 0 (steady state, old-regime RE solution, or fixed PLM) | Easy | The per-quarter re-solve, i.e. the T-map F ↦ (A0 − A2F)^{-1}A1, run k times; anchored-RE forecast code with the anchor F_{k−1} | Can be precomputed once if level 0 is time-invariant. Level 0 = current RE solution gives back RE exactly (fixed point). |
| Levels 0..K on a learned PLM (EGM "adaptive dynamics") | Easy–Medium | RLS / constant- or endogenous-gain PLM updating as the level-0 learner; K T-map evaluations per quarter; projection facility on the level-0 PLM | Add a stability guard: check the spectral radius of each H_j and fall back to a capped K or damping. |
| User-specified fixed shares ω_0..ω_K (Nagel-type) | Easy | Population-mix code (n1·E^RE + n2·E^BR) generalized to K+1 types | Exactly the user's proposal ("specify the PLM, the level, the shares"). |
| Poisson shares with mean τ | Easy | Same, with ω_k(τ) truncated and renormalized | Gives a continuous parameter for MCMC. In this coefficient-space setting it is not identical to GSW's ODE (Q3). |
| Cognitive hierarchy (each level responds to the normalized lower distribution) | Medium | K solves of mixed lower-level economies | More bookkeeping; same cost order. |
| Damped / reflective levels (BEG λ; discretized GSW) | Medium | T-map iteration with relaxation | Needs E-stability rather than IE-stability, so it is safer for SW07. |
| Brock–Hommes switching across levels (EGM-like, logit instead of replicator) | Medium | Existing BH discrete-choice code with K+1 predictors; each level's counterfactual forecast error is available each quarter | Expect mass to drift to high levels in stationary samples (EGM Theorem 2). |
| Mixing levels with hetlearn's model-consistent RE type | Medium | Existing fixed-point solve for RE agents facing BR agents; level-k forecasts are linear in the state like PLM forecasts | Level-k agents mis-perceive the economy (they think others are lower). Only the RE type knows the true mixed law of motion. |
| Gabaix m layered on any type | Easy | Multiply forecast deviations by m (or m^h) | Weakly identified jointly with k/τ (Q7). |
| Bayesian estimation of k/τ/λ with gains and BH parameters | Medium (mechanics) / Hard (identification) | Time-varying Kalman filter unchanged; matrices already vary by quarter | Add survey expectations as observables (Qiu: Michigan; IS: Blue Chip forecast errors). Use a continuous embedding for k. |
| Path-based level-k for announced policy (forward guidance, pegs; FW/GSW/BEG) | Hard | Not the per-quarter recursive solver; needs a stacked-time temporary-equilibrium solver over the announced path, or EGM-style Markov-state T-maps | I did not check whether the IRIS version in use exposes a usable stacked-time solver. |

Extra design notes:
- With t-information, every level's ALM needs the simultaneous solve (A0 − A2F)^{-1}. With t−1 information, use the two-step forecast H_j² (Q5).
- The user's remark that "level-k needs k solves per period if level 0 is learned" is right, and each solve is a backward-looking inversion with no Blanchard–Kahn step. If model-consistent RE agents are also present, the existing RE fixed point still dominates the cost.

### Gaps
- I did not check hetlearn's code. Component names and the claim that the per-quarter re-solve is a T-map evaluation rest on the task description.
- I have not tested IE-stability of SW07 at standard posterior values, so how large K can be before oscillation is unknown.
