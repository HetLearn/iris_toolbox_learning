function n1m = shares_for_mode(ctx, S)
%SHARES_FOR_MODE  RE shares n1_<x> to put in the model this period (DESIGN 4.6).
%
%   n1m = hetlearn.engine.shares_for_mode(ctx, S)
%
%   Inputs
%     ctx  engine context (.opts, .learnVars, .groupOf)
%     S    learning state at the start of period t (S.n1 = n1_{t-1} by group)
%
%   Output
%     n1m  struct by learning variable:
%            'rational'      1
%            'learning'      0
%            'fixed_shares'  1 - shares.fixed_n2 (scalar, or fixed_n2.<x>)
%            'switching'     n1_{t-1} of the variable's share group
%          The engine always sets n2_<x> = 1 - n1_<x>.
%          Exception (projection facility, DESIGN 4.4; user decision
%          2026-10-18): when the ALM check at the end of t-1 kept the
%          previous quarter's model shares, S.n1m_keep holds them and they
%          are returned instead, for this one quarter (update_learning clears
%          S.n1m_keep before the next check, which tries the mode shares
%          again). The discrete-choice shares S.n1 are not affected.

o = ctx.opts;
if isfield(S, 'n1m_keep') && isstruct(S.n1m_keep)
    n1m = S.n1m_keep;
    return
end
n1m = struct();
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    switch o.expectations.mode
        case 'rational'
            v = 1;
        case 'learning'
            v = 0;
        case 'fixed_shares'
            f2 = o.shares.fixed_n2;
            if isstruct(f2)
                if ~isfield(f2, x)
                    error('hetlearn:engine:fixedShares', ...
                        'shares.fixed_n2 is a struct but has no entry for learning variable %s.', x);
                end
                f2 = f2.(x);
            end
            v = 1 - f2;
        case 'switching'
            v = S.n1(ctx.groupOf.(x));
    end
    n1m.(x) = v;
end
end
