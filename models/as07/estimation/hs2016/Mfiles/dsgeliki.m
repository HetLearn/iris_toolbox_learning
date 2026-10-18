function [liki] = dsgeliki(para)

% This function computes the likelihood of the DSGE model.
% Input = para: Vector of Structural Parameters
%         constr: Indicator equal to 1 if parameters are constrained
% Output= Likelihood Function


[T1, TC, T0, TETA, RC, retcode] = model_solution(para);


if retcode==0
    
    data = load('us.txt');
 
    [A,B,H,R,Se,Phi] = sysmat(T1,T0,para);
    
    liki = kalman(A,B,H,R,Se,Phi,data);
    
    liki = sum(liki);
    
else
    
    liki=-1000000000000;
    
end
end



