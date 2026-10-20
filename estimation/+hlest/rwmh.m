function st = rwmh(cdir, target, x0, Sigma, scale, ndraws, opts)
%RWMH  One resumable, extendable random-walk Metropolis-Hastings chain written to a folder.
%
%   st = hlest.rwmh(cdir, target, x0, Sigma, scale, ndraws, opts)
%
%   cdir     chain folder (created); target  handle [lp, ll, ex] = target(x) (hlest.rwmh_core)
%   x0       start (used only when the folder has no state.mat)
%   Sigma    proposal covariance; scale  c (proposal N(x, c^2 Sigma)); both are stored in
%            state.mat at the first call and reused on resume (opts.new_proposal = true
%            replaces them)
%   ndraws   total number of draws the chain should have; a later call with a larger number
%            appends draws (the chain continues from its saved state and random stream)
%   opts     .seed (RandStream mt19937ar seed), .block (draws per block file, 1000), .thin
%            (paths of every thin-th draw, 50), .keep_paths, .names (parameter names), .label,
%            .meta (struct stored in state.mat), .progress_every (draws, 200)
%
%   Files in cdir (format for post-processing, see estimation/README.md):
%     state.mat        x, lp, ll, ev, paths (current state), n_done, n_acc, rs_state, L, scale,
%                      Sigma, seed, block, thin, names, label, meta, nblocks, elapsed_s, created
%     block_00001.mat  ... one per completed block: draws (block x d), lp, ll, acc, ev
%                      (facility event counts plm/alm/alm_shares of the current state, learning
%                      model), first, last (draw numbers), pidx, paths (thinned path structs)
%     progress.txt     key = value lines: label, pid, draws_done, ndraws, acc_rate, acc_last,
%                      last_lp, s_per_draw, eta_s, elapsed_s, updated, status
%   A block is written before state.mat, so a crash loses at most the block in progress.

if ~isfield(opts, 'block'), opts.block = 1000; end
if ~isfield(opts, 'thin'), opts.thin = 50; end
if ~isfield(opts, 'keep_paths'), opts.keep_paths = false; end
if ~isfield(opts, 'names'), opts.names = {}; end
if ~isfield(opts, 'label'), opts.label = cdir; end
if ~isfield(opts, 'meta'), opts.meta = struct(); end
if ~isfield(opts, 'progress_every'), opts.progress_every = 200; end
if ~isfield(opts, 'new_proposal'), opts.new_proposal = false; end
if exist(cdir, 'dir') ~= 7
    mkdir(cdir);
end
sfile = fullfile(cdir, 'state.mat');
pid = feature('getpid');
if exist(sfile, 'file') == 2
    S = load(sfile);
    st = S.st;
    rs = RandStream('mt19937ar', 'Seed', st.seed);
    rs.State = st.rs_state;
    if opts.new_proposal
        st.Sigma = Sigma;
        st.L = chol((Sigma + Sigma')/2, 'lower');
        st.scale = scale;
    end
    fprintf('[rwmh] %s: resuming at draw %d (target %d)\n', opts.label, st.n_done, ndraws);
else
    rs = RandStream('mt19937ar', 'Seed', opts.seed);
    [lp0, ll0, ex0] = target(x0(:));
    if ~isfinite(lp0)
        error('hlest:rwmh:start', 'The start value has a non-finite log posterior.');
    end
    st = struct('x', x0(:), 'lp', lp0, 'll', ll0, 'ev', ex0.ev, 'paths', ex0.paths, 'n_done', 0, ...
        'n_acc', 0, 'rs_state', rs.State, 'L', chol((Sigma + Sigma')/2, 'lower'), 'scale', scale, ...
        'Sigma', Sigma, 'seed', opts.seed, 'block', opts.block, 'thin', opts.thin, ...
        'names', {opts.names}, 'label', opts.label, 'meta', opts.meta, 'nblocks', 0, 'elapsed_s', 0, ...
        'created', datestr(now, 'yyyy-mm-dd HH:MM:SS'), 'x0', x0(:), 'keep_paths', opts.keep_paths); %#ok<TNOW1,DATST>
    save_state(sfile, st);
    fprintf('[rwmh] %s: new chain, start lp %.4f, scale %.4g, target %d draws\n', opts.label, lp0, scale, ndraws);
end
tRun = tic;
el0 = st.elapsed_s;
nRun0 = st.n_done;
accLast = NaN;
write_progress(cdir, st, ndraws, pid, NaN, NaN, 'running');
while st.n_done < ndraws
    nb = min(st.block, ndraws - st.n_done);
    % run the block in chunks so that the progress file stays current
    Bk = [];
    left = nb;
    while left > 0
        m = min(opts.progress_every, left);
        [Bc, st] = hlest.rwmh_core(target, st, st.L, st.scale, m, rs, st.thin, st.keep_paths);
        Bk = cat_block(Bk, Bc);
        left = left - m;
        st.n_acc = st.n_acc + nnz(Bc.acc);
        accLast = mean(Bc.acc);
        sp = toc(tRun)/max(1, st.n_done - nRun0);
        st.elapsed_s = el0 + toc(tRun);
        write_progress(cdir, st, ndraws, pid, sp, accLast, 'running');
    end
    st.nblocks = st.nblocks + 1;
    blk = Bk; %#ok<NASGU>
    save(fullfile(cdir, sprintf('block_%05d.mat', st.nblocks)), '-struct', 'blk');
    st.rs_state = rs.State;
    st.elapsed_s = el0 + toc(tRun);
    save_state(sfile, st);
end
sp = toc(tRun)/max(1, st.n_done - nRun0);
write_progress(cdir, st, ndraws, pid, sp, accLast, 'done');
fprintf('[rwmh] %s: done, %d draws, acceptance %.3f\n', opts.label, st.n_done, st.n_acc/max(1, st.n_done));
end


function B = cat_block(B, C)
if isempty(B)
    B = C;
    return
end
B.draws = [B.draws; C.draws];
B.lp = [B.lp; C.lp];
B.ll = [B.ll; C.ll];
B.acc = [B.acc; C.acc];
B.ev = [B.ev; C.ev];
B.last = C.last;
B.pidx = [B.pidx; C.pidx];
B.paths = [B.paths; C.paths];
end


function save_state(sfile, st) %#ok<INUSD>
tmp = [sfile(1:end-4) '_tmp.mat'];
for k = 1:5
    try
        save(tmp, 'st');
        movefile(tmp, sfile, 'f');
        return
    catch err
        pause(2);
        if k == 5
            rethrow(err);
        end
    end
end
end


function write_progress(cdir, st, ndraws, pid, sp, accLast, status)
eta = sp*(ndraws - st.n_done);
txt = sprintf(['label = %s\npid = %d\ndraws_done = %d\nndraws = %d\nacc_rate = %.4f\nacc_last = %.4f\n' ...
    'last_lp = %.6f\ns_per_draw = %.4f\neta_s = %.0f\nelapsed_s = %.0f\nupdated = %s\nstatus = %s\n'], ...
    st.label, pid, st.n_done, ndraws, st.n_acc/max(1, st.n_done), accLast, st.lp, sp, eta, st.elapsed_s, ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), status); %#ok<TNOW1,DATST>
try
    fid = fopen(fullfile(cdir, 'progress.txt'), 'w');
    if fid > 0
        fwrite(fid, txt);
        fclose(fid);
    end
catch
end
end
