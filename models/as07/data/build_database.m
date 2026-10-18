function [d, S] = build_database()
% BUILD_DATABASE  as07 observables as an IRIS databank, 1964Q1-2026Q2.
%
%   [d, S] = build_database()
%
% Reads  data/raw/canova_raw_fred_data.csv: FRED vintage 2026-09-29, a copy of
%        models/sw07/data/raw/canova_raw_fred_data.csv (same SHA-256). The file
%        is quarterly: gather_data.py has already averaged the monthly series
%        (CPIAUCSL, CNP16OV, FEDFUNDS) to quarters.
%        estimation/hs2016/us.txt: the book's estimation data, 1983Q1-2002Q4
%        (ygr, infl, int), for the definition check below.
% Writes data/as07_database.csv (databank.toCSV, '%.17g'), data/as07_database.mat
%        (struct d) and data/us_txt_match.csv (the definition check).
%
% Definitions: those of Herbst and Schorfheide (2016), confirmed against us.txt
% (data/README.md). Units are the book's: dy in % per quarter, pinfobs and
% robs in % a year.
%   dy       output growth, per capita: 100 x dlog GDPC1 minus 100 x dlog of the
%            HP trend (lambda 1600) of log CNP16OV, % q/q. The trend is fitted
%            over 1948Q1-2026Q2, the population data up to the last GDP quarter.
%            It removes the January population-control steps of CNP16OV, which
%            us.txt does not have (data/README.md: the raw-population variant
%            misses us.txt by 0.98 pp in 2000Q1).
%   dy_rawpop  helper, not an observable: 100 x dlog(GDPC1 / CNP16OV), the
%            raw-population definition of the SW07 package
%   pinfobs  CPI inflation, 400 x dlog CPIAUCSL (quarterly average), % a year
%   robs     federal funds rate, FEDFUNDS (quarterly average), % a year; NaN in
%            ELB quarters (FEDFUNDS below 0.25% a year)
%   ffr      FEDFUNDS in every quarter: robs before the ELB blanking
%   elb      1 in ELB quarters, 0 otherwise
% 1964Q1-1964Q4 is a presample; spec.filter_range starts in 1965Q1. The first
% growth rates use the raw file's 1963Q4 levels.
% Checks: dates consecutive; candidate definitions against us.txt
% (correlation, mean difference, max abs difference; the chosen ones must be
% the best match); the ELB quarters are exactly 2009Q1-2015Q4 and
% 2020Q2-2022Q1; CSV round trip to 1e-12 with the same NaN pattern.
% S returns the statistics quoted in README.md. Needs IRIS on the path.

here = fileparts(mfilename('fullpath'));
pkg = fileparts(here);
rawFile = fullfile(here, 'raw', 'canova_raw_fred_data.csv');
opts = detectImportOptions(rawFile, 'TextType', 'string', 'Delimiter', ',');
opts = setvartype(opts, 'date', 'string');   % keep ISO dates as text, not datetime
T = readtable(rawFile, opts);

% ---- dates -------------------------------------------------------------------------------
ds = string(T.date);
yr = double(extractBefore(ds, 5));
mo = double(extractBetween(ds, 6, 7));
assert(all(ismember(mo, [1 4 7 10])), 'Raw file is not quarter-start stamped');
qt = (mo - 1)/3 + 1;
assert(all(diff(yr*4 + qt) == 1), 'Raw dates are not consecutive quarters');
pos = @(y, q) find(yr == y & qt == q);
iFirst = pos(1964, 1);
iLast = pos(2026, 2);
assert(~isfinite(T.real_gdp(end)) || iLast == height(T), 'Raw file has GDP after 2026Q2');
startDate = qq(1964, 1);
endDate = qq(2026, 2);
nPer = iLast - iFirst + 1;

% ---- candidate definitions ------------------------------------------------------------------
dl = @(x) [NaN; diff(log(x))];
cand = struct();
iPop = find(isfinite(T.civ_pop), 1):iLast;
lpopHP = NaN(height(T), 1);
lpopHP(iPop) = hptrend(log(T.civ_pop(iPop)), 1600);
cand.ygr_percapita_hp = 100*[NaN; diff(log(T.real_gdp))] - 100*[NaN; diff(lpopHP)];   % chosen
cand.ygr_percapita_raw = 100*dl(T.real_gdp./T.civ_pop);
cand.ygr_total = 100*dl(T.real_gdp);
cand.infl_cpi = 400*dl(T.cpi);                         % chosen
cand.infl_gdpdef = 400*dl(T.gdp_deflator);
cand.infl_cpi_core = 400*dl(T.cpi_core);
cand.int_fedfunds = T.fedfunds;                        % chosen

% ---- match with the book's us.txt, 1983Q1-2002Q4 ---------------------------------------------
us = load(fullfile(pkg, 'estimation', 'hs2016', 'us.txt'));
bk = readmatrix(fullfile(pkg, 'estimation', 'hs2016', 'book_data', 'dsge1_data.csv'));
assert(isequal(size(bk), [80 3]) && max(abs(bk(:) - us(:))) < 1e-6, 'dsge1_data.csv differs from us.txt');
iu = pos(1983, 1):pos(2002, 4);
assert(numel(iu) == size(us, 1), 'us.txt does not have 80 quarters');
cn = fieldnames(cand);
col = [1 1 1 2 2 2 3];                                   % us.txt column of each candidate
M = table('Size', [numel(cn), 7], 'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'candidate', 'us_txt_column', 'corr', 'mean_diff', 'max_abs_diff', 'rms_diff', 'chosen'});
usName = {'ygr', 'infl', 'int'};
chosen = {'ygr_percapita_hp', 'infl_cpi', 'int_fedfunds'};
for i = 1:numel(cn)
    x = cand.(cn{i})(iu);
    b = us(:, col(i));
    e = x - b;
    r = corrcoef(x, b);
    M(i, :) = {string(cn{i}), string(usName{col(i)}), r(1, 2), mean(e), max(abs(e)), sqrt(mean(e.^2)), ...
        double(ismember(cn{i}, chosen))};
end
for k = 1:3
    rows = find(col == k);
    [~, best] = min(M.rms_diff(rows));
    assert(M.chosen(rows(best)) == 1, 'Chosen definition for %s is not the closest to us.txt', usName{k});
end
writetable(M, fullfile(here, 'us_txt_match.csv'));
S = struct();
S.match = M;
[~, k] = max(abs(cand.ygr_percapita_hp(iu) - us(:, 1)));
S.ygr_maxdiff_date = sprintf('%dQ%d', yr(iu(k)), qt(iu(k)));
[~, k] = max(abs(cand.infl_cpi(iu) - us(:, 2)));
S.infl_maxdiff_date = sprintf('%dQ%d', yr(iu(k)), qt(iu(k)));
S.sd_us = std(us, 0, 1);
S.mean_us = mean(us, 1);

% ---- federal funds rate; ELB quarters --------------------------------------------------------
ff = T.fedfunds(iFirst:iLast);
assert(all(isfinite(ff)), 'FEDFUNDS has gaps in the sample');
elb = ff < 0.25;
elbExpected = [pos(2009,1):pos(2015,4), pos(2020,2):pos(2022,1)] - iFirst + 1;
assert(isequal(find(elb)', elbExpected), 'ELB quarters differ from 2009Q1-2015Q4 and 2020Q2-2022Q1');
robs = ff;
robs(elb) = NaN;

% ---- databank ----------------------------------------------------------------------------
d = struct();
d.dy = Series(startDate, cand.ygr_percapita_hp(iFirst:iLast));
d.dy_rawpop = Series(startDate, cand.ygr_percapita_raw(iFirst:iLast));
d.pinfobs = Series(startDate, cand.infl_cpi(iFirst:iLast));
d.robs = Series(startDate, robs);
d.ffr = Series(startDate, ff);
d.elb = Series(startDate, double(elb));
names = fieldnames(d);
for i = 1:numel(names)
    x = getData(d.(names{i}), startDate:endDate);
    assert(numel(x) == nPer, '%s has the wrong length', names{i});
    if ~strcmp(names{i}, 'robs')
        assert(all(isfinite(x)), '%s has missing values', names{i});
    end
end
csvFile = fullfile(here, 'as07_database.csv');
matFile = fullfile(here, 'as07_database.mat');
databank.toCSV(d, csvFile, startDate:endDate, 'Format', '%.17g');
save(matFile, 'd');

d2 = databank.fromCSV(csvFile);
maxErr = 0;
for i = 1:numel(names)
    x = getData(d.(names{i}), startDate:endDate);
    x2 = getData(d2.(names{i}), startDate:endDate);
    assert(numel(x2) == nPer && isequal(isnan(x), isnan(x2)), '%s: round trip changes length or NaNs', names{i});
    okk = ~isnan(x);
    maxErr = max([maxErr; abs(x2(okk) - x(okk))]);
end
assert(maxErr < 1e-12, 'Round trip through CSV fails: %.3g', maxErr);

% ---- summary statistics (README.md) --------------------------------------------------------
g = @(name, rng) getData(d.(name), rng);
full = qq(1965,1):endDate;
S.n_elb = sum(elb);
S.mean_full = [mean(g('dy', full)), mean(g('pinfobs', full)), mean(g('robs', full), 'omitnan')];
S.mean_8302 = mean(us, 1);
win = qq(2020,1):qq(2024,4);
[S.peak_pinf, k] = max(g('pinfobs', win));
S.peak_date = dat2char(win(k));
popg = 100*dl(T.civ_pop);
pg = popg(iFirst:iLast);
[~, ord] = sort(abs(pg - median(pg)), 'descend');
S.pop_jumps = ord(1:6);
S.dy_2025Q1 = [g('dy', qq(2025,1)), g('dy_rawpop', qq(2025,1))];
S.popHP_growth_2023_2026 = mean(100*diff(lpopHP(pos(2022,4):iLast)));
S.pop_growth_2023_2026 = mean(popg(pos(2023,1):iLast));
S.dy_minus_rawpop_2022Q2 = g('dy', qq(2022,2)) - g('dy_rawpop', qq(2022,2));
dd = dat2str(startDate:endDate);

fprintf('build_database: %d quarters %s-%s, %d series, round-trip max abs error %.3g\n', ...
    nPer, dat2char(startDate), dat2char(endDate), numel(names), maxErr);
fprintf('Match with us.txt, 1983Q1-2002Q4 (constructed minus book):\n');
fprintf('  %-15s %-5s %8s %10s %10s %9s %6s\n', 'candidate', 'col', 'corr', 'mean diff', 'max |diff|', 'rms diff', 'chosen');
for i = 1:height(M)
    fprintf('  %-15s %-5s %8.4f %10.4f %10.4f %9.4f %6d\n', M.candidate(i), M.us_txt_column(i), M.corr(i), ...
        M.mean_diff(i), M.max_abs_diff(i), M.rms_diff(i), M.chosen(i));
end
fprintf('  largest gaps: ygr %s, infl %s\n', S.ygr_maxdiff_date, S.infl_maxdiff_date);
fprintf('us.txt means %.4f %.4f %.4f, std %.4f %.4f %.4f\n', S.mean_us, S.sd_us);
fprintf('Means 1965Q1-2026Q2: dy %.4f, pinfobs %.4f, robs %.4f (non-ELB)\n', S.mean_full);
fprintf('ELB quarters (FEDFUNDS < 0.25%% a year): %d, 2009Q1-2015Q4 and 2020Q2-2022Q1\n', S.n_elb);
fprintf('pinfobs peak 2020Q1-2024Q4: %s, %.4f %% a year (%.4f %% q/q)\n', S.peak_date, S.peak_pinf, S.peak_pinf/4);
fprintf('Largest CNP16OV growth outliers (100 dlog, median %.3f):', median(pg));
for k = S.pop_jumps(:)'
    fprintf(' %s %.3f (dy_rawpop %.2f, dy %.2f);', dd{k}, pg(k), g('dy_rawpop', startDate + k - 1), g('dy', startDate + k - 1));
end
fprintf('\n');
fprintf('2025Q1: dy %.3f, dy_rawpop %.3f. Mean pop growth 2023Q1-2026Q2: HP trend %.3f, raw %.3f. dy - dy_rawpop at 2022Q2: %.3f\n', ...
    S.dy_2025Q1, S.popHP_growth_2023_2026, S.pop_growth_2023_2026, S.dy_minus_rawpop_2022Q2);
end


function tr = hptrend(x, lambda)
% Hodrick-Prescott trend of the column x (two-sided, no missing values).
n = numel(x);
D = spdiags(repmat([1 -2 1], n - 2, 1), 0:2, n - 2, n);
tr = (speye(n) + lambda*(D'*D)) \ x(:);
end
