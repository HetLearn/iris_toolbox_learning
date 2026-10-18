function cfg = a5_demand_re()
%A5_DEMAND_RE  Application 5: density forecast from the 2022Q2 peak under demand shock uncertainty, RE.
%
%   cfg = a5_demand_re()
%
%   As a5_markup_re with draws of the risk-premium, government-spending and
%   investment shocks (eb, eg, eqs), the demand group of application 6. The
%   monetary shock em is not drawn.

cfg = a5_markup_re();
cfg.id = 'a5_demand_re';
cfg.title = 'App 5: density forecast, demand shock uncertainty, rational expectations';
cfg.description = 'Fan of 500 forecasts from the 2022Q2 peak with random risk-premium, government-spending and investment shocks (normal, calibrated sigma); every agent rational.';
cfg.density.shocks = {'eb', 'eg', 'eqs'};
end
