function cfg = br04_shallow()
%BR04_SHALLOW  BR portfolio 4: shallow reasoning (Angeletos and Sastry 2021), flat multipliers by agent role from Gust, Herbst and Lopez-Salido (2020).
%
%   cfg = br04_shallow()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 4 and the 04
%   row of section 3. The RE type's forward expectations are scaled by a
%   lambda that is the same at every horizon (profile 'flat'), one value per
%   agent role, through equation copies of the inflation expectation:
%   households (c, lab, inve, pk, rk) lambda_h 0.76; price and wage setters
%   (w, inflation in the price and wage Phillips curves) lambda_f 0.86;
%   expected inflation in the real rate (consumption Euler equation, value
%   of capital) lambda_pi 0.08. GHL posterior means of the Angeletos-Lian
%   form, US 1966Q1-2007Q4; the mapping to SW07 equations by agent role is
%   the design's (flagged there). The learners are not transformed; the flex
%   block stays RE (D1). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br04_shallow';
cfg.title = 'BR 4: shallow reasoning, flat multipliers by agent role (GHL values)';
cfg.description = 'As a1_learn, with the RE agents'' forward expectations scaled by 0.76 (households), 0.86 (price and wage setters) and 0.08 (expected inflation in the real rate).';
lam = @(v, sc) struct('kind', 'multiplier', 'profile', 'flat', 'types', {{'RE'}}, 'value', v, 'scope', {sc});
cfg.expectations.transforms = [ ...
    lam(0.76, {'c', 'lab', 'inve', 'pk', 'rk'}), ...                                              % lambda_h
    lam(0.86, {'w', 'pinf@Phillips curve, price setting', 'pinf@Wage Phillips curve, wage setting'}), ...  % lambda_f
    lam(0.08, {'pinf@Consumption Euler equation', 'pinf@Arbitrage equation for the value of capital'})];   % lambda_pi
cfg.compare_with = {'a1_learn', 'a1_re'};
end
