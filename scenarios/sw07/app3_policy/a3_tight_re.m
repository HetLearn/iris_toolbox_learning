function cfg = a3_tight_re()
%A3_TIGHT_RE  Application 3: policy 100 bp a year tighter than the Taylor rule in 2022Q3-2023Q2, RE.
%
%   cfg = a3_tight_re()
%
%   As a3_loose_re with ms held 0.25 ABOVE its path without the condition.

cfg = a3_loose_re();
cfg.id = 'a3_tight_re';
cfg.title = 'App 3: policy 100 bp tighter than the Taylor rule in 2022Q3-2023Q2, rational expectations';
cfg.description = 'From the 2022Q2 peak, the rate is held 100 bp a year above the Taylor rule for four quarters (ms 0.25 above its own path, em endogenised); every agent rational.';
cfg.conditions.values = 0.25;
end
