function C = conditions_prepare(ctx, refs)
%CONDITIONS_PREPARE  Conditions by forecast period, with targets (DESIGN 5.5).
%
%   C = hetlearn.engine.conditions_prepare(ctx, refs)
%
%   Inputs
%     ctx   engine context (.opts.conditions, .horizon, .xList, .yList,
%           .eList)
%     refs  struct of reference paths: refs.(key) is a databank, key =
%           hetlearn.engine.conditions_key(reference); needed only
%           for type 'delta'
%
%   Output
%     C     1 x H struct array, one per horizon period: .vars (cellstr),
%           .shocks (cellstr, unique), .targets (column vector)
%
%   Each condition: variable (transition or measurement), shock, dates
%   (vector or [start, end]; must lie in the horizon), values (scalar or one
%   per date), type 'level' (default) | 'delta', reference 'self' (default)
%   | scenario id. 'delta' targets = reference path + values. A variable
%   conditioned twice in one period is an error.

hz = ctx.horizon;
C = repmat(struct('vars', {{}}, 'shocks', {{}}, 'targets', zeros(0, 1)), 1, numel(hz));
cs = ctx.opts.conditions;
if isempty(cs)
    return
end
vars = [ctx.xList(:); ctx.yList(:)];
for i = 1:numel(cs)
    c = normalise(cs(i), i);
    if ~any(strcmp(vars, c.variable))
        error('hetlearn:engine:conditions', 'conditions(%d): %s is not a variable of the model.', i, c.variable);
    end
    if ~any(strcmp(ctx.eList, c.shock))
        error('hetlearn:engine:conditions', 'conditions(%d): %s is not a shock of the model.', i, c.shock);
    end
    dt = hetlearn.util.to_dates(c.dates);
    v = double(c.values(:));
    if isscalar(v)
        v = repmat(v, numel(dt), 1);
    end
    if numel(v) ~= numel(dt)
        error('hetlearn:engine:conditions', 'conditions(%d): %d values for %d dates.', i, numel(v), numel(dt));
    end
    for q = 1:numel(dt)
        k = find(hetlearn.util.date_eq(hz, dt(q)), 1);
        if isempty(k)
            error('hetlearn:engine:conditions', 'conditions(%d): date %s is outside the forecast horizon.', ...
                i, char(dat2str(dt(q))));
        end
        tgt = v(q);
        if strcmp(c.type, 'delta')
            key = hetlearn.engine.conditions_key(c.reference);
            tgt = refs.(key).(c.variable)(dt(q)) + v(q);
        end
        if any(strcmp(C(k).vars, c.variable))
            error('hetlearn:engine:conditions', 'Variable %s is conditioned twice in %s.', ...
                c.variable, char(dat2str(dt(q))));
        end
        C(k).vars{end+1} = c.variable;
        C(k).targets(end+1, 1) = tgt;
        if ~any(strcmp(C(k).shocks, c.shock))
            C(k).shocks{end+1} = c.shock;
        end
    end
end
end


function c = normalise(c, i)
need = {'variable', 'shock', 'dates', 'values'};
for k = 1:numel(need)
    if ~isfield(c, need{k}) || isempty(c.(need{k}))
        error('hetlearn:engine:conditions', 'conditions(%d) needs field %s.', i, need{k});
    end
end
c.variable = char(c.variable);
c.shock = char(c.shock);
if ~isfield(c, 'type') || isempty(c.type)
    c.type = 'level';
end
c.type = char(c.type);
if ~any(strcmp(c.type, {'level', 'delta'}))
    error('hetlearn:engine:conditions', 'conditions(%d).type must be ''level'' or ''delta''.', i);
end
if ~isfield(c, 'reference') || isempty(c.reference)
    c.reference = 'self';
end
c.reference = char(c.reference);
end
