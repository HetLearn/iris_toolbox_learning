function varargout = koz(cmd, varargin)
%KOZ  Endogenous gain of Kostyshyna, Ozden and Zhang (2024), eq. (9) (DESIGN 18).
%
%   f            = hetlearn.gain.koz('fields')                     % {'gain_R'}
%   gstate       = hetlearn.gain.koz('init', sys, learnVars, gopts)
%   g            = hetlearn.gain.koz('gain', gstate, errors, gopts)
%   [gstate, ev] = hetlearn.gain.koz('update', gstate, errors, gopts)
%
%   The adaptive step-size algorithm of Kostyshyna (2012) as written in KOZ
%   (Bank of Canada SWP 2024-14) eq. (9). For each gain process p, after
%   x_t is realised:
%       gamma_t = P[ gamma_{t-1} + mu * Rg_{t-1} * FE_t ]
%       Rg_t    = (1 - gamma_{t-1}) * Rg_{t-1} + FE_t
%   P projects onto gain.koz.bounds = [lower, upper] (event 'gain_bound'
%   each period it binds; Rg is not projected). FE_t is a SIGNED error times
%   gain.koz.error_scale (mu is scale dependent):
%     gain.koz.error = 'rls' (default): the one-step PLM residual
%       v_t - phi_{t-1}' z_{t-1} of the driving equation(s) (errors.rls), the
%       error of the RLS update itself (KOZ eq. 8);
%     'forecast': the BR agents' expectation error x_t - f^BR_{t-1}
%       (errors.forecast; a two-step error under beliefs.info = 'lagged').
%       Auxiliary PLM equations have no BR expectation and use their residual.
%   A missing FE_t (NaN: the first learning period for 'forecast', missing
%   data) leaves gamma and Rg unchanged.
%
%   Timing (KOZ eq. 8), as called by hetlearn.engine.update_learning:
%   'gain' returns g.<target> = gamma_{t-1} of the target's process, the
%   gain of the RLS update at the end of t; after the RLS and projection
%   step, 'update' moves gamma and Rg to t with FE_t, whatever the
%   projection facility did with the candidates (the error is observed
%   either way).
%
%   Structure (gain.koz.structure):
%     'common' (default; KOZ footnote 7): one process for every PLM equation,
%       auxiliary equations included, driven by the error of gain.koz.master
%       ('' or {} = the first learning variable; a list = the mean of their
%       scaled errors). With error 'rls' the master names PLM targets, with
%       'forecast' learning variables.
%     'per_variable': one process per PLM equation (auxiliary ones included),
%       each driven by its own error; gain.koz.master is ignored (warning).
%   Start values: gamma_0 = gain.koz.gamma0 ([] = gain.value; with
%   'per_variable' gain.by_var.<target> where set; 'common' ignores
%   gain.by_var, warning), Rg_0 = gain.koz.Rg0 (default 0: the derivative of
%   the initial estimate with respect to the gain). With mu = 0 the gain
%   stays at gamma_0, so the run equals the constant rule bit for bit
%   (gamma_{t-1} + 0 * Rg_{t-1} * FE_t = gamma_{t-1}).
%
%   Inputs
%     sys        closed PLM system (sys.eq(i).target)
%     learnVars  cellstr of learning variables (ctx.learnVars)
%     gopts      the gain options subtree (opts.gain): .value, .by_var, .koz
%                (.mu, .gamma0, .Rg0, .bounds, .error, .error_scale,
%                .structure, .master; validated by hetlearn.load_options)
%     gstate     gain state S.gain ('gain': at the start of t)
%     errors     see hetlearn.gain.constant (.t, .rls.<target>, .forecast.<x>)
%
%   Outputs
%     g          struct by PLM target: gamma_{t-1}, this period's RLS gain
%     gstate     after 'update', the state at the end of t: .rule, .structure, .error, .mu,
%                .bounds, .scale, .targets, .procOf.<target> (process index),
%                .proc (struct array: .members, .drivers, .src ('rls' |
%                'forecast' per driver), .gamma (gamma_t), .Rg (Rg_t)),
%                .rec.gain_R.<target> (Rg_t of the target's process,
%                recorded as res.learning.<target>.gain_R)
%     ev         'gain_bound' events (date, type, variable = process members,
%                detail)

switch char(cmd)
    case 'fields'
        varargout{1} = {'gain_R'};
    case 'init'
        varargout{1} = init(varargin{:});
    case 'gain'
        varargout{1} = gains(varargin{1});
    case 'update'
        [varargout{1:2}] = update(varargin{1:2});
    otherwise
        error('hetlearn:gain:call', 'Unknown call hetlearn.gain.koz(''%s'', ...).', char(cmd));
end
end


% =========================================================================
function G = init(sys, learnVars, gopts)
k = gopts.koz;
targets = {};
if isstruct(sys) && isfield(sys, 'eq') && ~isempty(sys.eq)
    targets = reshape({sys.eq.target}, 1, []);
end
lv = reshape(cellstr(learnVars), 1, []);
src0 = char(k.error);
master = k.master;
if ischar(master) || isstring(master)
    master = cellstr(master);
end
master = reshape(master(~cellfun(@isempty, master)), 1, []);
G = struct();
G.rule = 'koz';
G.structure = char(k.structure);
G.error = src0;
G.mu = k.mu;
G.bounds = reshape(double(k.bounds), 1, 2);
G.scale = k.error_scale;
G.targets = targets;
G.procOf = struct();
G.proc = struct('members', {}, 'drivers', {}, 'src', {}, 'gamma', {}, 'Rg', {});
G.rec = struct('gain_R', struct());
if isempty(targets)
    return
end
byVar = struct();
if isfield(gopts, 'by_var') && isstruct(gopts.by_var)
    byVar = gopts.by_var;
end
switch G.structure
    case 'common'
        drivers = master;
        if isempty(drivers)
            if ~isempty(lv)
                drivers = lv(1);
            else
                drivers = targets(1);
            end
        end
        if strcmp(src0, 'forecast')
            bad = setdiff(drivers, lv, 'stable');
            what = 'learning variables (they have a BR expectation)';
        else
            bad = setdiff(drivers, targets, 'stable');
            what = 'PLM targets';
        end
        if ~isempty(bad)
            error('hetlearn:gain:master', ...
                'gain.koz.master with gain.koz.error = ''%s'' must name %s; not: %s.', ...
                src0, what, strjoin(bad, ', '));
        end
        if ~isempty(fieldnames(byVar))
            warning('hetlearn:gain:byVarIgnored', ...
                'gain.by_var is ignored by gain.rule = ''koz'' with gain.koz.structure = ''common''.');
        end
        g0 = k.gamma0;
        if isempty(g0)
            g0 = gopts.value;
        end
        G.proc(1) = struct('members', {targets}, 'drivers', {drivers}, ...
            'src', {repmat({src0}, 1, numel(drivers))}, 'gamma', g0, 'Rg', k.Rg0);
        for i = 1:numel(targets)
            G.procOf.(targets{i}) = 1;
        end
    case 'per_variable'
        if ~isempty(master)
            warning('hetlearn:gain:masterIgnored', ...
                'gain.koz.master is ignored with gain.koz.structure = ''per_variable''.');
        end
        for i = 1:numel(targets)
            tg = targets{i};
            s = src0;
            if strcmp(s, 'forecast') && ~any(strcmp(tg, lv))
                s = 'rls';          % auxiliary PLM: no BR expectation, its own residual
            end
            g0 = k.gamma0;
            if isempty(g0)
                g0 = gopts.value;
                if isfield(byVar, tg)
                    g0 = byVar.(tg);
                end
            end
            G.proc(i) = struct('members', {{tg}}, 'drivers', {{tg}}, 'src', {{s}}, ...
                'gamma', g0, 'Rg', k.Rg0);
            G.procOf.(tg) = i;
        end
    otherwise
        error('hetlearn:gain:structure', 'Unknown gain.koz.structure ''%s''.', G.structure);
end
G = store(G);
end


% =========================================================================
function g = gains(G)
% gamma_{t-1} of each target's process: the gain of this period's RLS update.
g = struct();
for i = 1:numel(G.targets)
    tg = G.targets{i};
    g.(tg) = G.proc(G.procOf.(tg)).gamma;
end
end


function [G, ev] = update(G, errors)
% KOZ eq. (9) for every process, from gamma_{t-1}, Rg_{t-1} and FE_t.
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
lo = G.bounds(1);
hi = G.bounds(2);
for p = 1:numel(G.proc)
    P = G.proc(p);
    e = NaN(1, numel(P.drivers));
    for j = 1:numel(P.drivers)
        d = P.drivers{j};
        if strcmp(P.src{j}, 'forecast')
            if isfield(errors, 'forecast') && isfield(errors.forecast, d)
                e(j) = errors.forecast.(d);
            end
        elseif isfield(errors, 'rls') && isfield(errors.rls, d)
            e(j) = errors.rls.(d);
        end
    end
    fe = mean(G.scale * e);                         % one driver: G.scale * e exactly
    if ~isfinite(fe)
        continue                                    % no error observed: gamma, Rg kept
    end
    gam = P.gamma;
    Rg = P.Rg;
    gNew = gam + G.mu * Rg * fe;
    rNew = (1 - gam) * Rg + fe;
    if ~(isfinite(gNew) && isfinite(rNew))
        ev(end+1) = mkev(errors, 'gain_bound', P.members, sprintf( ...
            'non-finite update (FE_t %.6g, Rg_{t-1} %.6g); gamma %.6g and Rg kept', fe, Rg, gam)); %#ok<AGROW>
        continue
    end
    if gNew < lo
        ev(end+1) = mkev(errors, 'gain_bound', P.members, sprintf( ...
            'gamma_t %.6g below the lower bound %.6g (gamma_{t-1} %.6g, Rg_{t-1} %.6g, FE_t %.6g); set to the bound', ...
            gNew, lo, gam, Rg, fe)); %#ok<AGROW>
        gNew = lo;
    elseif gNew > hi
        ev(end+1) = mkev(errors, 'gain_bound', P.members, sprintf( ...
            'gamma_t %.6g above the upper bound %.6g (gamma_{t-1} %.6g, Rg_{t-1} %.6g, FE_t %.6g); set to the bound', ...
            gNew, hi, gam, Rg, fe)); %#ok<AGROW>
        gNew = hi;
    end
    G.proc(p).gamma = gNew;
    G.proc(p).Rg = rNew;
end
G = store(G);
end


function G = store(G)
for i = 1:numel(G.targets)
    tg = G.targets{i};
    G.rec.gain_R.(tg) = G.proc(G.procOf.(tg)).Rg;
end
end


function e = mkev(errors, type, members, detail)
t = NaN;
if isfield(errors, 't')
    t = double(errors.t);
end
e = struct('date', t, 'type', type, 'variable', strjoin(members, ','), 'detail', detail);
end
