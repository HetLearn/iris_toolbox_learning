function cfg = v2_var12()
%V2_VAR12  Model variant 2: VAR(1) perceived law of motion in the 12 forward-looking variables.
%
%   cfg = v2_var12()
%
%   As a1_learn with a VAR(1) with constant over the 12 SW07 forward-looking
%   variables. Learning stays on inflation only: the other 11 members are
%   auxiliary VAR equations that feed the inflation expectation (the default
%   gain 0.0585 applies to every equation). Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v2_var12';
cfg.title = 'Variant 2: learning on inflation with a VAR(1) in the 12 forward-looking variables';
cfg.description = 'As a1_learn, with the inflation learners forecasting from a VAR(1) in all 12 forward-looking variables of SW07.';
cfg.beliefs.plm.var = struct('variables', ...
    {{'invef', 'rkf', 'pkf', 'cf', 'labf', 'inve', 'pinf', 'rk', 'pk', 'c', 'lab', 'w'}}, ...
    'lags', 1, 'constant', true);
cfg.compare_with = {'a1_learn'};
end
