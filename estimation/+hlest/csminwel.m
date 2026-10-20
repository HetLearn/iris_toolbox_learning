function [fh, xh, gh, H, itct, fcount, retcodeh] = csminwel(fcn, x0, H0, crit, nit, opts)
%CSMINWEL  Sims' quasi-Newton minimiser with BFGS updates and cliff handling (port, numerical gradient).
%
%   [fh, xh, gh, H, itct, fcount, retcode] = hlest.csminwel(fcn, x0, H0, crit, nit, opts)
%
%   fcn   handle f = fcn(x), x a column; minimised (pass minus the log posterior)
%   x0    start; H0 initial inverse Hessian; crit convergence criterion on the improvement of f;
%   nit   maximum number of iterations
%   opts  .delta (forward-difference step, default 1e-6), .log (function handle of one text
%         argument for progress lines, default fprintf), .checkpoint (function handle called
%         as checkpoint(x, f, itct) after every iteration, default none), .max_time (seconds;
%         stop after the iteration that exceeds it, default Inf)
%
%   Port of csminwel.m, csminit.m, bfgsi.m and numgrad.m by Christopher Sims (1996-2003,
%   as distributed with Dynare 4.6.1), without the analytic-gradient branch.

if nargin < 6
    opts = struct();
end
if ~isfield(opts, 'delta')
    opts.delta = 1e-6;
end
if ~isfield(opts, 'log')
    opts.log = @(s) fprintf('%s\n', s);
end
if ~isfield(opts, 'checkpoint')
    opts.checkpoint = [];
end
if ~isfield(opts, 'max_time')
    opts.max_time = Inf;
end
tStart = tic;
x0 = x0(:);
nx = numel(x0);
done = 0;
itct = 0;
fcount = 0;
f0 = fcn(x0);
fcount = fcount + 1;
if f0 > 1e50
    error('hlest:csminwel:start', 'Bad initial parameter (f = %g).', f0);
end
[g, badg, fc] = numgrad(fcn, x0, f0, opts.delta);
fcount = fcount + fc;
retcode3 = 101;
x = x0;
f = f0;
H = H0;
gh = g;
retcodeh = NaN;
while ~done
    g1 = []; g2 = []; g3 = [];
    itct = itct + 1;
    [f1, x1, fc, retcode1] = csminit(fcn, x, f, g, badg, H, opts.log);
    fcount = fcount + fc;
    if retcode1 ~= 1
        if retcode1 == 2 || retcode1 == 4
            wall1 = 1;
            badg1 = 1;
        else
            [g1, badg1, fc] = numgrad(fcn, x1, f1, opts.delta);
            fcount = fcount + fc;
            wall1 = badg1;
        end
        if wall1 && (numel(H) > 1)
            Hcliff = H + diag(diag(H).*rand(nx, 1));
            opts.log('Cliff.  Perturbing search direction.');
            [f2, x2, fc, retcode2] = csminit(fcn, x, f, g, badg, Hcliff, opts.log);
            fcount = fcount + fc;
            if f2 < f
                if retcode2 == 2 || retcode2 == 4
                    wall2 = 1;
                    badg2 = 1;
                else
                    [g2, badg2, fc] = numgrad(fcn, x2, f2, opts.delta);
                    fcount = fcount + fc;
                    wall2 = badg2;
                end
                if wall2
                    opts.log('Cliff again.  Try traversing');
                    if norm(x2 - x1) < 1e-13
                        f3 = f; x3 = x; badg3 = 1; retcode3 = 101;
                    else
                        gcliff = ((f2 - f1)/((norm(x2 - x1))^2))*(x2 - x1);
                        [f3, x3, fc, retcode3] = csminit(fcn, x, f, gcliff, 0, eye(nx), opts.log);
                        fcount = fcount + fc;
                        if retcode3 == 2 || retcode3 == 4
                            badg3 = 1;
                        else
                            [g3, badg3, fc] = numgrad(fcn, x3, f3, opts.delta);
                            fcount = fcount + fc;
                        end
                    end
                else
                    f3 = f; x3 = x; badg3 = 1; retcode3 = 101;
                end
            else
                f3 = f; x3 = x; badg3 = 1; retcode3 = 101;
            end
        else
            f2 = f; f3 = f; badg2 = 1; badg3 = 1; retcode2 = 101; retcode3 = 101;
            x2 = x; x3 = x;
        end
    else
        f2 = f; f3 = f; f1 = f; retcode2 = retcode1; retcode3 = retcode1;
        x2 = x; x3 = x; x1 = x;
        badg1 = 1; badg2 = 1; badg3 = 1;
    end
    % pick the best of the three
    if f3 < f - crit && badg3 == 0
        fh = f3; xh = x3; gh = g3; badgh = badg3; retcodeh = retcode3;
    elseif f2 < f - crit && badg2 == 0
        fh = f2; xh = x2; gh = g2; badgh = badg2; retcodeh = retcode2;
    elseif f1 < f - crit && badg1 == 0
        fh = f1; xh = x1; gh = g1; badgh = badg1; retcodeh = retcode1;
    else
        [fh, ih] = min([f1, f2, f3]);
        switch ih
            case 1
                xh = x1;
            case 2
                xh = x2;
            case 3
                xh = x3;
        end
        rci = [retcode1, retcode2, retcode3];
        retcodeh = rci(ih);
        [gh, badgh, fc] = numgrad(fcn, xh, fh, opts.delta);
        fcount = fcount + fc;
        badgh = 1;
    end
    stuck = (abs(fh - f) < crit);
    if (~badg) && (~badgh) && (~stuck)
        H = bfgsi(H, gh - g, xh - x, opts.log);
    end
    opts.log(sprintf('iteration %d: f %.10f (improvement %.3g), evaluations %d, retcode %d', ...
        itct, fh, f - fh, fcount, retcodeh));
    if ~isempty(opts.checkpoint)
        opts.checkpoint(xh, fh, itct);
    end
    if itct > nit
        opts.log('iteration count termination');
        done = 1;
    elseif toc(tStart) > opts.max_time
        opts.log('time limit termination');
        done = 1;
    elseif stuck
        opts.log('improvement < crit termination');
        done = 1;
    end
    f = fh;
    x = xh;
    g = gh;
    badg = badgh;
end
end


% =========================================================================
function [fhat, xhat, fcount, retcode] = csminit(fcn, x0, f0, g0, badg, H0, logf)
ANGLE = .005;
THETA = .3;
FCHANGE = 1000;
MINLAMB = 1e-9;
MINDFAC = .01;
fcount = 0;
lambda = 1;
xhat = x0;
fhat = f0;
g = g0;
gnorm = norm(g);
retcode = 0;
if (gnorm < 1.e-12) && ~badg
    retcode = 1;
else
    dx = -H0*g;
    dxnorm = norm(dx);
    if dxnorm > 1e12
        logf('Near-singular H problem.');
        dx = dx*FCHANGE/dxnorm;
    end
    dfhat = dx'*g0;
    if ~badg
        a = -dfhat/(gnorm*dxnorm);
        if a < ANGLE
            dx = dx - (ANGLE*dxnorm/gnorm + dfhat/(gnorm*gnorm))*g;
            dx = dx*dxnorm/norm(dx);
            dfhat = dx'*g;
        end
    end
    done = 0;
    factor = 3;
    shrink = 1;
    lambdaMax = inf;
    lambdaPeak = 0;
    fPeak = f0;
    while ~done
        dxtest = x0 + dx*lambda;
        f = fcn(dxtest);
        if f < fhat
            fhat = f;
            xhat = dxtest;
        end
        fcount = fcount + 1;
        shrinkSignal = (~badg && (f0 - f < max([-THETA*dfhat*lambda 0]))) || (badg && (f0 - f) < 0);
        growSignal = ~badg && ((lambda > 0) && (f0 - f > -(1 - THETA)*dfhat*lambda));
        if shrinkSignal && ((lambda > lambdaPeak) || (lambda < 0))
            if (lambda > 0) && ((~shrink) || (lambda/factor <= lambdaPeak))
                shrink = 1;
                factor = factor^.6;
                while lambda/factor <= lambdaPeak
                    factor = factor^.6;
                end
                if abs(factor - 1) < MINDFAC
                    if abs(lambda) < 4
                        retcode = 2;
                    else
                        retcode = 7;
                    end
                    done = 1;
                end
            end
            if (lambda < lambdaMax) && (lambda > lambdaPeak)
                lambdaMax = lambda;
            end
            lambda = lambda/factor;
            if abs(lambda) < MINLAMB
                if (lambda > 0) && (f0 <= fhat)
                    lambda = -lambda*factor^6;
                else
                    if lambda < 0
                        retcode = 6;
                    else
                        retcode = 3;
                    end
                    done = 1;
                end
            end
        elseif (growSignal && lambda > 0) || (shrinkSignal && ((lambda <= lambdaPeak) && (lambda > 0)))
            if shrink
                shrink = 0;
                factor = factor^.6;
                if abs(factor - 1) < MINDFAC
                    if abs(lambda) < 4
                        retcode = 4;
                    else
                        retcode = 7;
                    end
                    done = 1;
                end
            end
            if (f < fPeak) && (lambda > 0)
                fPeak = f;
                lambdaPeak = lambda;
                if lambdaMax <= lambdaPeak
                    lambdaMax = lambdaPeak*factor*factor;
                end
            end
            lambda = lambda*factor;
            if abs(lambda) > 1e20
                retcode = 5;
                done = 1;
            end
        else
            done = 1;
            if factor < 1.2
                retcode = 7;
            else
                retcode = 0;
            end
        end
    end
end
end


function H = bfgsi(H0, dg, dx, logf)
Hdg = H0*dg;
dgdx = dg'*dx;
if abs(dgdx) > 1e-12
    H = H0 + (1 + (dg'*Hdg)/dgdx)*(dx*dx')/dgdx - (dx*Hdg' + Hdg*dx')/dgdx;
else
    logf('bfgs update failed.');
    H = H0;
end
end


function [g, badg, fcount] = numgrad(fcn, x, f0, delta)
n = numel(x);
g = zeros(n, 1);
badg = 0;
for i = 1:n
    xi = x;
    xi(i) = xi(i) + delta;
    g0 = (fcn(xi) - f0)/delta;
    if abs(g0) < 1e15
        g(i) = g0;
    else
        g(i) = 0;
        badg = 1;
    end
end
fcount = n;
end
