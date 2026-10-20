function cfg = tsw07_girf2019(base, shock, value)
%TSW07_GIRF2019  Test scenario: one 2019Q4 conditional IRF run of docs/DESIGN_br_extensions.md sec. 4 on the baseline.
%
%   cfg = tsw07_girf2019(base)                 run without a shock (the reference path of the GIRF)
%   cfg = tsw07_girf2019(base, shock, value)   value added to the shock in 2020Q1
%
%   base   'learn' (tsw07_a1_learn, the 2026-10-20 baseline) | 're' (tsw07_a1_re, the RE(t-1)
%          benchmark br00_re)
%   shock  SW07 shock name ('ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'); '' = none
%   value  size of the shock (make_br_freeze passes one sd, std_<shock> of the published mode)
%
%   Origin 2019Q4, horizon 20 (2020Q1-2024Q4), zero future shocks otherwise; the history stage of
%   the baseline (RE smoother with filtered RE states) runs to the origin, and beliefs, gains and
%   shares keep updating over the horizon. GIRF = the run with the shock minus the run without.

if nargin < 2
    shock = '';
end
switch base
    case 'learn'
        cfg = tsw07_a1_learn();
    case 're'
        cfg = tsw07_a1_re();
    otherwise
        error('tsw07_girf2019:base', 'base must be ''learn'' or ''re''.');
end
tag = shock;
if isempty(shock)
    tag = 'none';
end
cfg.id = sprintf('tsw07_girf2019_%s_%s', base, tag);
cfg.title = sprintf('Test: 2019Q4 GIRF run (%s), shock %s', base, tag);
cfg.forecast.origin = qq(2019, 4);
cfg.forecast.horizon = 20;
cfg.compare_with = {};
if ~isempty(shock)
    cfg.shocks.add = {{shock, qq(2020, 1), value}};
end
end
