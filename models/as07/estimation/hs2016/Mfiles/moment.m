function [y,y05,y95] = moment(IRF)

[nsim,H] = size(IRF);
y = (mean(IRF));
y05 = zeros(1,H);
y95 = zeros(1,H);
for i=1:H
 
  d= sort(IRF(:,i)); 
  y05(:,i) = d(round(0.05*nsim),:);
  y95(:,i) = d(round(.95*nsim),:);
end
end
