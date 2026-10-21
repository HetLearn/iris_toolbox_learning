function cfg = br27_bma()
%BR27_BMA  BR portfolio 27: Bayesian model averaging of the RE and AR(1) forecasts (Evans, Honkapohja, Sargent and Williams 2013; Cho and Kasa 2017).
%
%   cfg = br27_bma()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 27 and the 27
%   row of section 3: the shares are posterior model probabilities, a logit
%   in cumulative squared errors (unnormalized fitness, memory 1) with
%   intensity 1/(2 sigma^2), sigma^2 the RE(t-1) model's two-step forecast
%   error variance of inflation ('model:bma', proposed in the design), from
%   prior shares 0.5. No forgetting, so the shares tend to 0 or 1. The
%   projection facility is the baseline's ('alm'). Writes compare_a1_learn.csv
%   and compare_a1_re.csv when it completes.

cfg = a1_learn();
cfg.id = 'br27_bma';
cfg.title = 'BR 27: Bayesian model averaging of the RE and AR(1) forecasts';
cfg.description = 'As a1_learn, with the shares set as posterior probabilities of the two forecasting models (cumulative squared errors, no forgetting).';
cfg.switching.fitness = 'unnormalized';
cfg.switching.memory = 1;
cfg.switching.intensity = 'model:bma';        % = 1/(2 sigma^2) from the RE limit
cfg.compare_with = {'a1_learn', 'a1_re'};
end
