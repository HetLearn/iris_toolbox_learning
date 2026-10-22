# Application 2: replay of the backed-out shocks

**Question.** The RE smoother says which shocks hit the economy in 2022Q3-2026Q2. Feed those
same shocks, quarter by quarter, into the economy with learners. How far does the result move
from what actually happened?

Under RE the replay must give back the data exactly: that is a check on the machinery. Under
learning the same shocks meet different expectations, so the paths differ.

## Scenario files

`scenarios/sw07/app2_replay/`:

```matlab
function cfg = a2_re()
cfg = a1_re();
cfg.id = 'a2_re';
cfg.title = 'App 2: replay of the RE-smoothed shocks 2022Q3-2026Q2, rational expectations';
cfg.shocks.source = 'smoothed';      % the RE-smoothed shocks over the horizon
end

function cfg = a2_learn()
cfg = a1_learn();
cfg.id = 'a2_learn';
cfg.title = 'App 2: replay of the RE-smoothed shocks 2022Q3-2026Q2, learning on inflation';
cfg.shocks.source = 'smoothed';
cfg.compare_with = {'a2_re'};
end
```

`shocks.source = 'smoothed'` takes the shocks of the RE smoother over `shocks.range` (default
`[]`, the whole horizon). Every shock is unanticipated: each quarter is a new one-quarter
simulation with the beliefs and shares of that quarter.

```matlab
run_applications('app2')
```

## Results

| | RE replay | Learning replay | Data |
|---|---:|---:|---:|
| Average inflation 2022Q3-2026Q2 (%) | 3.21 | 4.64 | 3.21 |

- **RE replay = data.** `a2_re` reproduces all seven observables to 5.9e-13 (check C1 of
  `checks_v3.txt`).
- **The learning replay misses the data**: RMS gap 1.62 pp for inflation, 1.22 pp for the
  policy rate, 0.83 pp for output growth and 0.71 pp for consumption growth.
- **Most of the miss is in the first year.** The inflation gap is +2.60 pp in 2022Q3 and
  peaks at +2.81 pp in 2022Q4; 62% of the squared inflation gap falls in 2022Q3-2023Q2. After
  2023Q2 the largest gap is 1.79 pp.

In words: the shocks that bring inflation down under RE are not enough when learners
extrapolate the peak. To match the data with learners in the economy, the shocks themselves
must differ; Application 6 backs them out with the learning model.

## Variations

```matlab
% Replay without the monetary policy shocks
cfg = a2_learn(); cfg.id = 'a2_learn_nom'; cfg.shocks.exclude = {'em'};
hetlearn.run(cfg);

% Replay only the first year of shocks, zero shocks afterwards
cfg = a2_learn(); cfg.id = 'a2_learn_1y'; cfg.shocks.range = qq(2022, 3):qq(2023, 2);
hetlearn.run(cfg);

% Replay plus an extra monetary shock of 0.25 (model units) in 2022Q3
cfg = a2_learn(); cfg.id = 'a2_learn_em'; cfg.shocks.add = {{'em', qq(2022, 3), 0.25}};
hetlearn.run(cfg);
```

All shock options are on [Forecasts, shocks and conditions](../options/forecasts-conditions.md).
