function T = est_status2()
%EST_STATUS2  Progress of every chain, stage-2 chains included (est_status plus learn/chains2).
%
%   T = est_status2()
%
%   Reads only the progress.txt files (written by hlest.rwmh every 100-200 draws) under
%   results/estimation/: re/chains, learn/chains (stage 1), learn/chains2 (stage 2,
%   est_07_mcmc_stage2), learn/stage2_test/chains2 (if present), learn/pilot and
%   learn/chains_cond. Prints, per chain: status, whether its MATLAB process (pid) is alive,
%   draws done / target, acceptance (overall and last chunk), last log posterior, seconds per
%   draw, ETA and the time of the last update. Needs no IRIS; never opens state.mat or a block.

c = est_config();
groups = {fullfile('re', 'chains'), fullfile('learn', 'chains'), fullfile('learn', 'chains2'), ...
    fullfile('learn', 'stage2_test', 'chains2'), fullfile('learn', 'pilot'), fullfile('learn', 'chains_cond')};
rows = {};
for g = 1:numel(groups)
    dd = dir(fullfile(c.results, groups{g}, 'chain_*'));
    for k = 1:numel(dd)
        f = fullfile(dd(k).folder, dd(k).name, 'progress.txt');
        if exist(f, 'file') ~= 2
            continue
        end
        P = parse(f);
        alive = pid_alive(str2double(P.pid));
        eta = str2double(P.eta_s);
        if strcmp(P.status, 'done')
            etaTxt = '-';
        elseif isfinite(eta)
            etaTxt = datestr(now + eta/86400, 'HH:MM'); %#ok<TNOW1,DATST>
        else
            etaTxt = '?';
        end
        rows(end+1, :) = {strrep(groups{g}, filesep, '/'), dd(k).name, P.status, alive, ...
            str2double(P.draws_done), str2double(P.ndraws), str2double(P.acc_rate), str2double(P.acc_last), ...
            str2double(P.last_lp), str2double(P.s_per_draw), etaTxt, P.updated}; %#ok<AGROW>
    end
end
if isempty(rows)
    fprintf('no chains yet under %s\n', c.results);
    T = table();
    return
end
T = cell2table(rows, 'VariableNames', {'group', 'chain', 'status', 'alive', 'draws', 'target', 'acc', ...
    'acc_last', 'last_lp', 's_per_draw', 'eta', 'updated'});
fprintf('%-26s %-10s %-8s %-5s %9s %9s %6s %6s %12s %8s %6s %s\n', 'group', 'chain', 'status', 'alive', ...
    'draws', 'target', 'acc', 'last', 'last_lp', 's/draw', 'ETA', 'updated');
for i = 1:height(T)
    fprintf('%-26s %-10s %-8s %-5d %9d %9d %6.3f %6.3f %12.3f %8.4f %6s %s\n', T.group{i}, T.chain{i}, ...
        T.status{i}, T.alive(i), T.draws(i), T.target(i), T.acc(i), T.acc_last(i), T.last_lp(i), ...
        T.s_per_draw(i), T.eta{i}, T.updated{i});
end
for g = {'learn/chains', 'learn/chains2'}
    s = strcmp(T.group, g{1});
    if any(s)
        fprintf('%s: %d chains, %d done, %d running with a live process, draws %d-%d of %d\n', g{1}, nnz(s), ...
            nnz(strcmp(T.status(s), 'done')), nnz(strcmp(T.status(s), 'running') & T.alive(s)), min(T.draws(s)), ...
            max(T.draws(s)), max(T.target(s)));
    end
end
end


function P = parse(f)
P = struct('status', '?', 'pid', 'NaN', 'draws_done', 'NaN', 'ndraws', 'NaN', 'acc_rate', 'NaN', ...
    'acc_last', 'NaN', 'last_lp', 'NaN', 's_per_draw', 'NaN', 'eta_s', 'NaN', 'updated', '');
try
    txt = fileread(f);
catch
    return
end
L = regexp(txt, '(\w+)\s*=\s*([^\n\r]*)', 'tokens');
for i = 1:numel(L)
    P.(L{i}{1}) = strtrim(L{i}{2});
end
end


function tf = pid_alive(pid)
tf = false;
if ~isfinite(pid)
    return
end
[st, out] = system(sprintf('tasklist /FI "PID eq %d" /NH', pid));
tf = st == 0 && contains(lower(out), 'matlab');
end
