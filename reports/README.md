# Reports

Regression runs write machine-readable JSON and human-readable summaries
here. Contents are gitignored (`reports/*.json`, `reports/*.log`) - never
committed. Locally, look here after running `scripts/run_regression.py`. In
CI, the summary goes to the GitHub Actions job summary and the JSON is
uploaded as a workflow artifact.
