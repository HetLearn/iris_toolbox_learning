// sw07_re_lagged_pinf.mod: Dynare 4.6.1 cross-check for tests/test_re_info.m (T2).
// The swX1 model (C:\dynare_work\sw_ext\swX1.mod, Pfeifer's version of the SW07
// usmodel.mod) with every E_t pinf(+1) replaced by EXPECTATION(-1)(pinf(+1)), the
// expectation formed with information up to t-1 (four terms: the value of capital,
// the consumption Euler equation, the price and the wage Phillips curves). Every
// other expectation stays E_t. Written by hand, independent of hetlearn and IRIS.
// Parameter values: the line @#include "sw07_params.inc" is filled from
// models/sw07/sw07_params.m by tests/models/dynare/run_dynare_check.m, which runs
// this file in C:\dynare_work\re_info_check\ (Dynare fails on OneDrive paths) and
// stores the IRFs in tests/reference/re_info_dynare_irfs.mat.

var labobs robs pinfobs dy dc dinve dw ewma epinfma zcapf rkf kf pkf cf
    invef yf labf wf rrf mc zcap rk k pk c inve y lab pinf w r a b g qs ms
    spinf sw kpf kp;

varexo ea eb eg eqs em epinf ew;

parameters curvw cgy curvp constelab constepinf constebeta cmaw cmap calfa
    czcap csadjcost ctou csigma chabb cfc
    cindw cprobw cindp cprobp csigl clandaw
    crpi crdy cry crr
    crhoa crhob crhog crhoqs crhoms crhopinf crhow
    ctrend cg;

@#include "sw07_params.inc"

model(linear);
#cpie=1+constepinf/100;
#cgamma=1+ctrend/100 ;
#cbeta=1/(1+constebeta/100);
#clandap=cfc;
#cbetabar=cbeta*cgamma^(-csigma);
#cr=cpie/(cbeta*cgamma^(-csigma));
#crk=(cbeta^(-1))*(cgamma^csigma) - (1-ctou);
#cw = (calfa^calfa*(1-calfa)^(1-calfa)/(clandap*crk^calfa))^(1/(1-calfa));
#cikbar=(1-(1-ctou)/cgamma);
#cik=(1-(1-ctou)/cgamma)*cgamma;
#clk=((1-calfa)/calfa)*(crk/cw);
#cky=cfc*(clk)^(calfa-1);
#ciy=cik*cky;
#ccy=1-cg-cik*cky;
#crkky=crk*cky;
#cwhlc=(1/clandaw)*(1-calfa)/calfa*crk*cky/ccy;
#cwly=1-crk*cky;
#conster=(cr-1)*100;

// flexible economy
      0*(1-calfa)*a + 1*a =  calfa*rkf+(1-calfa)*(wf)  ;
      zcapf =  (1/(czcap/(1-czcap)))* rkf  ;
      rkf =  (wf)+labf-kf ;
      kf =  kpf(-1)+zcapf ;
      invef = (1/(1+cbetabar*cgamma))* (  invef(-1) + cbetabar*cgamma*invef(1)+(1/(cgamma^2*csadjcost))*pkf ) +qs ;
      pkf = -rrf-0*b+(1/((1-chabb/cgamma)/(csigma*(1+chabb/cgamma))))*b +(crk/(crk+(1-ctou)))*rkf(1) +  ((1-ctou)/(crk+(1-ctou)))*pkf(1) ;
      cf = (chabb/cgamma)/(1+chabb/cgamma)*cf(-1) + (1/(1+chabb/cgamma))*cf(+1) +((csigma-1)*cwhlc/(csigma*(1+chabb/cgamma)))*(labf-labf(+1)) - (1-chabb/cgamma)/(csigma*(1+chabb/cgamma))*(rrf+0*b) + b ;
      yf = ccy*cf+ciy*invef+g  +  crkky*zcapf ;
      yf = cfc*( calfa*kf+(1-calfa)*labf +a );
      wf = csigl*labf 	+(1/(1-chabb/cgamma))*cf - (chabb/cgamma)/(1-chabb/cgamma)*cf(-1) ;
      kpf =  (1-cikbar)*kpf(-1)+(cikbar)*invef + (cikbar)*(cgamma^2*csadjcost)*qs ;

// sticky price - wage economy; E_t pinf(+1) -> EXPECTATION(-1)(pinf(+1)) in four terms
      mc =  calfa*rk+(1-calfa)*(w) - 1*a - 0*(1-calfa)*a ;
      zcap =  (1/(czcap/(1-czcap)))* rk ;
      rk =  w+lab-k ;
      k =  kp(-1)+zcap ;
      inve = (1/(1+cbetabar*cgamma))* (  inve(-1) + cbetabar*cgamma*inve(1)+(1/(cgamma^2*csadjcost))*pk ) +qs ;
      pk = -r+EXPECTATION(-1)(pinf(1))-0*b +(1/((1-chabb/cgamma)/(csigma*(1+chabb/cgamma))))*b + (crk/(crk+(1-ctou)))*rk(1) +  ((1-ctou)/(crk+(1-ctou)))*pk(1) ;
      c = (chabb/cgamma)/(1+chabb/cgamma)*c(-1) + (1/(1+chabb/cgamma))*c(+1) +((csigma-1)*cwhlc/(csigma*(1+chabb/cgamma)))*(lab-lab(+1)) - (1-chabb/cgamma)/(csigma*(1+chabb/cgamma))*(r-EXPECTATION(-1)(pinf(+1)) + 0*b) +b ;
      y = ccy*c+ciy*inve+g  +  1*crkky*zcap ;
      y = cfc*( calfa*k+(1-calfa)*lab +a );
      pinf =  (1/(1+cbetabar*cgamma*cindp)) * ( cbetabar*cgamma*EXPECTATION(-1)(pinf(1)) +cindp*pinf(-1)
           +((1-cprobp)*(1-cbetabar*cgamma*cprobp)/cprobp)/((cfc-1)*curvp+1)*(mc)  )  + spinf ;
      w =  (1/(1+cbetabar*cgamma))*w(-1)
           +(cbetabar*cgamma/(1+cbetabar*cgamma))*w(1)
           +(cindw/(1+cbetabar*cgamma))*pinf(-1)
           -(1+cbetabar*cgamma*cindw)/(1+cbetabar*cgamma)*pinf
           +(cbetabar*cgamma)/(1+cbetabar*cgamma)*EXPECTATION(-1)(pinf(1))
           +(1-cprobw)*(1-cbetabar*cgamma*cprobw)/((1+cbetabar*cgamma)*cprobw)*(1/((clandaw-1)*curvw+1))*
           (csigl*lab + (1/(1-chabb/cgamma))*c - ((chabb/cgamma)/(1-chabb/cgamma))*c(-1) -w)
           + 1*sw ;
      r =  crpi*(1-crr)*pinf
           +cry*(1-crr)*(y-yf)
           +crdy*(y-yf-y(-1)+yf(-1))
           +crr*r(-1)
           +ms  ;
      a = crhoa*a(-1)  + ea;
      b = crhob*b(-1) + eb;
      g = crhog*(g(-1)) + eg + cgy*ea;
      qs = crhoqs*qs(-1) + eqs;
      ms = crhoms*ms(-1) + em;
      spinf = crhopinf*spinf(-1) + epinfma - cmap*epinfma(-1);
      epinfma=epinf;
      sw = crhow*sw(-1) + ewma - cmaw*ewma(-1) ;
      ewma=ew;
      kp =  (1-cikbar)*kp(-1)+cikbar*inve + cikbar*cgamma^2*csadjcost*qs ;

// measurement equations
dy=y-y(-1)+ctrend;
dc=c-c(-1)+ctrend;
dinve=inve-inve(-1)+ctrend;
dw=w-w(-1)+ctrend;
pinfobs = 1*(pinf) + constepinf;
robs =    1*(r) + conster;
labobs = lab + constelab;
end;

steady_state_model;
dy=ctrend;
dc=ctrend;
dinve=ctrend;
dw=ctrend;
pinfobs = constepinf;
robs = (((1+constepinf/100)/((1/(1+constebeta/100))*(1+ctrend/100)^(-csigma)))-1)*100;
labobs = constelab;
end;

@#include "sw07_shocks.inc"

steady;
check;
stoch_simul(order=1, irf=40, nograph, noprint, irf_plot_threshold=0);
