function C = read_chain(cdir, withPaths)
%READ_CHAIN  Read the blocks of one chain folder written by hlest.rwmh.
%
%   C = hlest.read_chain(cdir)
%   C = hlest.read_chain(cdir, true)        % also the thinned paths
%
%   C  .draws (n x d), .lp, .ll, .acc, .ev (n x 3), .n, .state (state.mat contents, without the
%      proposal), .names, .pidx and .paths (withPaths). Only completed blocks are read.

if nargin < 2
    withPaths = false;
end
C = struct('draws', [], 'lp', [], 'll', [], 'acc', [], 'ev', [], 'n', 0, 'names', {{}}, ...
    'pidx', [], 'paths', {{}}, 'state', []);
sf = fullfile(cdir, 'state.mat');
if exist(sf, 'file') ~= 2
    return
end
S = load(sf);
C.state = S.st;
C.names = S.st.names;
nbk = S.st.nblocks;
D = cell(nbk, 1);
LP = cell(nbk, 1);
LL = cell(nbk, 1);
AC = cell(nbk, 1);
EV = cell(nbk, 1);
PI = cell(nbk, 1);
PA = cell(nbk, 1);
for k = 1:nbk
    f = fullfile(cdir, sprintf('block_%05d.mat', k));
    if withPaths
        B = load(f);
        PI{k} = B.pidx;
        PA{k} = B.paths;
    else
        B = load(f, 'draws', 'lp', 'll', 'acc', 'ev');
    end
    D{k} = B.draws;
    LP{k} = B.lp;
    LL{k} = B.ll;
    AC{k} = B.acc;
    EV{k} = B.ev;
end
C.draws = vertcat(D{:});
C.lp = vertcat(LP{:});
C.ll = vertcat(LL{:});
C.acc = vertcat(AC{:});
C.ev = vertcat(EV{:});
C.n = size(C.draws, 1);
if withPaths
    C.pidx = vertcat(PI{:});
    C.paths = vertcat(PA{:});
end
end
