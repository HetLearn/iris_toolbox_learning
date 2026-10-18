function cfg = a5_demand_learn()
%A5_DEMAND_LEARN  Application 5: density forecast under demand shock uncertainty, learning on inflation.
%
%   cfg = a5_demand_learn()
%
%   As a1_learn with the density block of a5_demand_re (same draws).

cfg = a1_learn();
d = a5_demand_re();
cfg.id = 'a5_demand_learn';
cfg.title = 'App 5: density forecast, demand shock uncertainty, learning on inflation';
cfg.description = 'Fan of 500 forecasts from the 2022Q2 peak with random risk-premium, government-spending and investment shocks, with inflation expectations a switching mix of RE agents and learners.';
cfg.density = d.density;
cfg.compare_with = {'a5_demand_re'};
end
