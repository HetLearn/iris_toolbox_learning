function U0 = init_fitness_n(n0, chi)
%INIT_FITNESS_N  Initial fitness over N types so that the logit returns the initial shares (docs/USER_GUIDE.md section 7.2).
%
%   U0 = hetlearn.switching.init_fitness_n(n0, chi)
%
%   Inputs
%     n0   G x N initial shares (rows sum to 1), one row per share group
%     chi  intensity >= 0, scalar or G x 1
%
%   Output
%     U0   G x N fitness with exp(chi*U0) / sum_j exp(chi*U0_j) = n0:
%          U0_k = (log n0_k - log n0_r)/chi, r = the first type of the row
%          with a positive share (U0_r = 0). A share of 0 gives -Inf.
%          For two types (RE first) this is hetlearn.switching.init_fitness:
%          U0 = [0, log(n2/(1 - n2))/chi].
%          chi = 0: zeros, and a warning if the shares are not equal (the
%          logit then returns equal shares after the first period).
%
%   See also hetlearn.switching.discrete_choice_n, hetlearn.switching.init_fitness.

[G, N] = size(n0);
if any(n0(:) < 0 | n0(:) > 1) || any(abs(sum(n0, 2) - 1) > 1e-10)
    error('hetlearn:switching:range', 'Initial shares must lie in [0, 1] and sum to 1 in each group.');
end
chi = chi(:);
if isscalar(chi)
    chi = repmat(chi, G, 1);
end
U0 = zeros(G, N);
for g = 1:G
    if chi(g) == 0
        if any(abs(n0(g, :) - 1 / N) > 0)
            warning('hetlearn:switching:chiZero', ...
                'switching.intensity = 0: shares are equal after the first period whatever the initial shares.');
        end
        continue
    end
    r = find(n0(g, :) > 0, 1);
    U0(g, :) = (log(n0(g, :)) - log(n0(g, r))) ./ chi(g);
    U0(g, r) = 0;
end
end
