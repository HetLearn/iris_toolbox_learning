function R = test_switching()
%TEST_SWITCHING  Discrete-choice switching (IJCB eqs. 14-15) and initial fitness.
%
%   R = test_switching()   returns a struct array of checks (name, pass, msg).

R = struct('name', {}, 'pass', {}, 'msg', {});

try
    n1 = hetlearn.switching.discrete_choice(0.3, 0.3, -0.2, -0.2, 8, 0.6);
    R = add(R, 'switch: equal fitness gives n1 = 0.5', abs(n1 - 0.5) < 1e-15, sprintf('n1 = %.16g', n1));
catch err
    R = add(R, 'switch: equal fitness gives n1 = 0.5', false, err.message);
end

try
    [n1, zr, zb] = hetlearn.switching.discrete_choice(0.5, 2.0, -0.1, -0.4, 3, 0.6);
    zr0 = -(1 - 0.6) * 0.5 + 0.6 * -0.1;
    zb0 = -(1 - 0.6) * 2.0 + 0.6 * -0.4;
    naive = exp(3 * zr0) / (exp(3 * zr0) + exp(3 * zb0));
    d = max(abs([n1 - naive, zr - zr0, zb - zb0]));
    R = add(R, 'switch: fitness recursion and share equal the IJCB formula', d < 1e-14, sprintf('diff %.1e', d));
catch err
    R = add(R, 'switch: fitness recursion and share equal the IJCB formula', false, err.message);
end

try
    FE_RE = [0.1 0.5 2 0]; FE_BR = [0.2 0.1 2 3]; zr = [0 -1 0.5 0]; zb = [0 0.3 -2 0];
    n1 = hetlearn.switching.discrete_choice(FE_RE, FE_BR, zr, zb, 1.7, 0.3);
    zr1 = -(0.7) * FE_RE + 0.3 * zr; zb1 = -(0.7) * FE_BR + 0.3 * zb;
    naive = exp(1.7 * zr1) ./ (exp(1.7 * zr1) + exp(1.7 * zb1));
    d = max(abs(n1 - naive));
    R = add(R, 'switch: vectorised over share groups', d < 1e-14 && isequal(size(n1), [1 4]), sprintf('diff %.1e', d));
catch err
    R = add(R, 'switch: vectorised over share groups', false, err.message);
end

try
    a = hetlearn.switching.discrete_choice(0, 1, 0, 0, 1e3, 0);    % RE much fitter
    b = hetlearn.switching.discrete_choice(1, 0, 0, 0, 1e3, 0);    % BR much fitter
    c = hetlearn.switching.discrete_choice(0, 5, 0, 0, 0, 0.6);    % chi = 0
    ok = abs(a - 1) < 1e-12 && abs(b) < 1e-12 && abs(c - 0.5) < 1e-15;
    R = add(R, 'switch: limits (n1 -> 1, n1 -> 0, chi = 0 -> 0.5)', ok, sprintf('%.3g %.3g %.3g', a, b, c));
catch err
    R = add(R, 'switch: limits (n1 -> 1, n1 -> 0, chi = 0 -> 0.5)', false, err.message);
end

try
    % chi*zeta ~ 1e4 in both directions and both fitness values hugely negative
    a = hetlearn.switching.discrete_choice(0, 1e4 / 8 / 0.4, 0, 0, 8, 0.6);
    b = hetlearn.switching.discrete_choice(1e4 / 8 / 0.4, 0, 0, 0, 8, 0.6);
    c = hetlearn.switching.discrete_choice(1e6, 1e6, -1e6, -1e6, 8, 0.6);
    ok = all(isfinite([a b c])) && a == 1 && b == 0 && abs(c - 0.5) < 1e-15;
    R = add(R, 'switch: no overflow for chi*zeta ~ 1e4 (and 1e7)', ok, sprintf('%.3g %.3g %.3g', a, b, c));
catch err
    R = add(R, 'switch: no overflow for chi*zeta ~ 1e4 (and 1e7)', false, err.message);
end

try
    chi = 8;
    n2s = [0.1 0.3 0.5 0.9];
    [zr, zb] = hetlearn.switching.init_fitness(n2s, chi);
    n2 = exp(chi * zb) ./ (exp(chi * zr) + exp(chi * zb));
    [zr0, zb0] = hetlearn.switching.init_fitness(0, chi);
    n1edge = hetlearn.switching.discrete_choice(0, 0, zr0, zb0, chi, 0.6);
    ok = all(zr == 0) && max(abs(n2 - n2s)) < 1e-14 && n1edge == 1;
    R = add(R, 'switch: init_fitness gives zetaRE0 = 0 and n2_0 = init_n2', ok, ...
        sprintf('max diff %.1e; init_n2 = 0 keeps n1 = %g', max(abs(n2 - n2s)), n1edge));
catch err
    R = add(R, 'switch: init_fitness gives zetaRE0 = 0 and n2_0 = init_n2', false, err.message);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
