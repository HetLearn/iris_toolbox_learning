function P = est_05_pilot_pick(hours, target, chains, scale)
%EST_05_PILOT_PICK  Proposal scale of the learning chains from the pilot chains; chain length.
%
%   P = est_05_pilot_pick()                        % every pilot, 8 hours, target 0.275
%   P = est_05_pilot_pick(hours, target, chains)   % only the pilots chain_<chains>
%   P = est_05_pilot_pick(hours, target, chains, scale)   % record a chosen scale
%
%   Reads results/estimation/learn/pilot/chain_1xx/ (est_05_mcmc_learn(100+i, 2000, scale_i)),
%   fits log acceptance on the scale (linear) over the pilots, picks the scale for the target
%   acceptance, and sizes the chains: ndraws = floor(hours*3600/s_per_draw), s_per_draw the
%   slowest pilot's (all ran in parallel with the other processes). Writes learn/pilot.mat
%   (scale, scales, acc, s_per_draw, ndraws, hours, target). Needs no IRIS.

if nargin < 1 || isempty(hours)
    hours = 8;
end
if nargin < 2 || isempty(target)
    target = 0.275;
end
if nargin < 3
    chains = [];
end
if nargin < 4
    scale = [];
end
c = est_config();
addpath(c.est_dir);
dd = dir(fullfile(c.results, 'learn', 'pilot', 'chain_*'));
if ~isempty(chains)
    dd = dd(ismember({dd.name}, arrayfun(@(k) sprintf('chain_%03d', k), chains, 'UniformOutput', false)));
end
sc = [];
acc = [];
spd = [];
for k = 1:numel(dd)
    f = fullfile(dd(k).folder, dd(k).name, 'state.mat');
    if exist(f, 'file') ~= 2
        continue
    end
    S = load(f);
    if S.st.n_done == 0
        continue
    end
    sc(end+1) = S.st.scale; %#ok<AGROW>
    acc(end+1) = S.st.n_acc/S.st.n_done; %#ok<AGROW>
    spd(end+1) = S.st.elapsed_s/S.st.n_done; %#ok<AGROW>
    fprintf('pilot %s: scale %.4f, %d draws, acceptance %.3f, %.3f s per draw\n', dd(k).name, S.st.scale, ...
        S.st.n_done, acc(end), spd(end));
end
if numel(sc) >= 2
    pf = polyfit(sc, log(max(acc, 1e-3)), 1);
    s = (log(target) - pf(2))/pf(1);
else
    s = sc*exp((acc - target)/0.5);
end
if ~isfinite(s) || s <= 0
    [~, i] = min(abs(acc - target));
    s = sc(i);
end
sfit = s;
if ~isempty(scale)
    s = scale;
end
P = struct('scale', s, 'scale_fit', sfit, 'pilots', {{dd.name}}, 'scales', sc, 'acc', acc, 's_per_draw', max(spd), 'hours', hours, 'target', target, ...
    'ndraws', floor(hours*3600/max(spd)), 'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
save(fullfile(c.results, 'learn', 'pilot.mat'), '-struct', 'P');
fprintf('chosen scale %.4f (target acceptance %.3f); %.3f s per draw -> %d draws in %.1f hours\n', s, target, ...
    P.s_per_draw, P.ndraws, hours);
end
