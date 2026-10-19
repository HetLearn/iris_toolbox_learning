function d = build_database()
% BUILD_DATABASE  SW07 observables as an IRIS databank, 1965Q1-2026Q2.
%
% Reads  data/sw_ext_1966_latest.csv (the Dynare estimation panel of run swX1)
% Writes data/sw07_database.csv (databank.toCSV) and data/sw07_database.mat
% Checks that databank.fromCSV on the written CSV reproduces the input to 1e-12 and that
% exactly the covid quarters are missing.
% Needs IRIS on the path. See data/README.md for provenance.

here = fileparts(mfilename('fullpath'));
obs = {'dy', 'dc', 'dinve', 'dw', 'labobs', 'pinfobs', 'robs'};
startDate = qq(1965,1);
endDate = qq(2026,2);
% Covid quarters: every observable is set to NaN in these quarters, so the RE filter treats them
% as missing data (user decision 2026-10-19: ignore the covid quarters; the raw panel keeps
% them, and nothing else changes). Set to [] to keep them, as before 2026-10-19.
covid_nan_quarters = qq(2020,1):qq(2020,3);

T = readtable(fullfile(here, 'sw_ext_1966_latest.csv'), 'TextType', 'string');
nPer = height(T);
assert(nPer == 246, 'Expected 246 rows, found %d', nPer);
assert(T.date(1) == "1965Q1" && T.date(end) == "2026Q2", 'Unexpected date span');
% every row must be the next quarter
yr = double(extractBefore(T.date, "Q"));
qt = double(extractAfter(T.date, "Q"));
assert(all(diff(yr*4 + qt) == 1), 'Dates are not consecutive quarters');

d = struct();
for i = 1:numel(obs)
    x = T.(obs{i});
    assert(all(isfinite(x)), '%s has missing values', obs{i});
    d.(obs{i}) = Series(startDate, x);
    if ~isempty(covid_nan_quarters)
        d.(obs{i})(covid_nan_quarters) = NaN;
    end
end
covidRows = round(double(covid_nan_quarters) - double(startDate)) + 1;   % row positions in the panel

csvFile = fullfile(here, 'sw07_database.csv');
matFile = fullfile(here, 'sw07_database.mat');
databank.toCSV(d, csvFile, startDate:endDate, 'Format', '%.17g');
save(matFile, 'd');

% round-trip check
d2 = databank.fromCSV(csvFile);
maxErr = 0;
nNaN = 0;
for i = 1:numel(obs)
    x2 = getData(d2.(obs{i}), startDate:endDate);
    assert(numel(x2) == nPer, '%s: wrong length after round trip', obs{i});
    xe = T.(obs{i});
    xe(covidRows) = NaN;
    assert(isequal(isnan(x2(:)), isnan(xe)), '%s: NaN pattern differs after round trip', obs{i});
    nNaN = nNaN + nnz(isnan(x2));
    ok = ~isnan(xe);
    maxErr = max(maxErr, max(abs(x2(ok) - xe(ok))));
end
assert(nNaN == numel(obs) * numel(covidRows), 'Expected %d NaN values, found %d', numel(obs) * numel(covidRows), nNaN);
fprintf('build_database: %d NaN values (covid quarters %s-%s)\n', nNaN, dat2char(covid_nan_quarters(1)), dat2char(covid_nan_quarters(end)));
fprintf('build_database: %d quarters %s-%s, %d series, round-trip max abs error %.3g\n', ...
    nPer, dat2char(startDate), dat2char(endDate), numel(obs), maxErr);
assert(maxErr < 1e-12, 'Round trip through CSV fails: %.3g', maxErr);

end
