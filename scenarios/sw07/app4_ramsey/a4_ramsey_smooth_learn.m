function cfg = a4_ramsey_smooth_learn()
%A4_RAMSEY_SMOOTH_LEARN  Application 4: Ramsey policy (commitment), balanced weights with rate smoothing, learning on inflation.
%
%   cfg = a4_ramsey_smooth_learn()
%
%   As a4_rule_learn with the policy block of a4_ramsey_smooth_re (taken from
%   that file, so the two stay identical). With learning the planner
%   re-optimises each quarter given the current beliefs and shares. Caveat:
%   the anchored RE agents forecast with the RE solution under the Taylor
%   rule, not under the Ramsey policy (an open design question).
%   Writes compare_a4_rule_learn.csv.

cfg = a4_rule_learn();
r = a4_ramsey_smooth_re();
cfg.id = 'a4_ramsey_smooth_learn';
cfg.title = 'App 4: Ramsey policy, balanced weights with rate smoothing, learning on inflation';
cfg.description = 'Ramsey policy under commitment from the 2022Q2 peak with loss weights inflation 1, output gap 0.5, rate 0.1, rate change 0.5, with inflation expectations a switching mix of RE agents and learners.';
cfg.policy = r.policy;
cfg.compare_with = {'a4_rule_learn'};
end
