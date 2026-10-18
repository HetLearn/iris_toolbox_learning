function cfg = a3_loose_re()
%A3_LOOSE_RE  Application 3: policy 100 bp a year looser than the Taylor rule in 2022Q3-2023Q2, RE.
%
%   cfg = a3_loose_re()
%
%   ms is the monetary shock process, which enters the SW07 rule one for one
%   (r = rule + ms, ms = crhoms*ms{-1} + em). Holding ms 0.25 below its path in
%   the same scenario without the condition ('delta', reference 'self')
%   puts the rate 0.25% per quarter (100 bp a year) below what the rule gives
%   at the same state; em is endogenised, so agents are surprised each quarter.
%   Writes compare_a1_re.csv (this minus the baseline).

cfg = a1_re();
cfg.id = 'a3_loose_re';
cfg.title = 'App 3: policy 100 bp looser than the Taylor rule in 2022Q3-2023Q2, rational expectations';
cfg.description = 'From the 2022Q2 peak, the rate is held 100 bp a year below the Taylor rule for four quarters (ms 0.25 below its own path, em endogenised); every agent rational.';
cfg.conditions = struct('variable', 'ms', 'shock', 'em', ...
    'dates', [qq(2022, 3), qq(2023, 2)], 'values', -0.25, ...
    'type', 'delta', 'reference', 'self');
cfg.compare_with = {'a1_re'};
end
