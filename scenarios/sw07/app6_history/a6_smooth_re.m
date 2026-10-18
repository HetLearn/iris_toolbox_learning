function cfg = a6_smooth_re()
%A6_SMOOTH_RE  Application 6: RE-smoothed history 1966Q1-2026Q2 (base of the RE shock decomposition).
%
%   cfg = a6_smooth_re()
%
%   The RE filter and smoother over the whole sample; the origin is the last
%   data quarter, 2026Q2, so the history is the object. The 4-quarter
%   zero-shock forecast after it is not used. run_applications('app6')
%   decomposes pinfobs and dy into shock groups with hetlearn.decompose.

cfg = a1_re();
cfg.id = 'a6_smooth_re';
cfg.title = 'App 6: RE-smoothed history 1966Q1-2026Q2, rational expectations';
cfg.description = 'The history to 2026Q2 as the RE smoother backs it out, the base of the RE shock decomposition.';
cfg.forecast.origin = qq(2026, 2);            % the last data quarter (spec.filter_range end)
cfg.forecast.horizon = 4;
end
