function cfg = br18_degrauwe()
%BR18_DEGRAUWE  BR portfolio 18: targeters and extrapolators for inflation, optimists and pessimists for consumption (De Grauwe 2011).
%
%   cfg = br18_degrauwe()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 18 and the 18
%   row of section 3. Two share groups. Inflation: targeters (TAR, forecast
%   0, the steady state) and extrapolators (EXT, pinf_{t-1}) replace the RE
%   agents and learners. The consumption expectation of the Euler equation:
%   optimists (OPT) and pessimists (PES), each the model-consistent E_t
%   c_{t+1} plus or minus a constant bias g (D6). Fitness on the biased
%   forecasts (phase P4).
%
%   Calibration (user request 2026-10-21; run_br_app1('calib18') writes the
%   search to results/br_portfolio/app1_calib18.csv). The design's values
%   (g = sd(y - yf)/2 = 2.16 in the RE limit, intensity 2, memory 0.8) send
%   the forecast into a deflation spiral. De Grauwe (2011, Economic Theory
%   47; CESifo WP 2418, Appendix A) calibrates in decimal units with months
%   as the time unit: fixed divergence beta = 0.01, variable divergence
%   delta = 2, intensity gamma = 10000, memory rho = 0.5 (weights
%   (1 - rho) rho^k, the toolbox's 'normalized' fitness). In percent and
%   quarters: g = beta/2 = 0.5 (delta = 0, the paper's constant-bias case),
%   intensity gamma/100^2 = 1, memory rho^3 = 0.125. With those values
%   consumption growth swings far outside its 1966-2019 range. Of the 49
%   settings searched, the one used here is the passing setting closest to
%   them: g = 0.25, intensity 0.5, memory 0.125 (the memory as converted;
%   bias and intensity half of the converted values). Writes
%   compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br18_degrauwe';
cfg.title = 'BR 18: De Grauwe targeters/extrapolators (inflation) and optimists/pessimists (consumption)';
cfg.description = 'As a1_learn, with inflation forecast by targeters and extrapolators and the consumption expectation by optimists and pessimists, each group switching.';
cfg.expectations.variables = {'pinf', 'c'};
cfg.expectations.types = { ...
    struct('name', 'TAR', 'kind', 'rule', 'rule', '0', 'variables', {{'pinf'}}), ...
    struct('name', 'EXT', 'kind', 'rule', 'rule', 'x{-1}', 'variables', {{'pinf'}}), ...
    struct('name', 'OPT', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}}), ...
    struct('name', 'PES', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}})};
g = 0.25;                                     % bias, % of steady-state consumption (De Grauwe converted: 0.5)
cfg.expectations.transforms = [ ...
    struct('kind', 'wedge', 'types', {{'OPT'}}, 'factor', struct('mean', g)), ...
    struct('kind', 'wedge', 'types', {{'PES'}}, 'factor', struct('mean', -g))];
cfg.switching.intensity = 0.5;                % per squared percentage point (De Grauwe converted: 1)
cfg.switching.memory = 0.125;                 % per quarter (De Grauwe: 0.5 per month, cubed)
cfg.compare_with = {'a1_learn', 'a1_re'};
end
