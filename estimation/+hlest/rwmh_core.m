function [B, st] = rwmh_core(target, st, L, scale, n, rs, thin, keepPaths)
%RWMH_CORE  n random-walk Metropolis-Hastings steps from state st (in memory).
%
%   [B, st] = hlest.rwmh_core(target, st, L, scale, n, rs, thin, keepPaths)
%
%   target   handle [lp, ll, ex] = target(x): log posterior kernel, log likelihood and a struct
%            ex with .ev (1 x 3 facility event counts, or []) and .paths (struct, or [])
%   st       current state: .x (column), .lp, .ll, .ev, .paths, .n_done (draws so far)
%   L        lower Cholesky factor of the proposal covariance; scale  c in N(x, c^2 L L')
%   rs       RandStream (per chain; its state goes into the checkpoint)
%   thin     paths are kept for draws whose number (st.n_done + k) is a multiple of thin
%   B        .draws (n x d), .lp, .ll, .acc (n x 1), .ev (n x 3 int16), .first, .last (draw
%            numbers); with keepPaths .pidx (draw numbers) and .paths (cell of path structs)
%   Each step draws z ~ N(0, I) and u ~ U(0,1) whatever happens (reproducible stream).

d = numel(st.x);
B = struct('draws', zeros(n, d), 'lp', zeros(n, 1), 'll', zeros(n, 1), 'acc', false(n, 1), ...
    'ev', zeros(n, 3, 'int16'), 'first', st.n_done + 1, 'last', st.n_done + n, ...
    'pidx', zeros(0, 1), 'paths', {{}});
for k = 1:n
    xp = st.x + scale*(L*randn(rs, d, 1));
    u = rand(rs);
    [lpp, llp, ex] = target(xp);
    if isfinite(lpp) && log(u) < lpp - st.lp
        st.x = xp;
        st.lp = lpp;
        st.ll = llp;
        st.ev = ex.ev;
        st.paths = ex.paths;
        B.acc(k) = true;
    end
    B.draws(k, :) = st.x';
    B.lp(k) = st.lp;
    B.ll(k) = st.ll;
    if ~isempty(st.ev)
        B.ev(k, :) = int16(st.ev);
    end
    nd = st.n_done + k;
    if keepPaths && mod(nd, thin) == 0
        B.pidx(end+1, 1) = nd;
        B.paths{end+1, 1} = st.paths;
    end
end
st.n_done = st.n_done + n;
end
