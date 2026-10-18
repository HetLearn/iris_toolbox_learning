function cfg = a5_markup_re()
%A5_MARKUP_RE  Application 5: density forecast from the 2022Q2 peak under mark-up shock uncertainty, RE.
%
%   cfg = a5_markup_re()
%
%   500 draws of the price and wage mark-up shocks (epinf, ew; normal, the
%   model's calibrated standard deviations, seed 0) added to the zero-shock
%   forecast of a1_re over 2022Q3-2026Q2. Under RE without conditions each
%   draw is one linear simulation (density.fast_path). Writes density.mat and
%   density_quantiles.csv. The parent of the other three density files.

cfg = a1_re();
cfg.id = 'a5_markup_re';
cfg.title = 'App 5: density forecast, mark-up shock uncertainty, rational expectations';
cfg.description = 'Fan of 500 forecasts from the 2022Q2 peak with random price and wage mark-up shocks (normal, calibrated sigma); every agent rational.';
cfg.density.enabled = true;
cfg.density.shocks = {'epinf', 'ew'};
cfg.density.sigma = 'calibrated';
cfg.density.method = 'normal';
cfg.density.ndraws = 500;
cfg.density.seed = 0;
end
