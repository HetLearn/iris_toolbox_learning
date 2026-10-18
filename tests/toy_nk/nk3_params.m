function p = nk3_params()
%NK3_PARAMS  Parameter values for the toy hybrid NK model (quarterly).
%
%   p = nk3_params()   returns a struct incl. std_<shock>.

p = struct();
p.h = 0.5;          % output persistence
p.sig = 1.5;        % inverse IES
p.bet = 0.99;       % discount factor
p.iota = 0.5;       % price indexation
p.kap = 0.05;       % slope of the Phillips curve
p.c2 = 0.02;        % weight on the 2-step-ahead inflation expectation
p.rho_r = 0.8;      % interest-rate smoothing
p.phi_pi = 1.5;     % response to inflation
p.phi_y = 0.125;    % response to the output gap
p.phi_dy = 0.2;     % response to output growth
p.rho_g = 0.8;      % demand shock persistence
p.rho_u = 0.5;      % cost-push persistence
p.std_e_g = 1;
p.std_e_u = 0.5;
p.std_e_r = 0.25;
end
