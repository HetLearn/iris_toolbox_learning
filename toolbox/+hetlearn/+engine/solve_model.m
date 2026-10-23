function [m, ok, msg, si] = solve_model(m, spec)
%SOLVE_MODEL  Steady state (nonlinear models) and first-order solution, with the backward fallback.
%
%   [m, ok, msg] = hetlearn.engine.solve_model(m, spec)
%   [m, ok, msg, si] = hetlearn.engine.solve_model(m, spec)
%
%   Inputs
%     m     IRIS Model with parameters assigned
%     spec  model spec; spec.sstate (function name or handle m = f(m)) is
%           called before solve when given; nonlinear models without it
%           use sstate(m) before solve.
%
%   Outputs
%     m     solved model
%     ok    true if solve returned a unique stable solution (hasSucceeded),
%           or if the backward fallback below applies
%     msg   text of the solve flag ('' when IRIS succeeded)
%     si    struct: .flag (IRIS stability flag as text, e.g. 'UNIQUE_STABLE'),
%           .iris_ok (hasSucceeded), .backward (true when the backward
%           system below is used), .maxroot (its largest abs root, NaN
%           otherwise). The projection facility (hetlearn.engine.facility)
%           reads it: under 'alm' and 'plm_alm' a backward system with
%           maxroot > 1 is an unstable ALM.
%
%   Backward fallback (DESIGN 11). A linear model without leads
%   (get(m,'maxLead') = 0, e.g. the anchored RE variant with every
%   forward-looking variable learning and every max lead 1) has a solution
%   for any beliefs and shares, possibly explosive, but IRIS solve rejects
%   explosive solutions. When IRIS fails on such a model, the backward
%   system of hetlearn.engine.backward_simulate(m) is stored in the model's
%   user data (field hetlearn_backward); ok = true and msg names the IRIS
%   flag and the largest absolute root. hetlearn.engine.step then simulates
%   with it and logs an 'explosive' event. A successful IRIS solve removes a
%   stored system. IRIS warnings of the failed trial solve are suppressed
%   for models without leads. Models with leads are unchanged: ok = false
%   and the projection facility applies (hetlearn.engine.facility).
%
%   Caches in the model's user data:
%     hetlearn_maxlead  get(m,'maxLead'), computed once per model object (the
%                       lead structure does not depend on parameters)
%     hetlearn_sspace   after every successful IRIS solve, the state-space
%                       system of the fast one-period step,
%                       hetlearn.engine.step('build', m, previous), only when the
%                       user data field hetlearn_step is 'fast' (option
%                       engine.step, set by hetlearn.engine.core); removed when
%                       IRIS fails (the backward system or the projection
%                       facility then applies).
%
%   See also hetlearn.engine.backward_simulate, hetlearn.engine.step.

msg = '';
if isfield(spec, 'sstate') && ~isempty(spec.sstate)
    if ischar(spec.sstate) || isstring(spec.sstate)
        m = feval(char(spec.sstate), m);
    else
        m = spec.sstate(m);
    end
elseif ~logical(spec.linear)
    m = sstate(m);
end
u = userdata(m);
if ~isstruct(u)
    u = struct();
end
if isfield(u, 'hetlearn_maxlead')
    maxLead = u.hetlearn_maxlead;
else
    maxLead = get(m, 'maxLead');
    u.hetlearn_maxlead = maxLead;
end
noLeads = logical(spec.linear) && maxLead <= 0;
if noLeads
    ws = warning('off', 'all');
    [m, flag] = solve(m);
    warning(ws);
else
    [m, flag] = solve(m);
end
ok = hasSucceeded(flag);
si = struct('flag', '', 'iris_ok', ok, 'backward', false, 'maxroot', NaN);
try
    si.flag = char(string(flag));
catch
    si.flag = class(flag);
end
prev = [];
if isfield(u, 'hetlearn_sspace')
    prev = u.hetlearn_sspace;
    u = rmfield(u, 'hetlearn_sspace');
end
if isfield(u, 'hetlearn_backward')
    u = rmfield(u, 'hetlearn_backward');
end
if ok
    if isfield(u, 'hetlearn_step') && strcmpi(char(u.hetlearn_step), 'fast')
        u.hetlearn_sspace = hetlearn.engine.step('build', m, prev);
    end
    m = userdata(m, u);
    return
end
m = userdata(m, u);
try
    msg = char(string(flag));
catch
    msg = class(flag);
end
if noLeads
    bw = hetlearn.engine.backward_simulate(m);
    if bw.ok
        bw.flag = msg;
        si.backward = true;
        si.maxroot = bw.maxroot;
        m = store_backward(m, bw);
        ok = true;
        msg = sprintf('%s; backward system used, largest abs root %.6g', msg, bw.maxroot);
    else
        msg = sprintf('%s; no backward system (%s)', msg, bw.reason);
    end
end
end


function m = store_backward(m, bw)
u = userdata(m);
if isempty(bw)
    if isstruct(u) && isfield(u, 'hetlearn_backward')
        m = userdata(m, rmfield(u, 'hetlearn_backward'));
    end
    return
end
if ~isstruct(u)
    u = struct();
end
u.hetlearn_backward = bw;
m = userdata(m, u);
end
