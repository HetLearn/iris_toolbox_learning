# Your own model

`hetlearn` works with any linear IRIS model that has forward-looking terms. You do not change
the model to add learners: the toolbox reads your model file, finds every lead, and writes an
extended version in which the expectations of the variables you choose are a mix of RE agents
and learners. This page takes you from a model file to a first run. The worked example is the
three-equation New Keynesian model of Özden (2025), package `models/ijcb3/` in the repository.

## What you need

| File | What it is |
|---|---|
| `models/<name>/<name>.model` | The IRIS model file, linear, with leads written as `x{+1}` |
| `models/<name>/<name>_params.m` | A function returning a struct with every parameter and every shock standard deviation |
| `models/<name>/data/<name>_database.csv` | The observables as an IRIS databank (CSV from `databank.toCSV`, or a `.mat`) |
| `models/<name>/model_spec.m` | The package contract: a function returning `spec` |
| `scenarios/<name>/.../*.m` | Your scenario files |

## Step 1: the model file

A plain IRIS model file. The toolbox only needs leads of transition variables; every
`x{+1}` becomes an expectation that can be heterogeneous.

```text
!transition_variables
    "Output gap" y
    "Inflation, % q/q" pinf
    "Nominal policy rate, % per quarter" r
    "Demand shock process" u_y
    "Cost-push shock process" u_pinf

!transition_shocks
    "Demand innovation" eps_y
    "Cost-push innovation" eps_pinf
    "Monetary policy shock, i.i.d." eps_r

!parameters
    beta, tau, kappa, iota_y, iota_p, phi_pi, phi_y, phi_dy, rho_r, rho_y, rho_pi, pi_bar, r_bar_T

!transition_equations
    "IS curve, hybrid (IJCB eq. 1)"
    y = (1 - iota_y)*y{+1} + iota_y*y{-1} - (1/tau)*(r - pinf{+1}) + u_y;

    "Phillips curve, hybrid (IJCB eq. 1)"
    pinf = beta*((1 - iota_p)*pinf{+1} + iota_p*pinf{-1}) + kappa*y + u_pinf;

    "Monetary policy rule, Taylor rule with smoothing (IJCB eq. 1)"
    r = rho_r*r{-1} + (1 - rho_r)*(phi_pi*pinf + phi_y*y) + phi_dy*(y - y{-1}) + eps_r;

    u_y = rho_y*u_y{-1} + eps_y;
    u_pinf = rho_pi*u_pinf{-1} + eps_pinf;

!measurement_variables
    yobs, pinfobs, robs

!measurement_equations
    yobs = y;
    pinfobs = pi_bar + pinf;
    robs = r_bar_T + r;
```

Notes:

- **Lead notation.** IRIS 20230622 reads `x{+1}` and `x(+1)`. The toolbox also accepts `x{1}`,
  `x[+1]`, `x{t+1}` and `//` or `/* */` comments, and converts them for IRIS (it then keeps a
  normalised copy, `generated/<name>_norm.model`).
- **Leads of two or more periods** work: `x{+2}` becomes a chain through the one-step
  expectation.
- **Equation labels** (the quoted text before an equation) are optional, but the policy rule
  needs one if you want Ramsey policy, and equation-specific transforms refer to labels.
- **Your own `!if` switches** are allowed; set their values in `spec.assign`.
- **Linear models only.** `spec.linear = true`.

## Step 2: the parameters

A function in the package folder that returns a struct with every parameter, including the
standard deviation of every shock as `std_<shock>` (and of measurement shocks, if any):

```matlab
function P = ijcb3_params()
% Ozden (2025), Table 1, heterogeneous-expectations posterior means
P = struct();
P.beta = 0.99;          % fixed
P.tau = 1.13;
P.kappa = 0.0032;
P.iota_y = 0.06;
P.iota_p = 0.15;
P.phi_pi = 1.53;
P.phi_y = 0.42;
P.phi_dy = 0.12;
P.rho_r = 0.92;
P.rho_y = 0.95;
P.rho_pi = 0.04;
P.pi_bar = 0.58;        % trends in the measurement equations, % per quarter
P.r_bar_T = 0.26;
P.std_eps_y = 0.32;     % one std_<shock> per shock
P.std_eps_pinf = 0.38;
P.std_eps_r = 0.24;
end
```

You can keep several parameter files in the package and switch between them with the option
`model_params`. The project uses published parameter values; the toolbox does not estimate
them.

## Step 3: the database

An IRIS databank with one quarterly series per observable, saved as CSV:

```matlab
d = struct();
d.yobs    = Series(qq(1957, 1), yobs_values);      % column vectors of data
d.pinfobs = Series(qq(1957, 1), pinfobs_values);
d.robs    = Series(qq(1957, 1), robs_values);      % NaN where the rate is not observed
databank.toCSV(d, fullfile('models', 'ijcb3', 'data', 'ijcb3_database.csv'));
```

Missing values (NaN) are fine: the Kalman filter skips them. The ijcb3 package treats the
federal funds rate as missing at the effective lower bound, so the filter infers a shadow rate.

## Step 4: the package contract

`models/<name>/model_spec.m`, a function with no inputs:

```matlab
function spec = model_spec()
spec = struct();
spec.name = 'ijcb3';                                  % used in generated file names
spec.folder = fileparts(mfilename('fullpath'));       % always this line
spec.model_file = 'ijcb3.model';                      % relative to the folder
spec.params = 'ijcb3_params';                         % parameter function
spec.sstate = '';                                     % steady-state function (nonlinear models); '' here
spec.linear = true;
spec.assign = struct();                               % values of the model file's own !if switches
spec.database = 'data/ijcb3_database.csv';
spec.filter_range = [qq(1960, 1), qq(2026, 2)];       % RE filter and smoother range
spec.observables = {'yobs', 'pinfobs', 'robs'};

% Optional: reporting labels, units and the scale to report units (4 annualises a quarterly rate)
report = struct();
report.labels = struct('yobs', 'Output gap', 'pinfobs', 'Inflation (CPI)', 'robs', 'Federal funds rate');
report.units = struct('yobs', '% of trend output', 'pinfobs', '% q/q annualised', 'robs', '% annualised');
report.scale = struct('yobs', 1, 'pinfobs', 4, 'robs', 4);
spec.report = report;

% Optional: needed only for Ramsey policy and the policy loss
% spec.policy = struct('instrument', 'r', ...
%     'rule_label', 'Monetary policy rule, Taylor rule with smoothing (IJCB eq. 1)', ...
%     'targets', struct('pinf', '4*pinf', 'ygap', 'y', 'r', '4*r', 'dr', '4*(r - r{-1})'), ...
%     'discount', 'beta');
end
```

Required fields: `name`, `model_file`, `params`, `linear`. The others default to empty.

## Step 5: generate and check

```matlab
setup_paths
spec = hetlearn.load_spec('ijcb3');
cfg = struct('model', 'ijcb3');
cfg.expectations.variables = {'pinf'};
opts = hetlearn.load_options(cfg, struct());     % struct() = no project master options
[m, info] = hetlearn.load_model(spec, opts);     % writes generated/ijcb3_ext_ar1.model, runs the collapse test
info.meta.forward_vars                           % the variables that can learn: y, pinf
H = hetlearn.re_filter(spec, opts);              % RE filter and smoother, cached
H.fit_error                                      % how well the smoothed states rebuild the data
```

`hetlearn.load_model` checks every generated file with a **collapse test**: with every RE share
at 1 the extended model must reproduce the impulse responses of your original model to 1e-10.
`hetlearn.re_filter` stops if the smoothed states and shocks do not rebuild the data to 1e-8
(when the model has at least as many shocks as observables).

The second argument of `hetlearn.load_options` replaces `config/master_options.m`. Use it while
you set up a new model if the project's master options hold values for another model (the
SW07 baseline sets `model_params = 'sw07_params_original'`, a file of the SW07 package).

## Step 6: scenarios

Start the new model's RE parent from an empty struct, not from an SW07 scenario (`sw07_re`
loads SW07 and checks the SW07 inflation peak):

```matlab
function cfg = i1_re()
cfg = struct();
cfg.id = 'i1_re';
cfg.title = 'IJCB3: forecast from the 2022Q2 CPI inflation peak, rational expectations';
cfg.model = 'ijcb3';
spec = hetlearn.load_spec(cfg.model);
db = hetlearn.load_database(spec);
cfg.forecast.origin = hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4));
cfg.forecast.horizon = 16;
cfg.expectations.mode = 'rational';
cfg.expectations.variables = {'pinf'};
cfg.model_params = '';                     % this package's own parameters, whatever the master says
end

function cfg = i1_learn()
cfg = i1_re();
cfg.id = 'i1_learn';
cfg.expectations.mode = 'switching';
cfg.gain.value = 0.0585;                   % Ozden (2025), Table 1
cfg.switching.memory = 0.62;
cfg.switching.intensity = 0.51;
cfg.compare_with = {'i1_re'};
end
```

Save them under `scenarios/ijcb3/app1_peak/` (run `setup_paths` again after creating a new
folder), then:

```matlab
res_re = hetlearn.run(i1_re());
res    = hetlearn.run(i1_learn());
```

Values set in `config/master_options.m` reach these scenarios too. Pin anything the master
sets for another model, as `cfg.model_params = ''` does here.

## What the toolbox writes into your model

For each learning variable `x` the extended model gets an expectation variable `x_exp1` in
place of `x{+1}` and the block

```text
x_exp1 = n1_x*x_exp1_RE + n2_x*x_exp1_BR;
```

with the RE agents' and the learners' forecasts behind `!if` switches that the toolbox sets
from the options:

| Switch | Set from | Effect |
|---|---|---|
| `br_<x>` | `expectations.variables` | `true`: x's expectation is the RE/learner mix; `false`: pure RE |
| `re_anchored` | `expectations.re_variant` | anchored RE agents instead of `x{+1}` |
| `ramsey` | `policy.mode` | the loss function in place of the rule equation |
| `br_info_current` | `beliefs.info` | learners see period-t data |

`expectations.re_info = 'lagged'` uses a second generated file,
`<name>_ext_<tag>_relag.model`, in which the RE expectations of the learning set use data up to
t-1. Generated files and RE filter caches live in `models/<name>/generated/`; their names carry
a hash of the model text, the PLM spec and the parameters, so a stale file is never used.
Delete the folder to force a rebuild.

## Limits

- Linear models only; `spec.sstate` exists for nonlinear models but no package uses it.
- Anchored RE agents need plain state names (`hetlearn:load_model:anchored` otherwise).
- `expectations.re_info = 'lagged'` needs learning variables with a maximum lead of 1.
- The inversion history needs at least as many shocks as observables.
- Ramsey policy needs `spec.policy`.

## Other templates in the repository

| Package | Model | Use as a template for |
|---|---|---|
| `models/ijcb3/` | three-equation NK model, Özden (2025) | a small model with missing data (ELB) |
| `models/as07/` | An and Schorfheide (2007) | measurement errors (`std_me_*` in the parameter file) and annualised observables (report scale 1) |
| `models/sw07/` | Smets and Wouters (2007) | a medium-scale model, two parameter sets, a policy section |
| `tests/toy_nk/` | toy hybrid NK model | mixed lead notations, a two-period lead, a policy section with quarterly targets |

Each package has a `README.md`, a `data/README.md` with `build_database.m`, and a
`validation/` folder that checks the package against Dynare or the authors' code.
