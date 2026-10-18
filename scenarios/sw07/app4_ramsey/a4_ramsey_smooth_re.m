function cfg = a4_ramsey_smooth_re()
%A4_RAMSEY_SMOOTH_RE  Application 4: Ramsey policy (commitment), balanced weights plus rate smoothing, RE.
%
%   cfg = a4_ramsey_smooth_re()
%
%   As a4_ramsey_balanced_re with a weight of 0.5 on the change in the rate.

cfg = a4_ramsey_balanced_re();
cfg.id = 'a4_ramsey_smooth_re';
cfg.title = 'App 4: Ramsey policy, balanced weights with rate smoothing, rational expectations';
cfg.description = 'Ramsey policy under commitment from the 2022Q2 peak with loss weights inflation 1, output gap 0.5, rate 0.1, rate change 0.5; every agent rational.';
cfg.policy.loss = struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0.5);
end
