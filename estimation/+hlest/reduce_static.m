function Rd = reduce_static(sx, A, B, C, D)
%REDUCE_STATIC  Eliminate the belief-free static variables of the extended system (once per theta).
%
%   Rd = hlest.reduce_static(sx, A, B, C, D)
%
%   IRIS system form (system(m, 'MatrixFormat', 'plain', 'Normalize', false)):
%       A x_t + B x_{t-1} + C + D e_t = 0,   x = [xf; xb],
%   with the xf block dated one period ahead of xb. A static variable has a zero column in A
%   (it appears at one date only). Let S be the static columns other than pinf_exp1,
%   pinf_exp1_RE and pinf_exp1_BR (they do not depend on beliefs or shares) and O the rows
%   other than the two belief/share rows (pinf_exp1 = n1 RE + n2 BR, and the BR forecast
%   equation, which involve none of S). With B(O,S) = Q [R1; 0], the rows Q2' (O rows), Q2
%   = Q(:, ns+1:end), contain no static variable; the reduced system is those rows plus the
%   two belief/share rows, restricted to the columns N (all but S). Its solution for the
%   predetermined states equals that of the full system (the static rows only determine
%   the static variables). The three pinf statics are eliminated per quarter in hlest.qz_xb.
%
%   Rd  sx plus .A .B .C .D (reduced), .rE .rB (rows of the two belief/share equations),
%       .ok (false if the static pattern differs from the one at the calibration or B(O,S)
%       is rank deficient)

Rd = sx;
Rd.ok = false;
if any(any(A(:, sx.S)))
    return
end
[Q, R1] = qr(B(sx.O, sx.S));
dg = abs(diag(R1));
if isempty(dg) || min(dg) <= 1e-10*max(dg)
    return
end
ns = numel(sx.S);
Q2 = Q(:, ns+1:end)';
Rd.A = [Q2*A(sx.O, sx.N); A(sx.rows2, sx.N)];
Rd.B = [Q2*B(sx.O, sx.N); B(sx.rows2, sx.N)];
Rd.C = [Q2*C(sx.O); C(sx.rows2)];
Rd.D = [Q2*D(sx.O, :); D(sx.rows2, :)];
Rd.rE = size(Q2, 1) + 1;
Rd.rB = Rd.rE + 1;
Rd.ok = all(isfinite(Rd.A(:))) && all(isfinite(Rd.B(:)));
end
