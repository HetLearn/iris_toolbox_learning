function [d, S] = build_database()
% BUILD_DATABASE  ijcb3 observables as an IRIS databank, 1957Q1-2026Q2.
%
%   [d, S] = build_database()
%
% Reads  data/raw/canova_raw_fred_data.csv: FRED vintage 2026-09-29, a copy of
%        models/sw07/data/raw/canova_raw_fred_data.csv (same SHA-256). The file
%        is quarterly: gather_data.py has already averaged the monthly series
%        (CPIAUCSL, FEDFUNDS) to quarters.
% Writes data/ijcb3_database.csv (databank.toCSV, '%.17g') and
%        data/ijcb3_database.mat (struct d).
%
% Series, 1957Q1-2026Q2 (1957Q1-1959Q4 is IJCB's burn-in; filter_range starts
% in 1960Q1):
%   yobs     output gap: Hamilton (2018) regression filter on y = 100 x log
%            GDPC1, h = 8, p = 4, with the coefficients of IJCB's own sample:
%            OLS of y(t+8) on a constant and y(t), ..., y(t-3) over the gap
%            dates 1957Q1-2019Q4 (no covid quarters). The gap at every date is
%            y(t+8) minus the fitted value from those coefficients, with z in
%            place of y in the regressors; z equals y except in 2020Q1-2020Q3,
%            where it is a straight line between the 2019Q4 and 2020Q4 values.
%            Through 2019Q4 the gap is the regression's own residual (IJCB's
%            construction on this vintage); from 2020Q1 it is out of sample.
%            Percent of trend output (README.md).
%   pinfobs  CPI inflation, 100 x dlog CPIAUCSL (quarterly average), % q/q,
%            not annualised (IJCB's units, README.md "Units").
%   robs     federal funds rate, FEDFUNDS (quarterly average) / 4, % per
%            quarter; NaN in ELB quarters (FEDFUNDS below 0.25% a year).
%   ffr      FEDFUNDS / 4 in every quarter: robs before the ELB blanking.
%   elb      1 in ELB quarters, 0 otherwise.
%   yobs_hamilton    helper, not an observable: the plain Hamilton gap, OLS
%            over 1957Q1-2026Q2 on unadjusted GDP; it echoes the 2020Q2 trough
%            eight quarters later (2022Q1-2023Q2).
%   yobs_fullsample  helper, not an observable: covid-adjusted regressors with
%            the OLS over 1957Q1-2026Q2 (the earlier definition of yobs).
% Checks: dates consecutive; yobs through 2019Q4 equals the residuals of the
% IJCB-sample regression; CPI inflation equals the raw file's inflation_cpi_q;
% the ELB quarters are exactly 2009Q1-2015Q4 and 2020Q2-2022Q1; CSV round trip
% to 1e-12 with the same NaN pattern.
% S returns the summary statistics quoted in README.md. Needs IRIS on the path.

here = fileparts(mfilename('fullpath'));
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
pos = @(y, q) find(yr == y & qt == q);   % row of a quarter

h = 8;  p = 4;
iFirst = pos(1957, 1);                   % first database quarter (IJCB burn-in start)
iEst = pos(2019, 4);                     % last gap date of IJCB's sample
iLast = pos(2026, 2);                    % last quarter with GDP in this vintage
assert(~isempty(iFirst) && ~isempty(iLast), 'Sample dates not in the raw file');
assert(~isfinite(T.real_gdp(end)) || iLast == height(T), 'Raw file has GDP after 2026Q2');
startDate = qq(1957, 1);
endDate = qq(2026, 2);
nPer = iLast - iFirst + 1;

% ---- output gap: Hamilton (2018) filter ------------------------------------------------------
% Covid-adjusted regressors: the 2020Q1-2020Q3 GDP values in the REGRESSORS
% (not in the dependent variable) are a straight line between 2019Q4 and
% 2020Q4, the project's covid quarters (gather_data.py COVID_QUARTERS). This
% removes the echo of the lockdown trough eight quarters later (2022Q1-2023Q2).
gdp = 100*log(T.real_gdp);
gdpX = gdp;
i0 = pos(2019, 4);  i1 = pos(2020, 4);
iC = i0 + 1:i1 - 1;
gdpX(iC) = gdp(i0) + (gdp(i1) - gdp(i0))*(iC - i0)/(i1 - i0);
bIJCB = hamfit(gdp, gdp, iFirst, iEst, h, p);           % IJCB sample, no covid rows
gap = hamgap(gdp, gdpX, iFirst, iLast, h, p, bIJCB);    % yobs
inSample = hamgap(gdp, gdp, iFirst, iEst, h, p, bIJCB);
assert(max(abs(gap(1:numel(inSample)) - inSample)) < 1e-10, 'yobs through 2019Q4 is not the IJCB-sample residual');
bPlain = hamfit(gdp, gdp, iFirst, iLast, h, p);
gapH = hamgap(gdp, gdp, iFirst, iLast, h, p, bPlain);   % yobs_hamilton
bFull = hamfit(gdp, gdpX, iFirst, iLast, h, p);
gapF = hamgap(gdp, gdpX, iFirst, iLast, h, p, bFull);   % yobs_fullsample
% sensitivity: coefficients from every pre-covid gap date the data allow (from 1949Q4)
iFull = 1 + h + p - 1;
gap49 = hamgap(gdp, gdpX, iFirst, iLast, h, p, hamfit(gdp, gdp, iFull, iEst, h, p));

% ---- CPI inflation, % q/q ----------------------------------------------------------------
lcpi = log(T.cpi);
infl = [NaN; 100*diff(lcpi)];
chk = infl(iFirst:iLast) - T.inflation_cpi_q(iFirst:iLast);
assert(max(abs(chk)) < 1e-10, 'CPI inflation differs from inflation_cpi_q: %.3g', max(abs(chk)));

% ---- federal funds rate, % per quarter; ELB quarters ----------------------------------------
ffAnn = T.fedfunds(iFirst:iLast);            % % a year, quarterly average
assert(all(isfinite(ffAnn)), 'FEDFUNDS has gaps in the sample');
elb = ffAnn < 0.25;
elbExpected = [pos(2009,1):pos(2015,4), pos(2020,2):pos(2022,1)] - iFirst + 1;
assert(isequal(find(elb)', elbExpected), 'ELB quarters differ from 2009Q1-2015Q4 and 2020Q2-2022Q1');
ffr = ffAnn/4;
robs = ffr;
robs(elb) = NaN;

% ---- databank ----------------------------------------------------------------------------
d = struct();
d.yobs = Series(startDate, gap);
d.pinfobs = Series(startDate, infl(iFirst:iLast));
d.robs = Series(startDate, robs);
d.ffr = Series(startDate, ffr);
d.elb = Series(startDate, double(elb));
d.yobs_hamilton = Series(startDate, gapH);
d.yobs_fullsample = Series(startDate, gapF);
names = fieldnames(d);
for i = 1:numel(names)
    x = getData(d.(names{i}), startDate:endDate);
    assert(numel(x) == nPer, '%s has the wrong length', names{i});
    if ~strcmp(names{i}, 'robs')
        assert(all(isfinite(x)), '%s has missing values', names{i});
    end
end

csvFile = fullfile(here, 'ijcb3_database.csv');
matFile = fullfile(here, 'ijcb3_database.mat');
databank.toCSV(d, csvFile, startDate:endDate, 'Format', '%.17g');
save(matFile, 'd');

% round trip
d2 = databank.fromCSV(csvFile);
maxErr = 0;
for i = 1:numel(names)
    x = getData(d.(names{i}), startDate:endDate);
    x2 = getData(d2.(names{i}), startDate:endDate);
    assert(numel(x2) == nPer && isequal(isnan(x), isnan(x2)), '%s: round trip changes length or NaNs', names{i});
    ok = ~isnan(x);
    maxErr = max([maxErr; abs(x2(ok) - x(ok))]);
end
assert(maxErr < 1e-12, 'Round trip through CSV fails: %.3g', maxErr);

% ---- summary statistics (README.md) --------------------------------------------------------
est = qq(1960,1):qq(2019,4);
full = qq(1960,1):endDate;
g = @(name, rng) getData(d.(name), rng);
S = struct();
S.coef_ijcb = bIJCB';
S.coef_ijcb_slope_sum = sum(bIJCB(2:end));
S.coef_fullsample = bFull';
S.coef_plain = bPlain';
k60 = pos(1960, 1) - iFirst + 1;             % 1960Q1 within the database
S.gap_1949_maxdiff = max(abs(gap49(k60:end) - gap(k60:end)));
S.mean_pinf_1960_2019 = mean(g('pinfobs', est));
S.std_pinf_1960_2019 = std(g('pinfobs', est));
S.std_dpinf_1960_2019 = std(diff(g('pinfobs', est)));
S.mean_ffr_1960_2019 = mean(g('ffr', est));
S.mean_ffr_elb_2009_2015 = mean(g('ffr', qq(2009,1):qq(2015,4)));
S.std_ffr_elb_2009_2015 = std(g('ffr', qq(2009,1):qq(2015,4)));
S.mean_gap_1960_2019 = mean(g('yobs', est));
S.std_gap_1960_2019 = std(g('yobs', est));
S.maxdiff_plain_1960_2019 = max(abs(g('yobs', est) - g('yobs_hamilton', est)));
S.maxdiff_fullsample_1960_2019 = max(abs(g('yobs', est) - g('yobs_fullsample', est)));
S.n_elb = sum(elb);
win = qq(2020,1):qq(2024,4);
[S.peak_pinf, k] = max(g('pinfobs', win));
S.peak_date = win(k);
[S.gap_min, k] = min(g('yobs', full));
S.gap_min_date = full(k);
cmp = [qq(2020,2), qq(2022,1):qq(2023,2), endDate];
S.cmp_dates = dat2str(cmp);
S.cmp = [g('yobs_hamilton', cmp), g('yobs_fullsample', cmp), g('yobs', cmp)];

fprintf('build_database: %d quarters %s-%s, %d series, round-trip max abs error %.3g\n', ...
    nPer, dat2char(startDate), dat2char(endDate), numel(names), maxErr);
fprintf('Hamilton h=%d p=%d coefficients [constant, y(t), y(t-1), y(t-2), y(t-3)]:\n', h, p);
fprintf('  yobs, OLS over gap dates 1957Q1-2019Q4:                    [%s] slope sum %.4f\n', ...
    sprintf('%.4f ', bIJCB), S.coef_ijcb_slope_sum);
fprintf('  yobs_fullsample, adjusted regressors, OLS 1957Q1-2026Q2:   [%s]\n', sprintf('%.4f ', bFull));
fprintf('  yobs_hamilton, plain, OLS 1957Q1-2026Q2:                   [%s]\n', sprintf('%.4f ', bPlain));
fprintf('yobs through 2019Q4 = residuals of the 1957Q1-2019Q4 regression (checked)\n');
fprintf('yobs with coefficients from 1949Q4-2019Q4 instead: max abs difference 1960Q1-2026Q2 %.3f pp\n', S.gap_1949_maxdiff);
fprintf('yobs vs helpers, 1960Q1-2019Q4: max abs difference to yobs_hamilton %.3f, to yobs_fullsample %.3f\n', ...
    S.maxdiff_plain_1960_2019, S.maxdiff_fullsample_1960_2019);
fprintf('ELB quarters (FEDFUNDS < 0.25%% a year): %d, %s-%s and %s-%s\n', S.n_elb, ...
    dat2char(qq(2009,1)), dat2char(qq(2015,4)), dat2char(qq(2020,2)), dat2char(qq(2022,1)));
fprintf('1960Q1-2019Q4: mean pinfobs %.3f (std %.3f, std of changes %.3f), mean FEDFUNDS/4 %.3f, yobs mean %.3f std %.3f\n', ...
    S.mean_pinf_1960_2019, S.std_pinf_1960_2019, S.std_dpinf_1960_2019, S.mean_ffr_1960_2019, ...
    S.mean_gap_1960_2019, S.std_gap_1960_2019);
fprintf('2009Q1-2015Q4: mean FEDFUNDS/4 %.4f (std %.4f)\n', S.mean_ffr_elb_2009_2015, S.std_ffr_elb_2009_2015);
fprintf('pinfobs peak 2020Q1-2024Q4: %s, %.4f %% q/q (%.2f%% annualised)\n', dat2char(S.peak_date), S.peak_pinf, 4*S.peak_pinf);
fprintf('yobs minimum 1960Q1-2026Q2: %s, %.3f\n', dat2char(S.gap_min_date), S.gap_min);
fprintf('%-8s %14s %16s %8s\n', 'quarter', 'yobs_hamilton', 'yobs_fullsample', 'yobs');
for t = 1:numel(cmp)
    fprintf('%-8s %14.3f %16.3f %8.3f\n', S.cmp_dates{t}, S.cmp(t, 1), S.cmp(t, 2), S.cmp(t, 3));
end
end


function b = hamfit(x, z, i1, i2, h, p)
% OLS of x(t) on [1, z(t-h), ..., z(t-h-p+1)] over the gap dates t = i1..i2.
[X, yv] = hamdesign(x, z, i1, i2, h, p);
b = X\yv;
end


function gap = hamgap(x, z, i1, i2, h, p, b)
% Hamilton gap x(t) - [1, z(t-h), ..., z(t-h-p+1)]*b for t = i1..i2 (dated t).
[X, yv] = hamdesign(x, z, i1, i2, h, p);
gap = yv - X*b;
end


function [X, yv] = hamdesign(x, z, i1, i2, h, p)
t = (i1:i2)';
X = ones(numel(t), p + 1);
for j = 1:p
    X(:, j + 1) = z(t - h - j + 1);
end
yv = x(t);
assert(all(isfinite(X(:))) && all(isfinite(yv)), 'Hamilton filter: missing GDP');
end
