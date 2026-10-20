function [ll, out] = loglik_learn_pe(pb, theta, varargin)
%LOGLIK_LEARN_PE  hlest.loglik_learn plus the one-step-ahead prediction errors (est_06_post).
%
%   A copy of hlest.loglik_learn (2026-10-19) with two extra records under 'paths', true:
%   out.v (ny x nT, prediction errors y_t - Z a_{t|t-1} - D, NaN where y is missing) and
%   out.Fd (the diagonal of their covariance F_t). Written as a separate function because
%   loglik_learn could not be edited while the learning chains ran; est_06_post checks that
%   both return the same l_t at the mode. Everything below is loglik_learn's text.
%
%   Log likelihood of the learning model: time-varying Kalman filter of the ALM.
%
%   [ll, out] = hlest.loglik_learn_pe(pb, theta)
%   [ll, out] = hlest.loglik_learn_pe(pb, theta, 'paths', true, 'check_iris', false)
%
%   Model: a1_learn (pb = hlest.problem('learn', ...)). Quarter t (DESIGN_estimation 2.2):
%   the ALM in force in t was solved at the end of t-1 with (phi_{t-1}, model shares n1m_t);
%   Kalman prediction and update with y_t (NaN rows dropped; no data: l_t = 0); the agents use
%   the filtered point estimates: f^RE_t = k + c' a_{t|t} (anchored RE), f^BR_t from phi_{t-1}
%   ('lagged': alpha + beta (alpha + beta pinf_{t-1|t-1}); 'current': alpha + beta pinf_{t|t});
%   squared errors of last quarter's forecasts, fitness and discrete-choice shares (not in t0);
%   constant-gain RLS on z = [1; pinf_{t-1|t-1}], target pinf_{t|t}; projection facility
%   'plm_alm' exactly as hetlearn.engine.update_learning/facility: candidate |beta| > 1 or
%   non-finite -> keep phi, R (projection_plm); ALM of (phi_t, n_t) without a unique stable
%   solution -> revert every belief (projection_alm) -> still none -> keep the model shares in
%   force in t for t+1 (projection_alm_shares) -> still none -> log L = -Inf. 1965Q1-Q4 is a
%   presample filtered with the RE ALM; learning starts in pb.t0 (1966Q1) from phi_0, R_0 (RE
%   moments at theta, or fixed) and n2_0; the likelihood sums l_t over pb.ilike:end.
%
%   Options
%     'paths'       false (default) | true (all filtered paths) | 'light' (no filtered states
%                   and shocks: what the MCMC chains store)
%     'check_iris'  also solve every ALM with IRIS and compare (gate G5; slow)
%     'start_state' struct('a', a, 'P', P): state mean and MSE at t0-1 (1965Q4) instead of the
%                   presample filter from the stochastic initial condition (gate G4: with the
%                   engine's RE-smoothed 1965Q4 state and P = 0 the filter is the inversion)
%
%   out  .status, .ev_plm .ev_alm .ev_keep .ev_nan (event counts), .events (2 x k: quarter
%        index, type 1 plm / 2 alm / 3 alm_shares / 4 shares_nan), .sig (event signature),
%        .n_solve, .t_setup, .t_loop, .phi0 .R0; with 'paths': .llt, .pinf, .fRE, .fBR, .n1
%        (discrete choice), .n1m (model share in force), .phi (2 x nT, end of t), .zRE, .zBR,
%        .FE_RE, .FE_BR, .a (filtered states), .e (filtered shocks); with 'check_iris': .g5

ip = inputParser;
ip.addParameter('paths', false);
ip.addParameter('check_iris', false);
ip.addParameter('start_state', []);
ip.parse(varargin{:});
st0 = ip.Results.start_state;
pth = ip.Results.paths;
wantPaths = ~isequal(pth, false);
wantFull = isequal(pth, true);      % 'light': no filtered states and shocks
chk = logical(ip.Results.check_iris);

tA = tic;
L = pb.learn;
th = theta(:);
gain = th(pb.ig);
om = th(pb.iom);
chi = th(pb.ichi);
out = struct('status', 'ok', 'ev_plm', 0, 'ev_alm', 0, 'ev_keep', 0, 'ev_nan', 0, 'events', zeros(2, 0), ...
    'sig', '', 'n_solve', 0, 't_setup', NaN, 't_loop', NaN, 'phi0', [], 'R0', []);
ll = -Inf;

% ---- set-up per theta ---------------------------------------------------------------------
P = hlest.theta_struct(pb, th);
[ok, ss] = hlest.solve_orig(pb, P);
if ~ok
    out.status = 'no unique stable RE solution';
    return
end
PA = P;
an = pb.anchor_names;
PA.(an{1}) = ss.k;
for j = 1:numel(pb.xb)
    PA.(an{1 + j}) = ss.c(j);
end
mLt = assign(pb.mL, PA);
[A0, B0, C0, D0] = system(mLt, 'MatrixFormat', 'plain', 'Normalize', false);
Rd = hlest.reduce_static(pb.sx, A0, B0, C0, D0);
if ~Rd.ok
    out.status = 'static elimination failed';
    return
end
Omg = ss.Omg;
QRE = ss.Rb*Omg*ss.Rb';
QRE = (QRE + QRE')/2;
SRE = struct('Tb', ss.Tb, 'Rb', ss.Rb, 'Kb', ss.Kb, 'Q', QRE);
[a, Pk, ok] = hlest.init_state(ss.Tb, ss.Kb, QRE);
if ~ok
    out.status = 'initial covariance';
    return
end
ipf = pb.ip;
if strcmp(L.init_beliefs, 'fixed')
    phi = L.phi0(:);
    Rr = L.R0;
else
    mu = a(ipf);
    v0 = Pk(ipf, ipf);
    c1 = ss.Tb(ipf, :)*Pk(:, ipf);
    Rr = [1, mu; mu, v0 + mu^2];
    phi = Rr \ [mu; c1 + mu^2];
end
out.phi0 = phi;
out.R0 = Rr;
n2_0 = L.init_n2;
zRE = 0;
if chi == 0
    zBR = 0;
else
    zBR = (log(n2_0) - log1p(-n2_0))/chi;
end
n1 = 1 - n2_0;
current = strcmp(L.info, 'current');
freeze = strcmp(L.gap, 'freeze');
kRE = ss.k;
cRE = ss.c';
Y = pb.Y;
Z = ss.Z;
Dm = ss.D;
OBS = pb.obs;
nT = pb.nT;
t0 = pb.t0;
nb = numel(pb.xb);
c2pi = log(2*pi);
nSolve = 0;
g5 = struct('n', 0, 'mismatch', 0, 'dT', 0, 'dR', 0, 'dK', 0, 'n_cmp', 0, 'n_unstable', 0);
if chk
    nfL = [];
end
out.t_setup = toc(tA);

% ---- records ---------------------------------------------------------------------------------
llt = zeros(1, nT);
ev = zeros(2, 0);
if wantPaths
    R_ = struct('pinf', NaN(1, nT), 'fRE', NaN(1, nT), 'fBR', NaN(1, nT), 'n1', NaN(1, nT), ...
        'n1m', NaN(1, nT), 'phi', NaN(2, nT), 'zRE', NaN(1, nT), 'zBR', NaN(1, nT), ...
        'FE_RE', NaN(1, nT), 'FE_BR', NaN(1, nT), 'Rdiag', NaN(2, nT));
    if wantFull
        R_.a = NaN(nb, nT);
        R_.e = zeros(size(Omg, 1), nT);
        R_.Pmax = NaN(1, nT);
        R_.v = NaN(size(Y, 1), nT);
        R_.Fd = NaN(size(Y, 1), nT);
    end
end

% ---- filter -------------------------------------------------------------------------------------
tB = tic;
S = SRE;
tStart = 1;
if ~isempty(st0)
    a = st0.a(:);
    Pk = st0.P;
    pinfPrev = a(ipf);
    tStart = t0;
end
n1mF = 1;               % model share in force in t
n1keep = [];            % model share kept by the facility for t+1
fRE = NaN;
fBR = NaN;
if isempty(st0)
    pinfPrev = NaN;
end
for t = tStart:nT
    if t == t0
        n1mF = mode_share(L, n1);
        [S, ok] = alm(n1mF, phi);
        if ~ok
            out.status = 'ALM unstable at the first check (initial beliefs and shares)';
            finish();
            return
        end
    end
    % Kalman step with the ALM in force in t
    a = S.Tb*a + S.Kb;
    Pk = S.Tb*Pk*S.Tb' + S.Q;
    obs = OBS(:, t);
    hasObs = any(obs);
    if hasObs
        Zt = Z(obs, :);
        v = Y(obs, t) - Zt*a - Dm(obs);
        PZ = Pk*Zt';
        Fm = Zt*PZ;
        Fm = (Fm + Fm')/2;
        if wantFull
            R_.v(obs, t) = v;
            R_.Fd(obs, t) = diag(Fm);
        end
        [Lc, p] = chol(Fm, 'lower');
        if p ~= 0
            out.status = sprintf('prediction-error covariance not PD at quarter %d', t);
            finish();
            return
        end
        w = Lc \ v;
        llt(t) = -0.5*(nnz(obs)*c2pi + 2*sum(log(diag(Lc))) + w'*w);
        Fiv = Lc' \ w;
        if wantFull
            R_.e(:, t) = Omg*S.Rb'*Zt'*Fiv;
        end
        a = a + PZ*Fiv;
        Pk = Pk - PZ*(Lc' \ (Lc \ PZ'));
        Pk = (Pk + Pk')/2;
    end
    pinf_t = a(ipf);
    if wantPaths
        R_.pinf(t) = pinf_t;
        if wantFull
            R_.a(:, t) = a;
            R_.Pmax(t) = max(abs(diag(Pk)));
        end
    end
    if t < t0
        pinfPrev = pinf_t;
        continue
    end
    if wantPaths
        R_.n1m(t) = n1mF;
    end
    first = t == t0;
    if freeze && ~hasObs && ~first
        % 'freeze': no RLS and no share update in a quarter without data; the forecasts
        % made in t are still formed, the model in force stays
        fRE = kRE + cRE*a;
        fBR = br_forecast(phi, pinf_t, pinfPrev, current);
        pinfPrev = pinf_t;
        if wantPaths
            rec_end(t, NaN, NaN);
        end
        continue
    end
    n1mLast = n1mF;
    % (1) errors, fitness, shares
    FEr = NaN;
    FEb = NaN;
    if ~first
        FEr = (pinf_t - fRE)^2;
        FEb = (pinf_t - fBR)^2;
        [n1c, zRc, zBc] = dchoice(FEr, FEb, zRE, zBR, chi, om);
        if isfinite(n1c)
            n1 = n1c;
            zRE = zRc;
            zBR = zBc;
        else
            ev(:, end+1) = [t; 4]; %#ok<AGROW>
        end
    end
    % (2) forecasts made in t (BR with phi_{t-1})
    fRE = kRE + cRE*a;
    fBR = br_forecast(phi, pinf_t, pinfPrev, current);
    % (3) RLS and the PLM block check
    phiPrev = phi;
    RPrev = Rr;
    z = [1; pinfPrev];
    if all(isfinite(z)) && isfinite(pinf_t)
        Rc = Rr + gain*(z*z' - Rr);
        phic = phi + gain*(Rc \ (z*(pinf_t - phi'*z)));
        if all(isfinite(phic)) && all(isfinite(Rc(:))) && abs(phic(2)) <= 1
            phi = phic;
            Rr = Rc;
        else
            ev(:, end+1) = [t; 1]; %#ok<AGROW>
        end
    end
    % (4) ALM check of the model in force in t+1
    n1keep = [];
    n1m = mode_share(L, n1);
    if n1m == 1
        S = SRE;
        n1mF = 1;
    else
        [S2, ok] = alm(n1m, phi);
        if ~ok
            if ~isequal(phi, phiPrev) || ~isequal(Rr, RPrev)
                phi = phiPrev;
                Rr = RPrev;
                [S2, ok] = alm(n1m, phi);
                if ok
                    ev(:, end+1) = [t; 2]; %#ok<AGROW>
                end
            end
            if ~ok && ~isequal(n1mLast, n1m)
                [S2, ok] = alm(n1mLast, phi);
                if ok
                    n1keep = n1mLast;
                    ev(:, end+1) = [t; 3]; %#ok<AGROW>
                end
            end
            if ~ok
                out.status = sprintf('ALM unstable at quarter %d with no fallback', t);
                finish();
                return
            end
        end
        S = S2;
        if isempty(n1keep)
            n1mF = n1m;
        else
            n1mF = n1keep;
        end
    end
    pinfPrev = pinf_t;
    if wantPaths
        rec_end(t, FEr, FEb);
    end
end
ll = sum(llt(pb.ilike:end));
if ~isfinite(ll)
    ll = -Inf;
    out.status = 'non-finite likelihood';
end
finish();

    % ------------------------------------------------------------------------------------------
    function [Sx, okx] = alm(n1x, phix)
        if n1x == 1
            Sx = SRE;
            okx = true;
            return
        end
        [Tb, Rb, Kb, flag] = hlest.qz_xb(Rd, n1x, phix(1), phix(2));
        nSolve = nSolve + 1;
        okx = flag == 1;
        Sx = [];
        if okx
            Qx = Rb*Omg*Rb';
            Sx = struct('Tb', Tb, 'Rb', Rb, 'Kb', Kb, 'Q', (Qx + Qx')/2);
        end
        if chk
            iris_compare(n1x, phix, okx, Tb, Rb, Kb);
        end
    end

    function iris_compare(n1x, phix, okx, Tb, Rb, Kb)
        Pb = struct(pb.bnames.n1, n1x, pb.bnames.n2, 1 - n1x, pb.bnames.alpha, phix(1), ...
            pb.bnames.beta, phix(2));
        mc = assign(mLt, Pb);
        [mc, fl] = solve(mc, 'Warning', false);
        okI = hasSucceeded(fl);
        g5.n = g5.n + 1;
        if okI ~= okx
            g5.mismatch = g5.mismatch + 1;
        end
        if ~okI
            g5.n_unstable = g5.n_unstable + 1;
        end
        if okI && okx
            [Ti, Ri, Ki] = sspace(mc, 'triangular', false);
            ne = size(Omg, 1);
            nfL = size(Ti, 1) - nb;
            Ti = Ti(nfL+1:end, :, 1);
            Ri = Ri(nfL+1:end, 1:ne, 1);
            Ki = Ki(nfL+1:end, 1, 1);
            g5.dT = max(g5.dT, max(abs(Tb(:) - Ti(:))));
            g5.dR = max(g5.dR, max(abs(Rb(:) - Ri(:))));
            g5.dK = max(g5.dK, max(abs(Kb(:) - Ki(:))));
            g5.n_cmp = g5.n_cmp + 1;
        end
    end

    function rec_end(t, FEr, FEb)
        R_.fRE(t) = fRE;
        R_.fBR(t) = fBR;
        R_.n1(t) = n1;
        R_.phi(:, t) = phi;
        R_.Rdiag(:, t) = diag(Rr);
        R_.zRE(t) = zRE;
        R_.zBR(t) = zBR;
        R_.FE_RE(t) = FEr;
        R_.FE_BR(t) = FEb;
    end

    function finish()
        out.events = ev;
        out.ev_plm = nnz(ev(2, :) == 1);
        out.ev_alm = nnz(ev(2, :) == 2);
        out.ev_keep = nnz(ev(2, :) == 3);
        out.ev_nan = nnz(ev(2, :) == 4);
        out.sig = sprintf('%d.%d;', ev);
        out.n_solve = nSolve;
        out.t_loop = toc(tB);
        out.llt = llt;
        if wantPaths
            f = fieldnames(R_);
            for q = 1:numel(f)
                out.(f{q}) = R_.(f{q});
            end
        end
        if chk
            out.g5 = g5;
        end
    end
end


function v = mode_share(L, n1)
% RE share in the model (hetlearn.engine.shares_for_mode without a kept share).
switch L.mode
    case 'rational'
        v = 1;
    case 'learning'
        v = 0;
    case 'fixed_shares'
        v = 1 - L.fixed_n2;
    case 'switching'
        v = n1;
    otherwise
        error('hlest:loglik_learn:mode', 'Unknown expectations mode %s.', L.mode);
end
end


function f = br_forecast(phi, pinf_t, pinfPrev, current)
if current
    f = phi(1) + phi(2)*pinf_t;
else
    f = phi(1) + phi(2)*(phi(1) + phi(2)*pinfPrev);
end
end


function [n1, zR, zB] = dchoice(FEr, FEb, zRp, zBp, chi, om)
% hetlearn.switching.discrete_choice for one share group (IJCB eqs. 14-15).
if om == 0
    mR = 0;
    mB = 0;
else
    mR = om*zRp;
    mB = om*zBp;
end
zR = -(1 - om)*FEr + mR;
zB = -(1 - om)*FEb + mB;
d = chi*(zR - zB);
if chi == 0 && ~isnan(zR - zB)
    d = 0;
end
if isnan(d) && isinf(zR) && isinf(zB)
    d = 0;
end
if isnan(d)
    n1 = NaN;
elseif d >= 0
    n1 = 1/(1 + exp(-d));
else
    ed = exp(d);
    n1 = ed/(1 + ed);
end
end
