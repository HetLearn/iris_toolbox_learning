function T = param_table(kind, priors, P0)
%PARAM_TABLE  Estimated parameters: priors (Dynare 4.6.1 parameterisation), hard bounds, start values.
%
%   T = hlest.param_table(kind, priors, P0)
%
%   kind    're'    the 36 SW07 parameters of swX1.mod (7 shock sds, then crhoa ... calfa,
%                   Dynare's order)
%           'learn' the same 36 plus gain, memory (omega), intensity (chi)
%   priors  'ijcb'  learning priors of IJCB App. C (Table C.1): gain Gamma(0.035, 0.015),
%                   memory Beta(0.5, 0.2), chi Gamma(5, 2)                      (default)
%           'calib' centred on the toolbox calibration: gain Gamma(0.0585, 0.015),
%                   memory Beta(0.6, 0.15), chi Gamma(0.51, 0.25)               (variant b)
%   P0      struct with the start values of the SW07 parameters (sw07_params: the swX1
%           mode; shock sds as std_<shock>)
%
%   T (struct; column vectors, cellstr)
%     .name    Dynare name (ea ... calfa, gain, omega, chi)
%     .target  model parameter (std_ea, crhoa, ...) or learning option (gain, memory, intensity)
%     .lb .ub  hard bounds (swX1 estimated_params LB/UB; gain [0.001, 0.25], omega [0, 0.999],
%              chi [0, 50]); the log posterior is -Inf outside
%     .shape   1 beta, 2 gamma, 3 normal, 4 inverse gamma type 1 (Dynare codes)
%     .p1 .p2  prior mean and standard deviation; .p3 .p4 support (beta [0,1], gamma shift 0)
%     .h1 .h2  hyperparameters: beta a, b; gamma shape k, scale; normal mean, sd; IG1 s, nu
%     .x0      start values (SW07: P0; learning: calibration 0.0585, 0.6, 0.51)
%     .learn   true for the three learning parameters;   .n  number of rows

if nargin < 2 || isempty(priors)
    priors = 'ijcb';
end
% name, target, lb, ub, shape, mean, sd   (swX1.mod estimated_params)
R = {
    'ea',         'std_ea',     0.01,   3,      4, 0.1,   2
    'eb',         'std_eb',     0.025,  5,      4, 0.1,   2
    'eg',         'std_eg',     0.01,   3,      4, 0.1,   2
    'eqs',        'std_eqs',    0.01,   3,      4, 0.1,   2
    'em',         'std_em',     0.01,   3,      4, 0.1,   2
    'epinf',      'std_epinf',  0.01,   3,      4, 0.1,   2
    'ew',         'std_ew',     0.01,   3,      4, 0.1,   2
    'crhoa',      'crhoa',      0.01,   0.9999, 1, 0.5,   0.2
    'crhob',      'crhob',      0.01,   0.9999, 1, 0.5,   0.2
    'crhog',      'crhog',      0.01,   0.9999, 1, 0.5,   0.2
    'crhoqs',     'crhoqs',     0.01,   0.9999, 1, 0.5,   0.2
    'crhoms',     'crhoms',     0.01,   0.9999, 1, 0.5,   0.2
    'crhopinf',   'crhopinf',   0.01,   0.9999, 1, 0.5,   0.2
    'crhow',      'crhow',      0.001,  0.9999, 1, 0.5,   0.2
    'cmap',       'cmap',       0.01,   0.9999, 1, 0.5,   0.2
    'cmaw',       'cmaw',       0.01,   0.9999, 1, 0.5,   0.2
    'csadjcost',  'csadjcost',  2,      15,     3, 4,     1.5
    'csigma',     'csigma',     0.25,   3,      3, 1.5,   0.375
    'chabb',      'chabb',      0.001,  0.99,   1, 0.7,   0.1
    'cprobw',     'cprobw',     0.3,    0.95,   1, 0.5,   0.1
    'csigl',      'csigl',      0.25,   10,     3, 2,     0.75
    'cprobp',     'cprobp',     0.5,    0.95,   1, 0.5,   0.1
    'cindw',      'cindw',      0.01,   0.99,   1, 0.5,   0.15
    'cindp',      'cindp',      0.01,   0.99,   1, 0.5,   0.15
    'czcap',      'czcap',      0.01,   1,      1, 0.5,   0.15
    'cfc',        'cfc',        1.0,    3,      3, 1.25,  0.125
    'crpi',       'crpi',       1.0,    3,      3, 1.5,   0.25
    'crr',        'crr',        0.5,    0.975,  1, 0.75,  0.1
    'cry',        'cry',        0.001,  0.5,    3, 0.125, 0.05
    'crdy',       'crdy',       0.001,  0.5,    3, 0.125, 0.05
    'constepinf', 'constepinf', 0.1,    2.0,    2, 0.625, 0.1
    'constebeta', 'constebeta', 0.01,   2.0,    2, 0.25,  0.1
    'constelab',  'constelab',  -10,    10,     3, 0,     2
    'ctrend',     'ctrend',     0.1,    0.8,    3, 0.4,   0.1
    'cgy',        'cgy',        0.01,   2.0,    3, 0.5,   0.25
    'calfa',      'calfa',      0.01,   1.0,    3, 0.3,   0.05
    };
x0 = zeros(size(R, 1), 1);
for i = 1:size(R, 1)
    x0(i) = P0.(R{i, 2});
end
isL = false(size(R, 1), 1);
if strcmp(kind, 'learn')
    switch priors
        case 'ijcb'
            L = {'gain',  'gain',      0.001, 0.25,  2, 0.035,  0.015
                 'omega', 'memory',    0,     0.999, 1, 0.5,    0.2
                 'chi',   'intensity', 0,     50,    2, 5,      2};
        case 'calib'
            L = {'gain',  'gain',      0.001, 0.25,  2, 0.0585, 0.015
                 'omega', 'memory',    0,     0.999, 1, 0.6,    0.15
                 'chi',   'intensity', 0,     50,    2, 0.51,   0.25};
        otherwise
            error('hlest:param_table:priors', 'Unknown prior set %s.', priors);
    end
    R = [R; L];
    x0 = [x0; 0.0585; 0.6; 0.51];
    isL = [isL; true(3, 1)];
elseif ~strcmp(kind, 're')
    error('hlest:param_table:kind', 'kind must be ''re'' or ''learn''.');
end
n = size(R, 1);
T = struct();
T.name = R(:, 1);
T.target = R(:, 2);
T.lb = cell2mat(R(:, 3));
T.ub = cell2mat(R(:, 4));
T.shape = cell2mat(R(:, 5));
T.p1 = cell2mat(R(:, 6));
T.p2 = cell2mat(R(:, 7));
T.p3 = zeros(n, 1);
T.p4 = Inf(n, 1);
T.p3(T.shape == 3) = -Inf;
T.p4(T.shape == 1) = 1;
T.h1 = NaN(n, 1);
T.h2 = NaN(n, 1);
for i = 1:n
    [T.h1(i), T.h2(i)] = hlest.prior_hyper(T.shape(i), T.p1(i), T.p2(i), T.p3(i), T.p4(i));
end
T.x0 = x0;
T.learn = isL;
T.n = n;
T.priors = priors;
T.kind = kind;
end
