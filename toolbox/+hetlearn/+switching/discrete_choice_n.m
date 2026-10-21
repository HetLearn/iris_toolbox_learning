function [n, U] = discrete_choice_n(FE, Uprev, chi, omega, varargin)
%DISCRETE_CHOICE_N  Fitness update and shares over N agent types (DESIGN_br_extensions 1.2).
%
%   [n, U] = hetlearn.switching.discrete_choice_n(FE, Uprev, chi, omega)
%   [n, U] = hetlearn.switching.discrete_choice_n(FE, Uprev, chi, omega, ...
%                'inertia', delta, 'nprev', nprev, 'costs', C, 'fitness', fit)
%
%   Inputs (one row per share group, one column per type of the group)
%     FE      G x N squared forecast errors of period t (sums over the
%             group's variables)
%     Uprev   G x N fitness U_{t-1}
%     chi     intensity of choice >= 0, scalar or G x 1
%     omega   memory, scalar in [0, 1] (1 only with 'unnormalized')
%   Options
%     'inertia'  delta in [0, 1) (default 0)
%     'nprev'    G x N shares n_{t-1} (needed when delta > 0)
%     'costs'    Brock-Hommes costs C_k >= 0, 1 x N or G x N (default 0)
%     'fitness'  'normalized' (default; IJCB, as hetlearn.switching.discrete_choice)
%                | 'unnormalized' (Anufriev-Hommes)
%
%   Outputs
%     n   G x N shares at the end of t
%     U   G x N fitness U_t
%
%   Recursions
%     U_{k,t} = omega*U_{k,t-1} - c*FE_{k,t},   c = 1 - omega ('normalized') | 1 ('unnormalized')
%     n_{k,t} = delta*n_{k,t-1} + (1 - delta)*exp(chi*(U_{k,t} - C_k)) / sum_j exp(chi*(U_{j,t} - C_j))
%   The logit is evaluated with log-sum-exp (no overflow for any chi*U). A
%   fitness of -Inf (an initial share of 0, hetlearn.switching.init_fitness_n)
%   gives share 0 and stays -Inf while omega > 0. omega = 0 drops the memory
%   term (so -Inf does not turn into NaN), as in discrete_choice. chi = 0, or
%   every fitness of a group at -Inf, gives equal shares. A NaN error gives
%   NaN shares in its group (the engine keeps the previous ones, event
%   'shares_nan').
%
%   With N = 2, delta = 0, C = 0 and 'normalized' the shares equal
%   hetlearn.switching.discrete_choice (n(:,1) = n1, with the RE type first)
%   to rounding; the engine calls discrete_choice itself in that case, so the
%   default two-type runs are unchanged bit for bit.
%
%   See also hetlearn.switching.init_fitness_n, hetlearn.switching.discrete_choice.

ip = inputParser;
ip.addParameter('inertia', 0);
ip.addParameter('nprev', []);
ip.addParameter('costs', 0);
ip.addParameter('fitness', 'normalized');
ip.parse(varargin{:});
delta = ip.Results.inertia;
fit = char(ip.Results.fitness);

[G, N] = size(FE);
if ~isequal(size(Uprev), [G, N])
    error('hetlearn:switching:size', 'FE and Uprev must have the same size (%s vs %s).', ...
        mat2str(size(FE)), mat2str(size(Uprev)));
end
switch fit
    case 'normalized'
        c = 1 - omega;
    case 'unnormalized'
        c = 1;
    otherwise
        error('hetlearn:switching:fitness', 'fitness must be ''normalized'' or ''unnormalized'' (got ''%s'').', fit);
end
if omega == 0
    mem = zeros(G, N);
else
    mem = omega .* Uprev;
end
U = -c .* FE + mem;

C = ip.Results.costs;
if isempty(C)
    C = 0;
end
chi = chi(:);
if isscalar(chi)
    chi = repmat(chi, G, 1);
end
a = chi .* (U - C);
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
if delta ~= 0
    np = ip.Results.nprev;
    if ~isequal(size(np), [G, N])
        error('hetlearn:switching:size', 'inertia > 0 needs nprev of size %s.', mat2str([G, N]));
    end
    n = delta .* np + (1 - delta) .* n;
end
end
