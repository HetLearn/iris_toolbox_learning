function [zetaRE0, zetaBR0] = init_fitness(init_n2, chi)
%INIT_FITNESS  Initial fitness so that the initial BR share equals init_n2.
%
%   [zetaRE0, zetaBR0] = hetlearn.switching.init_fitness(init_n2, chi)
%
%   Inputs
%     init_n2  initial share of BR agents, in [0, 1] (scalar or array)
%     chi      intensity of choice (> 0; see below for chi = 0)
%
%   Outputs
%     zetaRE0  0
%     zetaBR0  log(init_n2 / (1 - init_n2)) / chi, so that
%              exp(chi*zBR0) / (exp(chi*zRE0) + exp(chi*zBR0)) = init_n2.
%              init_n2 = 0 or 1 gives -Inf or +Inf.
%
%   With chi = 0 the shares are always 1/2 whatever the fitness; zetaBR0 is
%   then 0 and a warning is issued if init_n2 differs from 0.5 (the engine
%   still uses init_n2 for the first period).

zetaRE0 = zeros(size(init_n2));
if any(init_n2(:) < 0 | init_n2(:) > 1)
    error('hetlearn:switching:range', 'init_n2 must lie in [0, 1].');
end
if chi == 0
    zetaBR0 = zeros(size(init_n2));
    if any(abs(init_n2(:) - 0.5) > 0)
        warning('hetlearn:switching:chiZero', ...
            'switching.intensity = 0: shares are 0.5 after the first period whatever init_n2.');
    end
    return
end
zetaBR0 = (log(init_n2) - log1p(-init_n2)) ./ chi;
end
