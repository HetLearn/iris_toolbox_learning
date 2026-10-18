function cfg = a5_markup_learn()
%A5_MARKUP_LEARN  Application 5: density forecast under mark-up shock uncertainty, learning on inflation.
%
%   cfg = a5_markup_learn()
%
%   As a1_learn with the density block of a5_markup_re (same shocks, sigma,
%   draws and seed, so both runs use the same draws). Each draw re-runs the
%   quarter-by-quarter forecast, so beliefs and shares respond to the drawn
%   shocks (general path, about 0.5-0.9 s per draw).

cfg = a1_learn();
d = a5_markup_re();
cfg.id = 'a5_markup_learn';
cfg.title = 'App 5: density forecast, mark-up shock uncertainty, learning on inflation';
cfg.description = 'Fan of 500 forecasts from the 2022Q2 peak with random price and wage mark-up shocks, with inflation expectations a switching mix of RE agents and learners.';
cfg.density = d.density;
cfg.compare_with = {'a5_markup_re'};
end
