function cfg = a1_re()
%A1_RE  Application 1: forecast from the 2022Q2 inflation peak, rational expectations.
%
%   cfg = a1_re()
%
%   Zero future shocks from the 2022Q2 smoothed state, horizon 2022Q3-2026Q2.
%   Identical to the parent sw07_re; the RE benchmark of applications 1, 3-5.

cfg = sw07_re();
cfg.id = 'a1_re';
cfg.title = 'App 1: forecast from the 2022Q2 peak, rational expectations';
cfg.description = 'Unconditional forecast (zero future shocks) from the 2022Q2 inflation peak with every agent rational.';
end
