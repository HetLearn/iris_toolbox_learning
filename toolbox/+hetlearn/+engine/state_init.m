function [S, ctx] = state_init(ctx, m, H)
%STATE_INIT  Initial learning state: beliefs, R, fitness, shares (DESIGN 4.5, 4.7).
%
%   [S, ctx] = hetlearn.engine.state_init(ctx, m, H)
%
%   Inputs
%     ctx  engine context (hetlearn.engine.core): .opts, .sys, .learnVars
%     m    the loaded RE model (hetlearn.load_model), for 're_moments'
%     H    RE filter output (hetlearn.re_filter), for 'training_ols'
%
%   Outputs
%     S    state struct
%            .phi.<target>, .R.<target>   beliefs in force (phi_{t-1}, R_{t-1})
%            .zetaRE, .zetaBR, .n1        row vectors by share group
%            .fRE.<x>, .fBR.<x>           last forecasts made (NaN at start)
%            .fe_hist.<target>            past RLS forecast errors (column)
%            .phi_hist.<target>           past coefficient vectors (k x T)
%            .gain                        gain-rule state, hetlearn.gain.<rule>('init',
%                                         sys, learnVars, opts.gain) (DESIGN 18)
%     ctx  with share groups added:
%            .groups(g).G        variables whose squared errors are summed
%            .groups(g).members  learning variables using this group's shares
%            .groupOf.<x>        group index of learning variable x
%
%   Initial beliefs: beliefs.init.method 're_moments' (hetlearn.init.re_moments
%   on m), 'training_ols' (hetlearn.init.training_ols on H.smooth, or on
%   H.filtered under history.re_states = 'filtered', over
%   beliefs.init.training_range) or 'user' (hetlearn.init.user with
%   re_moments as fallback). Initial fitness: hetlearn.switching.init_fitness
%   (shares.init_n2, switching.intensity); initial n1 = 1 - shares.init_n2.
%
%   N agent types (ctx.info.nt from hetlearn.load_model; docs/
%   DESIGN_br_extensions.md 1.1-1.2): the state and share groups of
%   hetlearn.engine.ntypes('init', ...) instead (beliefs, gains and fitness
%   per type, shares over the types of each group); ctx.nt is set. The
%   two-type state below is unchanged otherwise.

o = ctx.opts;
sys = ctx.sys;
learnVars = ctx.learnVars;
mInit = m;      % Ramsey runs (DESIGN 13): RE moments of the estimated rule model
if isfield(ctx, 'info') && isfield(ctx.info, 'policy') && ~isempty(ctx.info.policy) ...
        && ~isempty(ctx.info.policy.rule_model)
    mInit = ctx.info.policy.rule_model;
end
if isfield(ctx, 'info') && isfield(ctx.info, 'nt') && ~isempty(ctx.info.nt)
    [S, ctx] = hetlearn.engine.ntypes('init', ctx, mInit, H);     % N agent types
    return
end

% ---- beliefs ---------------------------------------------------------------------
if isempty(sys.eq)
    phi = struct();
    R = struct();
else
    switch o.beliefs.init.method
        case 're_moments'
            [phi, R] = hetlearn.init.re_moments(mInit, sys);
        case 'training_ols'      % on the history the learners watch (history.re_states)
            [phi, R] = hetlearn.init.training_ols(sys, hetlearn.engine.history_db(o, H), ...
                hetlearn.util.to_dates(o.beliefs.init.training_range));
        case 'user'
            [phiF, RF] = hetlearn.init.re_moments(mInit, sys);
            [phi, R] = hetlearn.init.user(sys, o.beliefs.init.values, phiF, RF);
    end
end

% ---- share groups ------------------------------------------------------------------
groups = struct('G', {}, 'members', {});
groupOf = struct();
switch o.shares.structure
    case 'per_variable'
        for i = 1:numel(learnVars)
            groups(i).G = learnVars(i);
            groups(i).members = learnVars(i);
            groupOf.(learnVars{i}) = i;
        end
    case 'universal'
        G = reshape(cellstr(o.shares.master), 1, []);
        bad = setdiff(G, learnVars);
        if ~isempty(bad)
            error('hetlearn:engine:master', ...
                'shares.master must name learning variables; not learning: %s.', strjoin(bad, ', '));
        end
        if ~isempty(learnVars)
            groups(1).G = G;
            groups(1).members = learnVars;
            for i = 1:numel(learnVars)
                groupOf.(learnVars{i}) = 1;
            end
        end
end
ctx.groups = groups;
ctx.groupOf = groupOf;

nG = numel(groups);
n2 = o.shares.init_n2;
[zRE, zBR] = hetlearn.switching.init_fitness(n2 * ones(1, nG), o.switching.intensity);

S = struct();
S.phi = phi;
S.R = R;
S.zetaRE = zRE;
S.zetaBR = zBR;
S.n1 = (1 - n2) * ones(1, nG);
S.fRE = struct();
S.fBR = struct();
for i = 1:numel(learnVars)
    S.fRE.(learnVars{i}) = NaN;
    S.fBR.(learnVars{i}) = NaN;
end
S.fe_hist = struct();
S.phi_hist = struct();
for i = 1:numel(sys.eq)
    tg = sys.eq(i).target;
    S.fe_hist.(tg) = zeros(0, 1);
    S.phi_hist.(tg) = zeros(numel(sys.eq(i).param_names), 0);
end
S.gain = feval(['hetlearn.gain.' o.gain.rule], 'init', sys, learnVars, o.gain);   % DESIGN 18
end
