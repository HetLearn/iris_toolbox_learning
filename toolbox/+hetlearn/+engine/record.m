function rec = record(rec, k, ctx, S, out, n1m)
%RECORD  Store the learning state of one period, or initialise the record.
%
%   rec = hetlearn.engine.record([], T, ctx)              % allocate T periods
%   rec = hetlearn.engine.record(rec, k, ctx, S, out, n1m) % store period k
%
%   Inputs
%     rec  record struct (or [] to allocate)
%     k    period index into the record (or T when allocating)
%     ctx  engine context (.sys, .learnVars, .groupOf)
%     S    state at the END of the period (hetlearn.engine.update_learning)
%     out  per-period output of update_learning (FE, gain)
%     n1m  struct by learning variable of the RE share used in the model in
%          this period, or [] (history: NaN)
%
%   Record layout
%     rec.eq(i).phi    k_i x T coefficients phi_t (param_names order)
%     rec.eq(i).Rdiag  k_i x T diagonal of R_t
%     rec.eq(i).gain   1 x T gain used in t
%     rec.eq(i).<f>    1 x T extra series of the gain rule, f in
%                      hetlearn.gain.<rule>('fields') (gain_R = Rg_t for
%                      'koz'), from S.gain.rec.<f>.<target> at the end of t
%     rec.var.<x>.n1, n2          discrete-choice shares n1_t, n2_t (group)
%     rec.var.<x>.n1_model        share used in the model in t
%     rec.var.<x>.zetaRE, zetaBR  fitness of the group
%     rec.var.<x>.FE_RE, FE_BR    own squared forecast errors at t
%     rec.var.<x>.fRE, fBR        forecasts of x_{t+1} made in t
%
%   N agent types (ctx.nt, docs/DESIGN_br_extensions.md 1.1): rec.eq follows
%   the keyed system ctx.sys (<target>__<type>; gain-rule series from
%   S.gain.<type>.rec), and rec.var.<x> holds, for each type k of x,
%   n_<k> (discrete-choice share at the end of t; 0 outside the population),
%   n_model_<k> (share in the model in t), U_<k> (fitness; NaN outside the
%   population), FE_<k> (own squared error at t) and f_<k> (forecast of
%   x_{t+1} made in t).

sys = ctx.sys;
lv = ctx.learnVars;
if isfield(ctx, 'nt') && ~isempty(ctx.nt)
    if isempty(rec)
        rec = alloc_nt(k, ctx);
    else
        rec = store_nt(rec, k, ctx, S, out, n1m);
    end
    return
end
if isempty(rec)
    T = k;
    rec = struct();
    rec.T = T;
    rec.eq = struct('phi', {}, 'Rdiag', {}, 'gain', {});
    for i = 1:numel(sys.eq)
        nk = numel(sys.eq(i).param_names);
        rec.eq(i).phi = NaN(nk, T);
        rec.eq(i).Rdiag = NaN(nk, T);
        rec.eq(i).gain = NaN(1, T);
    end
    xf = gain_fields(ctx);
    for i = 1:numel(sys.eq)
        for j = 1:numel(xf)
            rec.eq(i).(xf{j}) = NaN(1, T);
        end
    end
    rec.var = struct();
    f = {'n1', 'n2', 'n1_model', 'zetaRE', 'zetaBR', 'FE_RE', 'FE_BR', 'fRE', 'fBR'};
    for i = 1:numel(lv)
        for j = 1:numel(f)
            rec.var.(lv{i}).(f{j}) = NaN(1, T);
        end
    end
    return
end

for i = 1:numel(sys.eq)
    tg = sys.eq(i).target;
    rec.eq(i).phi(:, k) = S.phi.(tg);
    rec.eq(i).Rdiag(:, k) = diag(S.R.(tg));
    rec.eq(i).gain(k) = out.gain.(tg);
    if isfield(S, 'gain') && isstruct(S.gain) && isfield(S.gain, 'rec')
        xf = fieldnames(S.gain.rec);
        for j = 1:numel(xf)
            if ~isfield(rec.eq, xf{j})
                [rec.eq.(xf{j})] = deal(NaN(1, rec.T));
            end
            rec.eq(i).(xf{j})(k) = S.gain.rec.(xf{j}).(tg);
        end
    end
end
for i = 1:numel(lv)
    x = lv{i};
    g = ctx.groupOf.(x);
    r = rec.var.(x);
    r.n1(k) = S.n1(g);
    r.n2(k) = 1 - S.n1(g);
    r.zetaRE(k) = S.zetaRE(g);
    r.zetaBR(k) = S.zetaBR(g);
    r.FE_RE(k) = out.FE_RE.(x);
    r.FE_BR(k) = out.FE_BR.(x);
    r.fRE(k) = S.fRE.(x);
    r.fBR(k) = S.fBR.(x);
    if ~isempty(n1m)
        r.n1_model(k) = n1m.(x);
    end
    rec.var.(x) = r;
end
end


function f = gain_fields(ctx)
% Extra per-equation series recorded for the gain rule (DESIGN 18).
f = {};
if isfield(ctx, 'opts') && isfield(ctx.opts, 'gain') && isfield(ctx.opts.gain, 'rule')
    f = feval(['hetlearn.gain.' ctx.opts.gain.rule], 'fields');
end
end


% =========================================================================
function rec = alloc_nt(T, ctx)
% record of an N-type run (DESIGN_br_extensions 1.1)
sys = ctx.sys;
nt = ctx.nt;
rec = struct();
rec.T = T;
rec.eq = struct('phi', {}, 'Rdiag', {}, 'gain', {});
xf = {};
for j = 1:numel(nt.types)
    if ~isempty(nt.types(j).sys)
        xf = union(xf, feval(['hetlearn.gain.' nt.types(j).gain.rule], 'fields'), 'stable');
    end
end
for i = 1:numel(sys.eq)
    nk = numel(sys.eq(i).param_names);
    rec.eq(i).phi = NaN(nk, T);
    rec.eq(i).Rdiag = NaN(nk, T);
    rec.eq(i).gain = NaN(1, T);
    for j = 1:numel(xf)
        rec.eq(i).(xf{j}) = NaN(1, T);
    end
end
rec.var = struct();
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    for k = ctx.nt.byvar.(x).names
        for f = {'n_', 'n_model_', 'U_', 'FE_', 'f_'}
            rec.var.(x).([f{1} k{1}]) = NaN(1, T);
        end
    end
end
end


function rec = store_nt(rec, k, ctx, S, out, n1m)
sys = ctx.sys;
nt = ctx.nt;
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    tg = e.target;
    rec.eq(i).phi(:, k) = S.phi.(tg);
    rec.eq(i).Rdiag(:, k) = diag(S.R.(tg));
    rec.eq(i).gain(k) = out.gain.(tg);
    if isfield(S, 'gain') && isfield(S.gain, e.type) && isfield(S.gain.(e.type), 'rec')
        gr = S.gain.(e.type).rec;
        xf = fieldnames(gr);
        for j = 1:numel(xf)
            if ~isfield(rec.eq, xf{j})
                [rec.eq.(xf{j})] = deal(NaN(1, rec.T));
            end
            if isfield(gr.(xf{j}), e.var)
                rec.eq(i).(xf{j})(k) = gr.(xf{j}).(e.var);
            end
        end
    end
end
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    b = nt.byvar.(x);
    g = ctx.groupOf.(x);
    tix = ctx.groups(g).types;
    r = rec.var.(x);
    for jj = 1:numel(b.types)
        kn = b.names{jj};
        p = find(tix == b.types(jj), 1);
        if isempty(p)
            r.(['n_' kn])(k) = 0;
        else
            r.(['n_' kn])(k) = S.n{g}(p);
            r.(['U_' kn])(k) = S.U{g}(p);
        end
        r.(['FE_' kn])(k) = out.FE.(x).(kn);
        r.(['f_' kn])(k) = S.f.(x).(kn);
        if ~isempty(n1m)
            r.(['n_model_' kn])(k) = n1m.(x)(jj);
        end
    end
    rec.var.(x) = r;
end
end
