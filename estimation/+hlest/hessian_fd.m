function varargout = hessian_fd(cmd, varargin)
%HESSIAN_FD  Central finite-difference Hessian with an event-pattern check, splittable over processes.
%
%   pts            = hlest.hessian_fd('points', d)
%   [h, info]      = hlest.hessian_fd('steps', f, x, h0, lb, ub)
%   [fv, same]     = hlest.hessian_fd('eval', f, x, h, pts, idx)
%   [H, info]      = hlest.hessian_fd('assemble', x, h, pts, fv, same)
%   [H, info]      = hlest.hessian_fd('full', f, x, h0, lb, ub)          % steps + eval + assemble
%
%   f      handle [value, sig] = f(x): value = minus the log posterior, sig = event signature
%          (text; the learning model's facility events; '' for the RE model)
%   pts    stencil, one row [i j si sj] per point: [0 0 0 0] centre, [i 0 +-1 0] diagonal,
%          [i j +-1 +-1] (i < j) cross points; 2 d^2 + 1 points in all
%   steps  h_i = h0_i, shrunk by 4 (up to 4 times) while x +- h_i e_i leaves the bounds or
%          changes the event signature (the facility makes the likelihood piecewise smooth)
%   H_ii = (f(+) - 2 f0 + f(-))/h_i^2,   H_ij = (f(++) - f(+-) - f(-+) + f(--))/(4 h_i h_j)
%   info   .n_diff_sig: stencil points whose event signature differs from the centre's;
%          .min_eig, .pd

switch cmd
    case 'points'
        d = varargin{1};
        P = zeros(2*d^2 + 1, 4);
        k = 1;
        for i = 1:d
            P(k+1, :) = [i 0 1 0];
            P(k+2, :) = [i 0 -1 0];
            k = k + 2;
        end
        for i = 1:d
            for j = i+1:d
                P(k+1:k+4, :) = [i j 1 1; i j 1 -1; i j -1 1; i j -1 -1];
                k = k + 4;
            end
        end
        varargout{1} = P;
    case 'steps'
        [varargout{1:2}] = steps(varargin{:});
    case 'eval'
        [varargout{1:2}] = eval_points(varargin{:});
    case 'assemble'
        [varargout{1:2}] = assemble(varargin{:});
    case 'full'
        [f, x, h0, lb, ub] = varargin{1:5};
        [h, si] = steps(f, x, h0, lb, ub);
        pts = hlest.hessian_fd('points', numel(x));
        [fv, same] = eval_points(f, x, h, pts, 1:size(pts, 1));
        [H, info] = assemble(x, h, pts, fv, same);
        info.steps = si;
        varargout = {H, info};
    otherwise
        error('hlest:hessian_fd:cmd', 'Unknown command %s.', cmd);
end
end


function [h, info] = steps(f, x, h0, lb, ub)
x = x(:);
h = h0(:);
[f0, s0] = f(x);
d = numel(x);
nShrink = zeros(d, 1);
for i = 1:d
    for k = 0:4
        ok = x(i) + h(i) < ub(i) && x(i) - h(i) > lb(i);
        if ok
            e = zeros(d, 1);
            e(i) = h(i);
            [~, sp] = f(x + e);
            [~, sm] = f(x - e);
            ok = strcmp(sp, s0) && strcmp(sm, s0);
        end
        if ok || k == 4
            break
        end
        h(i) = h(i)/4;
        nShrink(i) = nShrink(i) + 1;
    end
end
info = struct('f0', f0, 'sig0', s0, 'n_shrink', nShrink);
end


function [fv, same] = eval_points(f, x, h, pts, idx)
x = x(:);
[~, s0] = f(x);
fv = NaN(numel(idx), 1);
same = true(numel(idx), 1);
for q = 1:numel(idx)
    p = pts(idx(q), :);
    y = x;
    if p(1) > 0
        y(p(1)) = y(p(1)) + p(3)*h(p(1));
    end
    if p(2) > 0
        y(p(2)) = y(p(2)) + p(4)*h(p(2));
    end
    [fv(q), s] = f(y);
    same(q) = strcmp(s, s0);
end
end


function [H, info] = assemble(x, h, pts, fv, same)
d = numel(x);
f0 = fv(all(pts == 0, 2));
H = zeros(d);
fp = NaN(d, 1);
fm = NaN(d, 1);
for q = 1:size(pts, 1)
    p = pts(q, :);
    if p(1) > 0 && p(2) == 0
        if p(3) > 0
            fp(p(1)) = fv(q);
        else
            fm(p(1)) = fv(q);
        end
    end
end
for i = 1:d
    H(i, i) = (fp(i) - 2*f0 + fm(i))/h(i)^2;
end
C = zeros(d, d, 4);
for q = 1:size(pts, 1)
    p = pts(q, :);
    if p(2) > 0
        k = 1 + (p(3) < 0)*2 + (p(4) < 0);
        C(p(1), p(2), k) = fv(q);
    end
end
for i = 1:d
    for j = i+1:d
        H(i, j) = (C(i, j, 1) - C(i, j, 2) - C(i, j, 3) + C(i, j, 4))/(4*h(i)*h(j));
        H(j, i) = H(i, j);
    end
end
ev = eig((H + H')/2);
info = struct('n_diff_sig', nnz(~same), 'min_eig', min(ev), 'pd', all(ev > 0), 'f0', f0, ...
    'nonfinite', nnz(~isfinite(fv)));
end
