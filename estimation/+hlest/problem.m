function pb = problem(kind, varargin)
%PROBLEM  Build an estimation problem: data, models, parameter table, solver indices.
%
%   pb = hlest.problem('re')
%   pb = hlest.problem('learn', name, value, ...)
%
%   're'     RE benchmark: the original SW07 model (36 parameters).
%   'learn'  a1_learn configuration: anchored RE agents, AR(1) learners on pinf with a
%            constant, constant gain, per-variable shares, facility 'plm_alm'
%            (36 + gain, memory, chi).
%   Options of 'learn' (defaults = a1_learn):
%     'info'          'lagged' | 'current'                        beliefs.info
%     'priors'        'ijcb' | 'calib'                            learning priors (param_table)
%     'mode'          'switching' | 'rational' | 'fixed_shares'   expectations.mode (gate G3)
%     'fixed_n2'      learners' share for 'fixed_shares'
%     'init_n2'       0.5                                          shares.init_n2
%     'init_beliefs'  're_moments' (RE moments at each theta) | 'fixed' ('phi0', 'R0')
%     'gap'           'filter' (default: learning continues on the filtered values when a
%                     quarter has no data, 2020Q1-Q3) | 'freeze' (no RLS, no share update)
%
%   pb fields: kind, cfg, spec, tab (hlest.param_table), n, lb, ub, nstruct (36), Pbase
%   (struct of every original-model parameter at swX1), mo (original IRIS model), Y (ny x nT
%   data, NaN = missing), dates (IRIS date codes), nT, ilike (first quarter of the likelihood
%   sum, 1966Q1), t0 (first learning quarter, 1966Q1 = beliefs.init.date default), yl, el,
%   xb (names of the predetermined states), ip (pinf in xb), pos_pinf (pinf row of the
%   original model's solution); 'learn' also: opts, mL (extended model), info (load_model),
%   anchor_names, sx (static-elimination indices, hlest.reduce_static), belief names, learn
%   (settings above), ig/iom/ichi (positions of gain, memory, chi in theta).

ip = inputParser;
ip.addParameter('info', 'lagged');
ip.addParameter('priors', 'ijcb');
ip.addParameter('mode', 'switching');
ip.addParameter('fixed_n2', []);
ip.addParameter('init_n2', 0.5);
ip.addParameter('init_beliefs', 're_moments');
ip.addParameter('phi0', []);
ip.addParameter('R0', []);
ip.addParameter('gap', 'filter');
ip.parse(varargin{:});
o = ip.Results;

cfg = est_config();
spec = hetlearn.load_spec(cfg.model);
P0 = call_params(spec);

pb = struct();
pb.kind = kind;
pb.cfg = cfg;
pb.spec = spec;
pb.tab = hlest.param_table(kind, o.priors, P0);
pb.n = pb.tab.n;
pb.lb = pb.tab.lb;
pb.ub = pb.tab.ub;
pb.nstruct = 36;

% ---- original model at the swX1 mode ----------------------------------------------------
mo = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true);
pl = fieldnames(get(mo, 'parameters'));
el = cellstr(get(mo, 'eList'));
f = fieldnames(P0);
keep = ismember(f, pl) | ismember(f, strcat('std_', el));
Pbase = struct();
for i = find(keep)'
    Pbase.(f{i}) = P0.(f{i});
end
miss = setdiff(pb.tab.target(1:pb.nstruct), fieldnames(Pbase));
if ~isempty(miss)
    error('hlest:problem:params', 'Estimated parameters not in the model: %s.', strjoin(miss, ', '));
end
mo = assign(mo, Pbase);
[mo, flag] = solve(mo, 'Warning', false);
if ~hasSucceeded(flag)
    error('hlest:problem:solve', 'The original model does not solve at the swX1 mode.');
end
pb.Pbase = Pbase;
pb.mo = mo;
pb.el = el;
pb.yl = cellstr(get(mo, 'yList'));
pb.xv = cellstr(get(mo, 'xVector'));
pb.xb = reshape(cellstr(get(mo, 'xbVector')), 1, []);
nb = numel(pb.xb);
nf = numel(pb.xv) - nb;
pb.pos_pinf = find(strcmp(pb.xv, 'pinf'), 1);
pb.ip = find(strcmp(pb.xb, 'pinf'));
if isempty(pb.ip) || pb.pos_pinf ~= nf + pb.ip
    error('hlest:problem:pinf', 'pinf is not a predetermined state of the original model.');
end

% ---- data ------------------------------------------------------------------------------
d = hetlearn.load_database(spec);
fr = hetlearn.util.to_dates(spec.filter_range);
rng = fr(1):fr(end);
Y = NaN(numel(pb.yl), numel(rng));
for i = 1:numel(pb.yl)
    Y(i, :) = reshape(d.(pb.yl{i})(rng), 1, []);
end
pb.Y = Y;
pb.dates = double(rng);
pb.nT = numel(rng);
pb.ilike = find(abs(pb.dates - double(qq(cfg.like_start(1), cfg.like_start(2)))) < 1e-6);
pb.t0 = pb.ilike;
pb.obs = isfinite(Y);
pb.learn = [];

if strcmp(kind, 're')
    return
end

% ---- learning model (extended model of a1_learn) --------------------------------------------
cfgS = a1_learn();
cfgS.beliefs.info = o.info;
opts = hetlearn.load_options(cfgS);
[mL, info] = hetlearn.load_model(spec, opts);
if ~isequal(reshape(cellstr(info.meta.re_states), 1, []), pb.xb)
    error('hlest:problem:states', 'Anchored-RE states differ from the original model''s state vector.');
end
if ~isequal(reshape(cellstr(info.learnVars), 1, []), {'pinf'})
    error('hlest:problem:learnVars', 'The estimator supports learning on pinf only.');
end
eL = cellstr(get(mL, 'eList'));
if ~isequal(eL(:), el(:))
    error('hlest:problem:shocks', 'Shock order differs between the original and the extended model.');
end
pLm = cellstr(get(mL, 'pList'));
fb = fieldnames(Pbase);
okp = ismember(fb, pLm) | ismember(fb, strcat('std_', eL));
if ~all(okp)
    error('hlest:problem:extParams', 'Parameters missing in the extended model: %s.', strjoin(fb(~okp), ', '));
end
pb.opts = opts;
pb.info = info;
pb.anchor_names = hetlearn.plm.anchor_names('pinf', pb.xb);
pb.bnames = struct('n1', 'n1_pinf', 'n2', 'n2_pinf', 'alpha', 'alpha_pinf', 'beta', 'beta_pinf');
pe = info.sys.eq(1).param_names;
if ~isequal(pe, {'alpha_pinf', 'beta_pinf'})
    error('hlest:problem:plm', 'Expected an AR(1) PLM with constant on pinf (alpha_pinf, beta_pinf).');
end
% extended model at the swX1 mode with its anchored coefficients (load_model did this)
pb.mL = mL;

% ---- indices of the parametric system and of the static elimination --------------------------
[A, B, ~, ~, ~, ~, ~, ~, list, numF] = system(mL, 'MatrixFormat', 'plain', 'Normalize', false);
x1 = cellstr(list{2});
teq = cellstr(list{5});
rowE = find(~cellfun(@isempty, regexp(teq, '^pinf_exp1\s*=\s*n1_pinf', 'once')));
rowB = find(~cellfun(@isempty, regexp(teq, '^pinf_exp1_BR\s*=', 'once')));
iE = find(strcmp(x1, 'pinf_exp1{1}'));
iRE = find(strcmp(x1, 'pinf_exp1_RE{1}'));
iBR = find(strcmp(x1, 'pinf_exp1_BR{1}'));
iP = find(strcmp(x1, 'pinf'));
if ~(isscalar(rowE) && isscalar(rowB) && isscalar(iE) && isscalar(iRE) && isscalar(iBR) && isscalar(iP))
    error('hlest:problem:locate', 'Belief and share entries of the pinf block not found uniquely.');
end
nx = numel(x1);
xbL = reshape(x1(numF+1:end), 1, []);
if ~isequal(xbL, pb.xb)
    error('hlest:problem:xb', 'The extended model''s predetermined states differ from the original model''s.');
end
Sall = find(all(A(:, 1:numF) == 0, 1));
if ~all(ismember([iE iRE iBR], Sall))
    error('hlest:problem:static', 'pinf_exp1, pinf_exp1_RE, pinf_exp1_BR are expected to be static.');
end
S = setdiff(Sall, [iE iRE iBR]);
rows2 = [rowE rowB];
if any(any(B(rows2, S))) || any(any(A(rows2, S)))
    error('hlest:problem:static', 'Rows of the pinf block involve other static variables.');
end
N = setdiff(1:nx, S);
sx = struct();
sx.S = S;
sx.O = setdiff(1:size(A, 1), rows2);
sx.N = N;
sx.rows2 = rows2;
sx.jE = find(N == iE);
sx.jRE = find(N == iRE);
sx.jBR = find(N == iBR);
sx.jP = find(N == iP);
sx.s3 = [sx.jE sx.jRE sx.jBR];
sx.keepc = setdiff(1:numel(N), sx.s3);
sx.nu2 = numF - numel(S) - 3;
sx.nb = nx - numF;
sx.sE = B(rowE, iE);
sx.sB = B(rowB, iBR);
sx.current = strcmp(o.info, 'current');
sx.full = struct('rowE', rowE, 'rowB', rowB, 'iE', iE, 'iRE', iRE, 'iBR', iBR, 'iP', iP, ...
    'numF', numF, 'nx', nx, 'x1', {x1}, 'n_static', numel(Sall));
pb.sx = sx;

pb.learn = struct('mode', o.mode, 'fixed_n2', o.fixed_n2, 'init_n2', o.init_n2, 'info', o.info, ...
    'gap', o.gap, 'init_beliefs', o.init_beliefs, 'phi0', o.phi0, 'R0', o.R0);
pb.ig = find(strcmp(pb.tab.name, 'gain'));
pb.iom = find(strcmp(pb.tab.name, 'omega'));
pb.ichi = find(strcmp(pb.tab.name, 'chi'));
end


function P = call_params(spec)
added = false;
if ~any(strcmpi(strsplit(path, pathsep), spec.folder))
    addpath(spec.folder);
    added = true;
end
P = feval(spec.params);
if added
    rmpath(spec.folder);
end
end
