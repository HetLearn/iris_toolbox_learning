function cfg = a2_re()
%A2_RE  Application 2: replay of the RE-smoothed shocks 2022Q3-2026Q2, rational expectations.
%
%   cfg = a2_re()
%
%   From the 2022Q2 smoothed state, the shocks backed out by the RE smoother
%   for 2022Q3-2026Q2 are fed in one quarter at a time (unanticipated). Under
%   RE this reproduces the data.

cfg = a1_re();
cfg.id = 'a2_re';
cfg.title = 'App 2: replay of the RE-smoothed shocks 2022Q3-2026Q2, rational expectations';
cfg.description = 'The RE-smoothed shocks of 2022Q3-2026Q2 are fed in quarter by quarter from the 2022Q2 state; with every agent rational this reproduces the data.';
cfg.shocks.source = 'smoothed';
end
