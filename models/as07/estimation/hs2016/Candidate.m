%==========================================================================
%                       DSGE MODEL ESTIMATION:  
%        Constructing the Candidate Density for MH Algorithm
%
%
%
% Author: Minsu Chang        minsuc@sas.upenn.edu
% Modified from Candidate.m by Luigi Bocola
%==========================================================================


clear
clc
close all
delete *.asv

tic

l = path;

path('Mfiles',path);
path('Optimization Routines',path);
path('LRE',path);
path('Matfiles',path);

disp('                                                                  ');
disp('    BAYESIAN ESTIMATION OF DSGE MODEL: THE CANDIDATE DENSITY      ');
disp('                                                                  ');


param = [2.09 0.6530 2.00 0.65 0.34 3.16 0.51 1.5 4 2.5 0.19 0.65 0.5]; % starting values

[fh,x,gh,H,itct,fcount,retcodeh] = csminwel('objectiveconstr',param',eye(13),[] ,10^(-5),200);

Theta=x';

Theta(2) = exp(Theta(2))/(1+exp(Theta(2)));
Theta(8) = exp(Theta(8))/(1+exp(Theta(8)));
Theta(9) = exp(Theta(9))/(1+exp(Theta(9)));
Theta(10) = exp(Theta(10))/(1+exp(Theta(10)));


%disp('   tau    kappa    psi1    psi2    rA    piA    gammaQ    rho_R    rho_g    rho_z    sigma_R    sigma_g    sigma_z   ');
%disp(num2str(Theta))
%disp('                                                                  ');                 
  

mode  = Theta; 
Sigma = nhess(@objectiveunconstr,mode');
Sigma = inv(Sigma);


save Matfiles/MH_candidate Sigma mode 

path(l);

disp(['         ELAPSED TIME:   ', num2str(toc)]);

elapsedtime=toc;



