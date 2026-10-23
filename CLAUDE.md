# Working rules for this repository

- Read WRITING_RULEBOOK.md before editing any documentation (README, docs_site, docs). Apply it as for
  documentation: US spelling, no "you/your", no em dashes, abbreviations spelled out on first use on each page,
  one name per thing, no internal dates or process notes, notation as in docs/technical_appendix. Code, option and
  file names are fine in documentation.
- Never add manuscript, review or internal-notes files to this repository.
- Before committing site changes, `mkdocs build --strict` must pass (pip install -r docs_site/requirements.txt).
  The site deploys from main.
- Do not touch estimation/ or reports/build_estimation_report.py.
- Commits: author tolgaozden <tolgaozdn@gmail.com>, no Co-Authored-By or other AI trailer, one file per commit.
