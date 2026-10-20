function F = forecast_learn(pb, theta, varargin)
%FORECAST_LEARN  Application 1 consistent with the likelihood: learning filter to the origin, then the forecast stage.
%
%   F = hlest.forecast_learn(pb, theta)
%   F = hlest.forecast_learn(pb, theta, 'origin', [2022 2], 'horizon', 16, 'check', true)
%   F = hlest.forecast_learn(pb, theta, 'origin_state', S0)    % forecast from a given origin state (gate G8)
%
%   pb     hlest.problem('learn', ...); theta  39 x 1 (36 SW07 parameters, gain, memory, chi)
%
%   History: the filter of hlest.loglik_learn (its code, line for line) on the data up to the
%   origin; nothing after the origin is used. Forecast, quarters origin+1 .. origin+horizon: the
%   same recursion without data. With no observation the Kalman step is the prediction
%   x_t = T_t x_{t-1} + K_t, i.e. the zero-shock simulation with the ALM in force in t (solved at
%   the end of t-1 with phi_{t-1} and the model shares in force), and the learning steps run on
%   the simulated values exactly as hetlearn.engine.forecast + update_learning do with zero
%   shocks and no conditions: (1) squared errors of the forecasts made in t-1, fitness, discrete-
%   choice shares; (2) forecasts made in t, f^RE = k + c' x_t (anchored RE) and f^BR from
%   phi_{t-1} ('lagged': alpha + beta (alpha + beta pinf_{t-1})); (3) constant-gain RLS on
%   z = [1; pinf_{t-1}] with the PLM block check (|beta| > 1: keep phi, R); (4) the ALM check of
%   the model in force in t+1 (unstable: revert every belief; still unstable: keep the model
%   shares in force in t; still unstable: status error). The covid treatment of pb.learn.gap
%   ('filter' or 'freeze') applies to the history only; the forecast always learns.
%
%   'check' (default true; ignored with 'origin_state'): hlest.loglik_learn on the full sample
%   (data to 2026Q2) at the same theta. Its recorded history up to the origin (filtered states,
%   pinf, beliefs, R diagonal, fitness, discrete-choice and model shares, forecasts, squared
%   errors, l_t, facility events) and the model share in force in origin+1 must equal this
%   function's: the filter is one-sided, so data after the origin cannot matter, and the copy of
%   the code cannot have drifted from the likelihood. F.check = largest absolute difference
%   (asserted below 1e-12; it is 0 when the two run the same arithmetic).
%
%   'origin_state' (struct, e.g. the engine's state at the end of the origin): fields a (xb at
%   the origin), phi (2 x 1), R (2 x 2), zRE, zBR, n1 (RE share, discrete choice), fRE, fBR (the
%   forecasts of pinf made at the origin, model units), n1m_keep ([] or the model share kept by
%   the facility for origin+1), prev_phi, prev_R (beliefs before the origin's update), n1m_last
%   (model share in force at the origin). The forecast then starts at origin+1 with the
%   engine's start-of-period solve (hetlearn.engine.facility 'solve'): the ALM of (phi, n1m),
%   n1m = n1m_keep or the discrete-choice share; if unstable, the beliefs prev_phi/prev_R; then
%   the shares n1m_last.
%
%   F  .ok, .status, .t_origin, .t_end (quarter index, t = 1 is 1965Q1), .q (labels 1..t_end),
%      .names (observables, pb.yl), .y (ny x t_end, model units: Z x_t + D with the filtered
%      state x_{t|t} up to the origin, the forecast after it), .yrep (report units: x
%      spec.report.scale, so inflation, the rate and the growth rates in % annualised),
%      .pinf, .n2 (1 - n1, learners' discrete-choice share at the end of t), .n2_model
%      (learners' share in the model in force in t), .alpha, .beta (beliefs at the end of t),
%      .fRE, .fBR (forecasts of pinf_{t+1} made in t, model units), .fRE_rep, .fBR_rep, .pmean
%      (4 (f + constepinf), 4 (alpha/(1-beta) + constepinf): annualised levels), .a (filtered
%      or simulated xb), .llt (l_t; 0 after the origin), .events (2 x k: quarter, type 1 plm /
%      2 alm revert / 3 kept shares / 4 shares NaN), .n_events_forecast, .origin_state (the
%      state at the end of the origin in the format above, plus .P and .n1m_next = the model
%      share in force in origin+1), .avg_pinf (average annualised inflation over the horizon),
%      .check, .ll_full (log likelihood of the full sample, from the check)

ip = inputParser;
ip.addParameter('origin', [2022 2]);
ip.addParameter('horizon', 16);
ip.addParameter('check', true);
ip.addParameter('origin_state', []);
ip.parse(varargin{:});
o = ip.Results;
S0 = o.origin_state;

L = pb.learn;
th = theta(:);
gain = th(pb.ig);
om = th(pb.iom);
chi = th(pb.ichi);
tO = find(abs(pb.dates - double(qq(o.origin(1), o.origin(2)))) < 1e-6, 1);
if isempty(tO) || tO < pb.t0
    error('hlest:forecast_learn:origin', 'The origin must lie in the filter range after the first learning quarter.');
end
H = o.horizon;
tEnd = tO + H;
F = struct('ok', false, 'status', 'ok', 't_origin', tO, 't_end', tEnd, 'horizon', H, 'q', {qlabels(tEnd)}, ...
    'names', {pb.yl}, 'check', NaN, 'll_full', NaN);
ev = zeros(2, 0);

% ---- set-up per theta (as hlest.loglik_learn) ----------------------------------------------------
P = hlest.theta_struct(pb, th);
[ok, ss] = hlest.solve_orig(pb, P);
if ~ok
    F.status = 'no unique stable RE solution';
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
    F.status = 'static elimination failed';
    return
end
Omg = ss.Omg;
QRE = ss.Rb*Omg*ss.Rb';
QRE = (QRE + QRE')/2;
SRE = struct('Tb', ss.Tb, 'Rb', ss.Rb, 'Kb', ss.Kb, 'Q', QRE);
[a, Pk, ok] = hlest.init_state(ss.Tb, ss.Kb, QRE);
if ~ok
    F.status = 'initial covariance';
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
% data up to the origin only; no data in the forecast quarters
ny = size(pb.Y, 1);
Y = NaN(ny, tEnd);
nC = min(pb.nT, tO);
Y(:, 1:nC) = pb.Y(:, 1:nC);
OBS = isfinite(Y);
Z = ss.Z;
Dm = ss.D;
t0 = pb.t0;
nb = numel(pb.xb);
c2pi = log(2*pi);

% ---- records --------------------------------------------------------------------------------
llt = zeros(1, tEnd);
R_ = struct('pinf', NaN(1, tEnd), 'fRE', NaN(1, tEnd), 'fBR', NaN(1, tEnd), 'n1', NaN(1, tEnd), ...
    'n1m', NaN(1, tEnd), 'phi', NaN(2, tEnd), 'zRE', NaN(1, tEnd), 'zBR', NaN(1, tEnd), ...
    'FE_RE', NaN(1, tEnd), 'FE_BR', NaN(1, tEnd), 'Rdiag', NaN(2, tEnd), 'a', NaN(nb, tEnd), ...
    'y', NaN(ny, tEnd));

% ---- filter, then forecast -------------------------------------------------------------------
S = SRE;
tStart = 1;
n1mF = 1;               % model share in force in t
n1keep = [];            % model share kept by the facility for t+1
fRE = NaN;
fBR = NaN;
pinfPrev = NaN;
n1mLast = NaN;
phiPrev = phi;
RPrev = Rr;
if ~isempty(S0)
    % forecast from a given state at the end of the origin
    a = S0.a(:);
    Pk = zeros(nb);
    phi = S0.phi(:);
    Rr = S0.R;
    zRE = S0.zRE;
    zBR = S0.zBR;
    n1 = S0.n1;
    fRE = S0.fRE;
    fBR = S0.fBR;
    pinfPrev = a(ipf);
    n1m = mode_share(L, n1);
    if isfield(S0, 'n1m_keep') && ~isempty(S0.n1m_keep)
        n1m = S0.n1m_keep;
    end
    [S, ok] = alm(n1m, phi);
    if ~ok && isfield(S0, 'prev_phi') && (~isequal(phi, S0.prev_phi(:)) || ~isequal(Rr, S0.prev_R))
        phi = S0.prev_phi(:);
        Rr = S0.prev_R;
        [S, ok] = alm(n1m, phi);
        if ok
            ev(:, end+1) = [tO + 1; 2];
        end
    end
    if ~ok && isfield(S0, 'n1m_last') && ~isequal(S0.n1m_last, n1m)
        n1m = S0.n1m_last;
        [S, ok] = alm(n1m, phi);
        if ok
            ev(:, end+1) = [tO + 1; 3];
        end
    end
    if ~ok
        F.status = 'ALM unstable at the start of the forecast with no fallback';
        finish();
        return
    end
    n1mF = n1m;
    tStart = tO + 1;
    F.origin_state = S0;
    F.origin_state.n1m_next = n1mF;
    R_.a(:, tO) = a;
    R_.y(:, tO) = Z*a + Dm;
    R_.pinf(tO) = a(ipf);
    R_.phi(:, tO) = phi;
    R_.n1(tO) = n1;
    R_.fRE(tO) = fRE;
    R_.fBR(tO) = fBR;
end
for t = tStart:tEnd
    if t == t0
        n1mF = mode_share(L, n1);
        [S, ok] = alm(n1mF, phi);
        if ~ok
            F.status = 'ALM unstable at the first check (initial beliefs and shares)';
            finish();
            return
        end
    end
    % Kalman step with the ALM in force in t (after the origin: the zero-shock simulation)
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
        [Lc, p] = chol(Fm, 'lower');
        if p ~= 0
            F.status = sprintf('prediction-error covariance not PD at quarter %d', t);
            finish();
            return
        end
        w = Lc \ v;
        llt(t) = -0.5*(nnz(obs)*c2pi + 2*sum(log(diag(Lc))) + w'*w);
        Fiv = Lc' \ w;
        a = a + PZ*Fiv;
        Pk = Pk - PZ*(Lc' \ (Lc \ PZ'));
        Pk = (Pk + Pk')/2;
    end
    pinf_t = a(ipf);
    R_.pinf(t) = pinf_t;
    R_.a(:, t) = a;
    R_.y(:, t) = Z*a + Dm;
    if t < t0
        pinfPrev = pinf_t;
        continue
    end
    R_.n1m(t) = n1mF;
    first = t == t0;
    if freeze && ~hasObs && ~first && t <= tO
        % 'freeze' (history only): no RLS and no share update in a quarter without data
        fRE = kRE + cRE*a;
        fBR = br_forecast(phi, pinf_t, pinfPrev, current);
        pinfPrev = pinf_t;
        rec_end(t, NaN, NaN);
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
                F.status = sprintf('ALM unstable at quarter %d with no fallback', t);
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
    rec_end(t, FEr, FEb);
    if t == tO
        F.origin_state = struct('a', a, 'P', Pk, 'phi', phi, 'R', Rr, 'zRE', zRE, 'zBR', zBR, 'n1', n1, ...
            'fRE', fRE, 'fBR', fBR, 'n1m_keep', n1keep, 'prev_phi', phiPrev, 'prev_R', RPrev, ...
            'n1m_last', n1mLast, 'n1m_next', n1mF);
    end
end
F.ok = true;
finish();

% ---- the history must be the likelihood's own (one-sided filter) -------------------------------
if o.check && isempty(S0)
    [llF, oF] = hlest.loglik_learn(pb, th, 'paths', true);
    F.ll_full = llF;
    k = 1:tO;
    kl = t0:tO;
    d = [mdiff(oF.a(:, k), F.a(:, k)), mdiff(oF.pinf(k), F.pinf(k)), mdiff(oF.phi(:, kl), F.alpha_beta(:, kl)), ...
        mdiff(oF.Rdiag(:, kl), R_.Rdiag(:, kl)), mdiff(oF.zRE(kl), R_.zRE(kl)), mdiff(oF.zBR(kl), R_.zBR(kl)), ...
        mdiff(oF.n1(kl), R_.n1(kl)), mdiff(oF.n1m(kl), R_.n1m(kl)), mdiff(oF.fRE(kl), R_.fRE(kl)), ...
        mdiff(oF.fBR(kl), R_.fBR(kl)), mdiff(oF.FE_RE(kl), R_.FE_RE(kl)), mdiff(oF.FE_BR(kl), R_.FE_BR(kl)), ...
        mdiff(oF.llt(k), llt(k))];
    if tO < pb.nT
        d(end+1) = mdiff(oF.n1m(tO + 1), F.origin_state.n1m_next);
    end
    evF = oF.events(:, oF.events(1, :) <= tO);
    evH = F.events(:, F.events(1, :) <= tO);
    if ~isequal(evF, evH)
        d(end+1) = Inf;
    end
    F.check = max(d);
    if ~(F.check < 1e-12)
        error('hlest:forecast_learn:check', ['The history up to the origin differs from hlest.loglik_learn on the ' ...
            'full sample by %.3g (the forecast must start from the likelihood''s own filtered state).'], F.check);
    end
end

    % ------------------------------------------------------------------------------------------
    function [Sx, okx] = alm(n1x, phix)
        if n1x == 1
            Sx = SRE;
            okx = true;
            return
        end
        [Tb, Rb, Kb, flag] = hlest.qz_xb(Rd, n1x, phix(1), phix(2));
        okx = flag == 1;
        Sx = [];
        if okx
            Qx = Rb*Omg*Rb';
            Sx = struct('Tb', Tb, 'Rb', Rb, 'Kb', Kb, 'Q', (Qx + Qx')/2);
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
        sc = pb.spec.report.scale;
        cm = th(strcmp(pb.tab.name, 'constepinf'));
        F.events = ev;
        F.n_events_forecast = nnz(ev(1, :) > tO);
        F.llt = llt;
        F.a = R_.a;
        F.y = R_.y;
        F.yrep = R_.y;
        for i = 1:ny
            F.yrep(i, :) = R_.y(i, :)*sc.(pb.yl{i});
        end
        F.pinf = R_.pinf;
        F.n2 = 1 - R_.n1;
        F.n2_model = 1 - R_.n1m;
        F.alpha = R_.phi(1, :);
        F.beta = R_.phi(2, :);
        F.alpha_beta = R_.phi;
        F.fRE = R_.fRE;
        F.fBR = R_.fBR;
        F.fRE_rep = 4*(R_.fRE + cm);
        F.fBR_rep = 4*(R_.fBR + cm);
        F.pmean = 4*(R_.phi(1, :)./(1 - R_.phi(2, :)) + cm);
        F.FE_RE = R_.FE_RE;
        F.FE_BR = R_.FE_BR;
        ipo = strcmp(pb.yl, 'pinfobs');
        F.avg_pinf = mean(F.yrep(ipo, tO+1:tEnd));
        if ~isfield(F, 'origin_state')
            F.origin_state = [];
        end
    end
end


function d = mdiff(A, B)
% Largest absolute difference; Inf if the NaN patterns differ.
A = double(A(:));
B = double(B(:));
if numel(A) ~= numel(B) || ~isequal(isnan(A), isnan(B))
    d = Inf;
    return
end
k = ~isnan(A);
d = max([0; abs(A(k) - B(k))]);
end


function Q = qlabels(n)
Q = cell(1, n);
for t = 1:n
    Q{t} = sprintf('%dQ%d', 1965 + floor((t - 1)/4), mod(t - 1, 4) + 1);
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
        error('hlest:forecast_learn:mode', 'Unknown expectations mode %s.', L.mode);
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
