# Crawler

To run the crawler,

```
cd crawler144
go run . # default settings
```

Results are saved as json lines (```graph.jsonl```), with a url field and a children field (list of urls on page).

Graphs were made after processing the jsonl file.

# Data Processing/Visualization

There's a `requirements.txt` in the root directory. Install those and then run the Jupyter notebook `p1.ipynb` in this directory to get the plots/metrics.
