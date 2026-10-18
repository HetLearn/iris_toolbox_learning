function cfg = a2_learn()
%A2_LEARN  Application 2: replay of the RE-smoothed shocks 2022Q3-2026Q2, learning on inflation.
%
%   cfg = a2_learn()
%
%   As a2_re (the same shocks), with the baseline learning model: the gap to
%   the data shows how far the learning economy moves from the RE one under
%   the shocks the RE model backs out. Writes compare_a2_re.csv (= learning
%   replay minus data).

cfg = a1_learn();
cfg.id = 'a2_learn';
cfg.title = 'App 2: replay of the RE-smoothed shocks 2022Q3-2026Q2, learning on inflation';
cfg.description = 'The RE-smoothed shocks of 2022Q3-2026Q2 are fed in quarter by quarter, with inflation expectations a switching mix of RE agents and learners.';
cfg.shocks.source = 'smoothed';
cfg.compare_with = {'a2_re'};
end
