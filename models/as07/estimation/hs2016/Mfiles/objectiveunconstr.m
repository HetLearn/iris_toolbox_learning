function [objective] = objectiveunconstr(Theta)
    
prio = prior(Theta);

if prio==-Inf
    objective = -1000000000000000;
else

liki = dsgeliki(Theta);

objective = -(liki+prio);

end

