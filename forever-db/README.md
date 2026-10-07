# foreverdb (M1: data / evidence foundation)

Answers: what do we know about a Forever entity, in which build, from which source, with what confidence.
No frontend, API, map or route engine yet. Stdlib only; SQLite storage. See `docs/ARCHITECTURE_M1.md`.

```
python -m pip install -e . pytest                  # tests only need pytest
# Keep acquired data OUTSIDE the repo tree (it contains Blizzard-derived files):
export RAW=../fdb-data/raw
python -m pytest tests/unit                        # synthetic fixtures; always runs
python -m foreverdb registry show
python -m foreverdb registry verify                # tries Blizzard's version service; logs the outcome
python -m foreverdb --raw $RAW acquire att-head att-a054efd   # ~1 GB each: ATT is a large repo
python -m foreverdb --raw $RAW manifest --snapshot att-head
python -m foreverdb --raw $RAW manifest --snapshot att-a054efd
python -m foreverdb manifest-diff --a att-a054efd --b att-head
python -m foreverdb --raw $RAW build-db --snapshot att-head --out ../fdb-data/forever.sqlite
#   add --questv2 CSV --questv2-build B (and --era-questv2 CSV --era-build B) when you have them
python -m foreverdb validate-coords --db ../fdb-data/forever.sqlite
FOREVERDB_RAW=$RAW python -m pytest tests/integration   # needs the acquired snapshots
```

Nothing under `data/` is ever committed. The repository-wide MIT `LICENSE` at the repository root covers the code here (the owner confirms it before publishing); data files are separate and never committed.
