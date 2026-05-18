# AgenticR Evaluation

Evaluates AgenticR's ability to translate natural language into correct R code.

## Structure

```
eval/
├── runner.R              # Feeds NL → AgenticR, saves generated code
├── scorer.R              # Scores results (exec, output, similarity)
├── benchmarks/
│   ├── dplyr/            # 20 dplyr examples
│   ├── ggplot2/          # 20 ggplot2 examples
│   └── base_r/           # 20 base R examples
└── results/              # JSONL output files
```

## Benchmark format

Each `.R` file:
- Line 1: `# NL: <natural language description>`
- Lines 2+: expected R code

Example:
```r
# NL: using mtcars, keep only the rows where mpg is greater than 20
filter(mtcars, mpg > 20)
```

## Running

```r
# Requires configured API key (agentic_setup or env var)
cd eval
Rscript runner.R    # ~ 60 API calls, saves results_YYYYMMDD.jsonl
Rscript scorer.R    # scores the latest results file
```

## Scoring

| Metric | Weight | Description |
|--------|--------|-------------|
| exec | 0.3 | Generated code runs without error |
| output | 0.5 | Generated output matches expected output |
| sim | 0.2 | Token similarity between generated and expected code |

Composite = `exec × 0.3 + output × 0.5 + sim × 0.2`
