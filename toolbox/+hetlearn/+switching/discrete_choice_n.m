function [n, U] = discrete_choice_n(FE, Uprev, chi, omega)
%DISCRETE_CHOICE_N  Fitness update and shares over N agent types (docs/USER_GUIDE.md section 7.2).
%
%   [n, U] = hetlearn.switching.discrete_choice_n(FE, Uprev, chi, omega)
%
%   Inputs (one row per share group, one column per type of the group)
%     FE      G x N squared forecast errors of period t (sums over the
%             group's variables)
%     Uprev   G x N fitness U_{t-1}
%     chi     intensity of choice >= 0, scalar or G x 1
%     omega   memory, scalar in [0, 1)
%
%   Outputs
%     n   G x N shares at the end of t
%     U   G x N fitness U_t
%
%   Recursions (normalized fitness, IJCB, as hetlearn.switching.discrete_choice)
%     U_{k,t} = omega*U_{k,t-1} - (1 - omega)*FE_{k,t}
%     n_{k,t} = exp(chi*U_{k,t}) / sum_j exp(chi*U_{j,t})
%   The logit is evaluated with log-sum-exp (no overflow for any chi*U). A
%   fitness of -Inf (an initial share of 0, hetlearn.switching.init_fitness_n)
%   gives share 0 and stays -Inf while omega > 0. omega = 0 drops the memory
%   term (so -Inf does not turn into NaN), as in discrete_choice. chi = 0, or
%   every fitness of a group at -Inf, gives equal shares. A NaN error gives
%   NaN shares in its group (the engine keeps the previous ones, event
%   'shares_nan').
%
%   With N = 2 the shares equal hetlearn.switching.discrete_choice (n(:,1) =
%   n1, with the RE type first) to rounding; the engine calls discrete_choice
%   itself in that case, so the default two-type runs are unchanged bit for
%   bit.
%
%   See also hetlearn.switching.init_fitness_n, hetlearn.switching.discrete_choice.

[G, N] = size(FE);
if ~isequal(size(Uprev), [G, N])
    error('hetlearn:switching:size', 'FE and Uprev must have the same size (%s vs %s).', ...
        mat2str(size(FE)), mat2str(size(Uprev)));
end
c = 1 - omega;
if omega == 0
    mem = zeros(G, N);
else
    mem = omega .* Uprev;
end
U = -c .* FE + mem;

chi = chi(:);
if isscalar(chi)
    chi = repmat(chi, G, 1);
end
a = chi .* U;
a(chi == 0 & ~any(isnan(U), 2), :) = 0;          % chi = 0: equal shares whatever the fitness
n = NaN(G, N);
for g = 1:G
    r = a(g, :);
    if any(isnan(r))
        continue
    end
    mx = max(r);
    if mx == -Inf
        n(g, :) = 1 / N;                         % every type at -Inf: equal shares
        continue
    end
    e = exp(r - mx);
    n(g, :) = e ./ sum(e);
end
end
