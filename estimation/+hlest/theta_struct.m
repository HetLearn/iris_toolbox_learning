function P = theta_struct(pb, theta)
%THETA_STRUCT  Original-model parameter struct at theta (the 36 SW07 entries; fixed ones at swX1).
%
%   P = hlest.theta_struct(pb, theta)

P = pb.Pbase;
tg = pb.tab.target;
for i = 1:pb.nstruct
    P.(tg{i}) = theta(i);
end
end
