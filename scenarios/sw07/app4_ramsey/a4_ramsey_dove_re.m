function cfg = a4_ramsey_dove_re()
%A4_RAMSEY_DOVE_RE  Application 4: Ramsey policy (commitment), dovish weights, RE.
%
%   cfg = a4_ramsey_dove_re()
%
%   As a4_ramsey_balanced_re with equal weights on inflation and the output gap.

cfg = a4_ramsey_balanced_re();
cfg.id = 'a4_ramsey_dove_re';
cfg.title = 'App 4: Ramsey policy, dovish weights, rational expectations';
cfg.description = 'Ramsey policy under commitment from the 2022Q2 peak with loss weights inflation 1, output gap 1, rate 0.1; every agent rational.';
cfg.policy.loss = struct('pinf', 1, 'ygap', 1, 'r', 0.1, 'dr', 0);
end
