function G = est_gonogo2(which, varargin)
%EST_GONOGO2  Convergence of the stage-1 (learn/chains) and stage-2 (learn/chains2) learning chains; is stage 2 needed?
%
%   G = est_gonogo2()               % stage 1 and, when learn/chains2 has chains, stage 2
%   G = est_gonogo2('stage1')       % only stage 1 ('stage2': only stage 2)
%   G = est_gonogo2(which, 'min_age_s', 120, 'chains2', folder)
%
%   Reads completed block files only (hlest.read_blocks: never state.mat; block files younger than
%   min_age_s seconds are skipped unless the chain's progress.txt says done), so it is safe while
%   chains run. Chains truncated to the shortest; burn-in: stage 1 the first 50% (as est_gonogo
%   and est_06_post), stage 2 the first 10% (stage 1 is the adaptation). Per parameter: split
%   R-hat on rank-normalised draws and bulk ESS (hlest.diagnostics), mean, sd.
%   Two criteria per stage:
%     rule       the design's go/no-go rule (est_gonogo): R-hat < 1.1 and ESS > 100 for gain,
%                memory and chi, and for at least 80% of the 36 structural parameters
%     converged  every one of the 39 parameters has R-hat < 1.1 and ESS > 100
%   Decision lines (parsed by est_06_post):
%     STAGE1 RULE: GO | NO-GO
%     STAGE1 CONVERGED: yes | no
%     STAGE 2: not needed | needed        (needed when stage 1 is not converged)
%     STAGE2 CONVERGED: yes | no          (when stage-2 chains exist)
%   Writes results/estimation/learn/gonogo2.txt and gonogo2.mat. Needs no IRIS.

if nargin < 1 || isempty(which)
    which = 'both';
end
c = est_config();
addpath(c.est_dir);
ip = inputParser;
ip.addParameter('min_age_s', 120);
ip.addParameter('chains2', fullfile(c.results, 'learn', 'chains2'));
ip.parse(varargin{:});
o = ip.Results;
M = load(fullfile(c.results, 'learn', 'mode.mat'), 'names');
names = M.names(:)';
isL = ismember(names, {'gain', 'omega', 'chi'});
lines = {sprintf('est_gonogo2(''%s'') %s', which, datestr(now, 'yyyy-mm-dd HH:MM:SS'))}; %#ok<TNOW1,DATST>
G = struct('created', lines{1});
st = {};
if any(strcmp(which, {'both', 'stage1'}))
    st{end+1} = {'stage1', fullfile(c.results, 'learn', 'chains'), 0.5};
end
if any(strcmp(which, {'both', 'stage2'}))
    st{end+1} = {'stage2', o.chains2, 0.1};
end
for s = 1:numel(st)
    [tag, base, burn] = st{s}{:};
    C = read_set(base, o.min_age_s);
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = sprintf('== %s: %s', upper(tag), base); %#ok<AGROW>
    if numel(C) < 2
        lines{end+1} = sprintf('fewer than 2 chains with completed blocks (%d)', numel(C)); %#ok<AGROW>
        G.(tag) = struct('decision', 'WAIT', 'converged', false, 'n', 0);
        continue
    end
    n = min(cellfun(@(x) x.n, C));
    m = numel(C);
    d = numel(names);
    h = floor(burn*n);
    X = zeros(n - h, m, d);
    acc = zeros(1, m);
    for j = 1:m
        X(:, j, :) = reshape(C{j}.draws(h+1:n, :), n - h, 1, d);
        acc(j) = mean(C{j}.acc(1:n));
    end
    D = hlest.diagnostics(X);
    ok = D.rhat < 1.1 & D.ess_bulk > 100;
    okL = all(ok(isL));
    fracS = mean(ok(~isL));
    go = okL && fracS >= 0.8;
    conv = all(ok);
    lines{end+1} = sprintf(['%d chains (%s), %d draws each used (shortest chain; read %s), burn-in %d (%.0f%%), ' ...
        '%d post burn-in draws per chain'], m, strjoin(cellfun(@(x) x.name, C, 'UniformOutput', false), ' '), n, ...
        mat2str(cellfun(@(x) x.n, C)), h, 100*burn, n - h); %#ok<AGROW>
    lines{end+1} = sprintf('acceptance by chain: %s', sprintf('%.3f ', acc)); %#ok<AGROW>
    lines{end+1} = sprintf('%-12s %12s %12s %10s %10s %4s', 'parameter', 'mean', 'sd', 'R-hat', 'ESS', 'ok'); %#ok<AGROW>
    for i = 1:d
        lines{end+1} = sprintf('%-12s %12.5f %12.5f %10.4f %10.1f %4d', names{i}, D.mean(i), D.sd(i), D.rhat(i), ...
            D.ess_bulk(i), ok(i)); %#ok<AGROW>
    end
    bad = names(~ok);
    [rmx, irx] = max(D.rhat);
    [emn, ien] = min(D.ess_bulk);
    lines{end+1} = sprintf(['learning parameters all R-hat < 1.1 and ESS > 100: %d; structural parameters passing: %d of %d ' ...
        '(%.0f%%, the rule needs 80%%); largest R-hat %.3f (%s), smallest ESS %.0f (%s)'], okL, nnz(ok(~isL)), nnz(~isL), ...
        100*fracS, rmx, names{irx}, emn, names{ien}); %#ok<AGROW>
    lines{end+1} = sprintf('%s RULE: %s', upper(tag), ternary(go, 'GO', 'NO-GO')); %#ok<AGROW>
    lines{end+1} = sprintf('%s CONVERGED: %s (%d of %d parameters pass%s)', upper(tag), ternary(conv, 'yes', 'no'), ...
        nnz(ok), d, ternary(isempty(bad), '', ['; failing: ' strjoin(bad, ' ')])); %#ok<AGROW>
    G.(tag) = struct('n', n, 'm', m, 'burn', h, 'names', {names}, 'diag', D, 'ok', ok, 'acc', acc, ...
        'decision', ternary(go, 'GO', 'NO-GO'), 'converged', conv, 'failing', {bad}, 'chains', ...
        {cellfun(@(x) x.name, C, 'UniformOutput', false)}, 'status', {cellfun(@(x) x.status, C, 'UniformOutput', false)});
    if strcmp(tag, 'stage1')
        allDone = all(strcmp(G.stage1.status, 'done'));
        if conv
            lines{end+1} = sprintf('STAGE 2: not needed (stage 1 converged%s)', ternary(allDone, '', ...
                '; chains still running, check again when they are done')); %#ok<AGROW>
        else
            lines{end+1} = sprintf(['STAGE 2: needed (stage 1 not converged: %s). Run est_07_mcmc_stage2(''prepare'') once ' ...
                'the stage-1 chains are done, then est_07_mcmc_stage2(k, ndraws) for k = 1..6 (launch.ps1)%s'], ...
                strjoin(bad, ' '), ternary(allDone, '', '; stage-1 chains still running')); %#ok<AGROW>
        end
        G.stage2_needed = ~conv;
    end
end
save(fullfile(c.results, 'learn', 'gonogo2.mat'), 'G');
fid = fopen(fullfile(c.results, 'learn', 'gonogo2.txt'), 'w');
fprintf(fid, '%s\n', lines{:});
fclose(fid);
fprintf('%s\n', lines{:});
end


function C = read_set(base, minAge)
dd = dir(fullfile(base, 'chain_*'));
dd = dd([dd.isdir]);
C = {};
for k = 1:numel(dd)
    cdir = fullfile(dd(k).folder, dd(k).name);
    st = progress_status(cdir);
    age = minAge;
    if strcmp(st, 'done')
        age = 0;
    end
    B = hlest.read_blocks(cdir, false, age);
    if B.n > 0
        B.name = dd(k).name;
        B.status = st;
        C{end+1} = B; %#ok<AGROW>
    end
end
end


function st = progress_status(cdir)
st = '';
f = fullfile(cdir, 'progress.txt');
if exist(f, 'file') ~= 2
    return
end
try
    txt = fileread(f);
    t = regexp(txt, 'status = (\w+)', 'tokens', 'once');
    if ~isempty(t)
        st = t{1};
    end
catch
end
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
