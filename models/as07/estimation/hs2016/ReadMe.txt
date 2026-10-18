<Readme file for DSGE Estimation>
- In this folder, you can find a set of MATLAB codes that generates posterior draws of small NK model 
using random walk Metropolis-Hastings (RWMH). 
- Last modified: 2/25/2016


There are 2 main files in the folder. 

1) Candidate.m                 : It computes the candidate density for Metropolis-Hastings algorithm, 
                                 The output (MH_candidate.mat) is saved in the folder ``Matfiles".

2) MetropolisHastings.m        : It runs the Metropolis-Hastings algorithm. It save the posterior draws 
                                 and logposterior density (mhdraws.mat) in the folder "Matfiles". The file 
                                 produces some diagnostic graph.
 

These files use a number of procedures collected in the folder "Mfiles". The most relevant files are


	a) model_solution.m  : Takes as inputs the vector of structural parameters. Returns the coefficient 
                               matrices of the log-linear approximate solution of the DSGE model. Please, 
                               refer to Sims () for details on the procedure.

	b) sysmat.m          : Takes as inputs the solution of the DSGE model and the vector of structural parameters.
                               Returns the matrices for the state space representation. 

	c) kalman.m          : Takes as inputs the state space matrices. Returns the likelihood function and the 
                               filtered states. 

	d) dsgeliki.m        : Takes as inputs the vector of structural parameters. Returns the value of the 
                               log-likelihood function.

	e) prior.m           : Takes as inputs the vector of structural parameters. Returns the value of the
                               log-prior. Modify this file in case you need to change the prior distribution.  
	


The folder contains two additional subfolders: "LRE" and "Optimization Routines". These two folders collect files
to solve the linear rational expectation model and to find the posterior mode. 

us.txt is the data file whose first column is output growth, second column is inflation, third column is federal fund rates. 
The observations used in the estimation range from 1983:I to 2002:IV, giving a total of 80 observations. 
See Appendix for detailed definition of the variables.

	