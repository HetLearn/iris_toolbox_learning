function G = est_gonogo(kind)
%EST_GONOGO  Convergence check of the chains so far and the design's go/no-go rule.
%
%   G = est_gonogo()          % learning chains (results/estimation/learn/chains)
%   G = est_gonogo('re')      % RE chains (re/chains), same statistics, no decision
%
%   Uses the completed blocks of every chain, truncated to the shortest chain, and drops the
%   first half of each (50% burn-in). Per parameter: split R-hat (rank-normalised) and bulk ESS
%   (hlest.diagnostics), posterior mean and sd; per chain: draws and acceptance.
%   Rule (DESIGN_estimation 4.4): GO if split R-hat < 1.1 and bulk ESS > 100 for gain, memory
%   and chi, and for most (at least 80%) of the 36 structural parameters; otherwise NO-GO:
%   stop the full chains and run the fallback (posterior mode, inverse-Hessian sds, Laplace
%   MDD for all 39 parameters, plus est_05_mcmc_learn(k, n, [], 'cond'): conditional RWMH on
%   gain, memory, chi and the 7 shock sds with the other 29 parameters at the mode).
%   Writes <kind dir>/gonogo.txt and gonogo.mat. Needs no IRIS.

if nargin < 1 || isempty(kind)
    kind = 'learn';
end
c = est_config();
addpath(c.est_dir);
base = fullfile(c.results, kind);
dd = dir(fullfile(base, 'chains', 'chain_*'));
C = {};
for k = 1:numel(dd)
    Ck = hlest.read_chain(fullfile(dd(k).folder, dd(k).name));
    if Ck.n > 0
        C{end+1} = Ck; %#ok<AGROW>
    end
end
lines = {};
lines{end+1} = sprintf('est_gonogo(''%s'') %s', kind, datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
if numel(C) < 2
    lines{end+1} = sprintf('fewer than 2 chains with completed blocks (%d); nothing to check yet', numel(C));
    finish(base, lines, struct());
    G = struct('decision', 'WAIT');
    return
end
n = min(cellfun(@(x) x.n, C));
m = numel(C);
names = C{1}.names;
d = numel(names);
h = floor(n/2);
X = zeros(n - h, m, d);
acc = zeros(1, m);
for j = 1:m
    X(:, j, :) = reshape(C{j}.draws(h+1:n, :), n - h, 1, d);
    acc(j) = mean(C{j}.acc(1:n));
end
D = hlest.diagnostics(X);
ok = D.rhat < 1.1 & D.ess_bulk > 100;
isL = ismember(names, {'gain', 'omega', 'chi'});
lines{end+1} = sprintf('%d chains, %d draws each used (shortest chain), burn-in %d, %d post-burn-in draws per chain', m, n, h, n - h);
lines{end+1} = sprintf('acceptance by chain: %s', sprintf('%.3f ', acc));
lines{end+1} = sprintf('%-12s %12s %12s %10s %10s %4s', 'parameter', 'mean', 'sd', 'R-hat', 'ESS', 'ok');
for i = 1:d
    lines{end+1} = sprintf('%-12s %12.5f %12.5f %10.4f %10.1f %4d', names{i}, D.mean(i), D.sd(i), D.rhat(i), ...
        D.ess_bulk(i), ok(i)); %#ok<AGROW>
end
G = struct('n', n, 'm', m, 'burn', h, 'names', {names}, 'diag', D, 'ok', ok, 'acc', acc, 'decision', 'n/a');
if any(isL)
    okL = all(ok(isL));
    fracS = mean(ok(~isL));
    go = okL && fracS >= 0.8;
    G.decision = ternary(go, 'GO', 'NO-GO');
    lines{end+1} = sprintf(['rule: learning parameters all R-hat < 1.1 and ESS > 100: %d; structural parameters passing: ' ...
        '%d of %d (%.0f%%, need 80%%)'], okL, nnz(ok(~isL)), nnz(~isL), 100*fracS);
    lines{end+1} = sprintf('DECISION: %s', G.decision);
    if ~go
        lines{end+1} = ['NO-GO: stop the full learning chains (est_status shows the pids; taskkill /PID <pid> /F) and ' ...
            'run the fallback: est_05_mcmc_learn(k, 20000, [], ''cond'') for k = 1:3 after setting learn/pilot_cond.mat ' ...
            '(scale for 10 parameters, about 2.38/sqrt(10)*0.8); report the structural uncertainty as Laplace-only.'];
    end
end
save(fullfile(base, 'gonogo.mat'), 'G');
finish(base, lines, G);
end


function finish(base, lines, G) %#ok<INUSD>
fid = fopen(fullfile(base, 'gonogo.txt'), 'w');
fprintf(fid, '%s\n', lines{:});
fclose(fid);
fprintf('%s\n', lines{:});
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
