function res = assemble(ctx, d, rec, recDates, ev, S, H)
%ASSEMBLE  Build the result struct from the engine state and record (DESIGN 9).
%
%   res = hetlearn.engine.assemble(ctx, d, rec, recDates, ev, S, H)
%
%   Output res
%     .cfg       merged options
%     .paths     databank over [filter start, origin+H] of every transition
%                and measurement variable and shock of the scenario model:
%                RE-smoothed history to the origin, the scenario after.
%                <x>_exp1_BR of a learning variable holds the BR agents'
%                forecasts (history stage, then model) over the record
%                dates and NaN before (the RE filter runs with zero beliefs)
%     .learning  struct by PLM target (learning variables and auxiliary
%                PLMs), Series over the record dates: one per belief
%                parameter (e.g. alpha_pinf, beta_pinf), R_<param> (diagonal
%                of R), gain (used in t), the gain rule's own series
%                (gain.rule = 'koz': gain_R = Rg_t, DESIGN 18); learning
%                variables also n1, n2 (discrete-choice
%                shares at the end of t), n1_model (share used in the model in
%                t; NaN in the history), zetaRE, zetaBR, FE_RE, FE_BR (own
%                squared errors, unscaled), fRE, fBR (forecasts of x_{t+1} made
%                in t);
%                plus .isAux, .params
%     .events    table: date, type, variable, detail, stage ('history' |
%                'inversion' | 'forecast', from the date: up to the origin
%                history or inversion, after it forecast)
%     .state     final learning state
%     .dates     .origin, .horizon, .init_date, .record, .full
%     .meta      learnVars, model, model_hash, refilter hash and fit, IRIS
%                version
%
%   N agent types (ctx.nt, docs/DESIGN_br_extensions.md 1.1): .paths
%   <x>_exp1_<k> of 'plm' and 'rule' types hold the type's forecasts over the
%   record dates (NaN before), as <x>_exp1_BR above; .learning.<target>__<k>
%   holds the PLM series of each learning type (with .type and .variable),
%   and .learning.<x> the per-variable series of every type k: n_<k>,
%   n_model_<k>, U_<k>, FE_<k>, f_<k> (plus .types). .meta.types (name, kind,
%   variant, info, variables, cost, population) and .meta.model_values
%   ('model:<rule>' values, e.g. bma.sigma2 and the intensities used).

o = ctx.opts;
hz = ctx.horizon;
full = H.range(1) : hz(end);

paths = struct();
names = [ctx.xList(:); ctx.yList(:); ctx.eList(:)]';
for i = 1:numel(names)
    paths.(names{i}) = clip(d.(names{i}), full(1), full(end));
end
isNT = isfield(ctx, 'nt') && ~isempty(ctx.nt);
if isNT
    [paths, learning] = nt_outputs(ctx, paths, rec, recDates, full);     % N agent types
else
    for i = 1:numel(ctx.learnVars)
        x = ctx.learnVars{i};
        s = Series(full, NaN(numel(full), 1));
        s(recDates) = rec.var.(x).fBR(:);
        paths.([x '_exp1_BR']) = s;
    end

    learning = struct();
    sys = ctx.sys;
    vf = {'n1', 'n2', 'n1_model', 'zetaRE', 'zetaBR', 'FE_RE', 'FE_BR', 'fRE', 'fBR'};
    for i = 1:numel(sys.eq)
        e = sys.eq(i);
        L = struct('isAux', e.isAux, 'params', {e.param_names});
        for j = 1:numel(e.param_names)
            L.(e.param_names{j}) = Series(recDates, rec.eq(i).phi(j, :)');
        end
        for j = 1:numel(e.param_names)
            L.(['R_' e.param_names{j}]) = Series(recDates, rec.eq(i).Rdiag(j, :)');
        end
        L.gain = Series(recDates, rec.eq(i).gain(:));
        xf = setdiff(fieldnames(rec.eq), {'phi', 'Rdiag', 'gain'}, 'stable');   % gain-rule series
        for j = 1:numel(xf)
            L.(xf{j}) = Series(recDates, rec.eq(i).(xf{j})(:));
        end
        if isfield(rec.var, e.target)
            for j = 1:numel(vf)
                L.(vf{j}) = Series(recDates, rec.var.(e.target).(vf{j})(:));
            end
        end
        learning.(e.target) = L;
    end
end

if isempty(ev)
    events = table(cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), ...
        'VariableNames', {'date', 'type', 'variable', 'detail', 'stage'});
else
    dd = [ev.date];
    stage = repmat({'forecast'}, numel(dd), 1);
    org = double(ctx.origin);
    inH = dd <= org + 1e-6;
    stage(inH) = {'history'};
    if strcmp(o.history.mode, 'inversion') && isfield(ctx, 'inv_start')
        stage(inH & dd >= double(ctx.inv_start) - 1e-6) = {'inversion'};
    end
    events = table(hetlearn.util.date_str(dd)', {ev.type}', {ev.variable}', {ev.detail}', stage, ...
        'VariableNames', {'date', 'type', 'variable', 'detail', 'stage'});
end

res = struct();
res.cfg = o;
res.paths = paths;
res.learning = learning;
res.events = events;
res.state = S;
res.dates = struct('origin', ctx.origin, 'horizon', hz, 'init_date', ctx.init_date, ...
    'record', recDates, 'full', full);
meta = struct();
meta.model = ctx.spec.name;
meta.model_folder = ctx.spec.folder;
meta.learnVars = ctx.learnVars;
meta.xList = reshape(ctx.xList, 1, []);
meta.yList = reshape(ctx.yList, 1, []);
meta.eList = reshape(ctx.eList, 1, []);
meta.ext_file = ctx.info.meta.ext_file;
meta.model_hash = ctx.info.model_hash;
meta.collapse_maxdiff = ctx.info.meta.collapse_maxdiff;
meta.refilter_hash = H.hash;
meta.refilter_fit_error = H.fit_error;
meta.refilter_end = H.range(end);       % last data date the RE filter used
meta.refilter_realtime = isfield(H, 'realtime') && logical(H.realtime);
meta.iris_version = char(string(iris.release()));
if isNT
    nt = ctx.nt;
    meta.types = struct('name', {nt.types.name}, 'kind', {nt.types.kind}, 'variant', {nt.types.variant}, ...
        'info', {nt.types.info}, 'variables', {nt.types.vars}, 'cost', {nt.types.cost}, ...
        'population', {nt.types.inpop});
    mv = nt.model_values;
    if isfield(mv, 'bma')
        mv.bma.chi = [ctx.groups.chi];      % intensity of each share group
    end
    meta.model_values = mv;
end
res.meta = meta;
end


% =========================================================================
function [paths, learning] = nt_outputs(ctx, paths, rec, recDates, full)
% paths and learning series of an N-type run (DESIGN_br_extensions 1.1)
nt = ctx.nt;
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        if any(strcmp(nt.types(b.types(jj)).kind, {'plm', 'rule', 'level', 're_mean'}))
            s = Series(full, NaN(numel(full), 1));
            fn = ['f_' b.names{jj}];
            if isfield(rec.var.(x), ['fb_' b.names{jj}])
                fn = ['fb_' b.names{jj}];      % the model variable is the forecast before the transforms (P4)
            end
            s(recDates) = rec.var.(x).(fn)(:);
            paths.(b.fvars{jj}) = s;
        end
    end
end
learning = struct();
sys = ctx.sys;
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    L = struct('isAux', e.isAux, 'params', {e.param_names}, 'type', e.type, 'variable', e.var);
    for j = 1:numel(e.param_names)
        L.(e.param_names{j}) = Series(recDates, rec.eq(i).phi(j, :)');
    end
    for j = 1:numel(e.param_names)
        L.(['R_' e.param_names{j}]) = Series(recDates, rec.eq(i).Rdiag(j, :)');
    end
    L.gain = Series(recDates, rec.eq(i).gain(:));
    xf = setdiff(fieldnames(rec.eq), {'phi', 'Rdiag', 'gain'}, 'stable');
    for j = 1:numel(xf)
        L.(xf{j}) = Series(recDates, rec.eq(i).(xf{j})(:));
    end
    learning.(e.target) = L;
end
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    L = struct('types', {nt.byvar.(x).names});
    f = fieldnames(rec.var.(x));
    for j = 1:numel(f)
        L.(f{j}) = Series(recDates, rec.var.(x).(f{j})(:));
    end
    learning.(x) = L;
end
end
