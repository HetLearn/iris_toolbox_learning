function C = read_blocks(cdir, withPaths, minAge)
%READ_BLOCKS  Read the completed block files of a chain folder without opening state.mat.
%
%   C = hlest.read_blocks(cdir)                     % draws, lp, ll, acc, ev of every complete block
%   C = hlest.read_blocks(cdir, true)               % also the thinned paths (learning chains)
%   C = hlest.read_blocks(cdir, withPaths, minAge)  % skip block files younger than minAge s (120)
%
%   Safe on a chain that is still running (est_06_post 'interim'): hlest.rwmh writes each
%   block_<k>.mat once, when its 1,000 draws are complete, and never touches it again. The
%   newest file may still be in the middle of being written, so files modified less than
%   minAge seconds ago are skipped; blocks are read in order from block 1 and reading stops
%   at the first missing number or the first file that fails to load. state.mat and
%   progress.txt are never opened (no file lock can get in the way of the chain's own
%   checkpoint).
%
%   C  .draws (n x d), .lp, .ll, .acc, .ev (n x 3), .n, .nblocks (blocks read), .first_draw
%      (1), .pidx (draw numbers of the stored paths) and .paths (cell of path structs) with
%      withPaths, .files_seen (block files present), .note (why reading stopped, '' if at the
%      newest file)

if nargin < 2 || isempty(withPaths)
    withPaths = false;
end
if nargin < 3 || isempty(minAge)
    minAge = 120;
end
C = struct('draws', [], 'lp', [], 'll', [], 'acc', [], 'ev', [], 'n', 0, 'nblocks', 0, ...
    'pidx', zeros(0, 1), 'paths', {{}}, 'files_seen', 0, 'note', '');
dd = dir(fullfile(cdir, 'block_*.mat'));
if isempty(dd)
    C.note = 'no block files';
    return
end
num = zeros(numel(dd), 1);
for k = 1:numel(dd)
    t = regexp(dd(k).name, '^block_(\d+)\.mat$', 'tokens', 'once');
    if isempty(t)
        num(k) = NaN;
    else
        num(k) = str2double(t{1});
    end
end
ok = isfinite(num);
dd = dd(ok);
num = num(ok);
[num, o] = sort(num);
dd = dd(o);
C.files_seen = numel(dd);
age = (now - [dd.datenum])*86400; %#ok<TNOW1>
D = cell(numel(dd), 1);
LP = D; LL = D; AC = D; EV = D; PI = D; PA = D;
nb = 0;
for k = 1:numel(dd)
    if num(k) ~= k
        C.note = sprintf('gap: block %d missing', k);
        break
    end
    if age(k) < minAge
        C.note = sprintf('block %d younger than %g s, skipped with the later ones', k, minAge);
        break
    end
    f = fullfile(dd(k).folder, dd(k).name);
    try
        if withPaths
            B = load(f, 'draws', 'lp', 'll', 'acc', 'ev', 'pidx', 'paths');
        else
            B = load(f, 'draws', 'lp', 'll', 'acc', 'ev');
        end
    catch err
        C.note = sprintf('block %d failed to load (%s), stopped there', k, err.message);
        break
    end
    if ~isfield(B, 'draws') || size(B.draws, 1) < 1
        C.note = sprintf('block %d incomplete, stopped there', k);
        break
    end
    nb = k;
    D{k} = B.draws;
    LP{k} = B.lp;
    LL{k} = B.ll;
    AC{k} = B.acc;
    EV{k} = double(B.ev);
    if withPaths
        PI{k} = B.pidx(:);
        PA{k} = B.paths(:);
    end
end
if nb == 0
    return
end
C.nblocks = nb;
C.draws = vertcat(D{1:nb});
C.lp = vertcat(LP{1:nb});
C.ll = vertcat(LL{1:nb});
C.acc = vertcat(AC{1:nb});
C.ev = vertcat(EV{1:nb});
C.n = size(C.draws, 1);
if withPaths
    C.pidx = vertcat(PI{1:nb});
    C.paths = vertcat(PA{1:nb});
end
end
