function [objective] = objectiveconstr(Theta)

Theta(2) = exp(Theta(2))/(1+exp(Theta(2)));
Theta(8) = exp(Theta(8))/(1+exp(Theta(8)));
Theta(9) = exp(Theta(9))/(1+exp(Theta(9)));
Theta(10) = exp(Theta(10))/(1+exp(Theta(10)));


prio = prior(Theta);

    
liki = dsgeliki(Theta);
objective = -(liki+prio);


end

