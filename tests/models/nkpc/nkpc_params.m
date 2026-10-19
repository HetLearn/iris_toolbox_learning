function p = nkpc_params()
%NKPC_PARAMS  Parameters of the closed-form test Phillips curve (tests/test_re_info.m, T3).
p = struct();
p.bet = 0.99;
p.kap = 0.1;
p.rho_x = 0.7;
p.rho_u = 0.5;
p.std_e_x = 1;
p.std_e_u = 0.5;
end
