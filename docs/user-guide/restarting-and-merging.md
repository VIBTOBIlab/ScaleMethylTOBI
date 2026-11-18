# Restarting and merging

Besides a full run from sequencing data, the workflow has entry points that reuse the results of earlier runs.

| Goal                                                              | Entry point                                         |
| ----------------------------------------------------------------- | --------------------------------------------------- |
| Change matrix bins or add coverage formats without re-aligning    | [Start after extraction](#start-after-extraction)   |
| Change the cell-calling threshold and regenerate reports          | [Reporting only](#reporting-only)                   |
| Process plates separately, then combine them                      | [Merging runs](#merging-runs)                       |
| Combine the alignments of two sequencing runs of the same library | [Starting from BAM files](#starting-from-bam-files) |

## Start after extraction

The restart modes read the outputs of the previous runs from `cell_metrics/`, `samples/` and `methylation_calls/parquet/`. Output folders of versions before 1.5.0 (with `metrics_for_reporting/` and `matrix_generation/`, and BAM files in `alignments/bam/`) can be used as well.

`--start_post_extraction true` restarts after the deduplication and methylation extraction steps, before matrix generation. Use it to change the genome bins or to add outputs such as ALLC or Amethyst files without re-aligning.

Requirements: the previous run must have completed methylation extraction (`MET_EXTRACT`) and cell calling (`GENERATE_METRICS`), and kept the per-well methylation calls (`save_parquet: true`, the default). Point `--previous_outdir` at the previous output folder and use a new `--outdir`.

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker -params-file runParams.yml \
    --start_post_extraction true --previous_outdir ScaleMethyl.out \
    --outdir ScaleMethyl.rerun
```

## Reporting only

`--reporting_only true` runs only cell calling and report generation from the metrics of a previous run (`cell_metrics/`; `metrics_for_reporting/` in output folders of versions before 1.5.0). Use it after changing the `threshold` column in [samples.csv](samples-csv.md), or `min_uniq_total` / `max_uniq_total`.

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker --genome hg38 \
    --input samples.csv --reporting_only true \
    --previous_outdir ScaleMethyl.out --outdir ScaleMethyl.reports
```

Use a new `--outdir`; reusing the original folder overwrites its results. The new run produces:

- cell metrics (`<sample>.allCells.csv` and passing-cell statistics);
- sample reports (`reports/samples/<sample>/<sample>.report.html`) with their csv files;
- library reports (`reports/libraries/<libName>/<libName>.report.html`).

These reports do not include the read and barcode statistics of the original run (those do not change); look them up in the original reports.

## Merging runs

For large experiments (e.g. a ScaleBio large kit) each plate can be analysed in a separate run, then combined:

1. Run the workflow on each plate's fastq files without matrix generation: `--skip_window_matrix --skip_cov --skip_amethyst --skip_allc`.
2. Write a merge sample table with a `resultDir` column pointing to the output folder of each run. A sample that is present in several runs is listed once per run with the same name ([samples_merge.csv](../examples/samples_merge.csv)):

   ```csv
   sample,barcodes,libName,resultDir
   PBMC-S1,1A01-1D12;2A01-2D12;3A01-3D12,ScaleMethyl,output
   PBMC-S1,1E01-1H12;2E01-2H12;3E01-3H12,ScaleMethyl,output2
   ```

3. Run with `--start_post_extraction true --merge_runs true` (or `--reporting_only true --merge_runs true` for combined reports only). Do not combine `merge_runs` with `previous_outdir`.

This combines the metrics and reports and generates the matrices for the merged samples. It assumes the runs contain different cells (different barcodes); runs whose cells can carry identical barcodes, such as sciMETv3 PCR libraries made with the same primers, should instead be kept separate and combined afterwards with unique cell names ([Combining libraries](../scimetv3/combining-libraries.md)).

## Starting from BAM files

The workflow can also start from the aligned BAM files of two previous runs, e.g. two sequencing runs of the same library. For each `<sample>.<tn5 well>` the two BAM files are merged with `samtools merge`, after setting the read group (`ID`, `LB`) of each input, and then processed from deduplication onwards.

| Parameter       | Description                                                             |
| --------------- | ----------------------------------------------------------------------- |
| `bam1_dir`      | BAM folder of the first run, e.g. `outdir_run1/bwameth/alignments`          |
| `bam2_dir`      | BAM folder of the second run                                            |
| `input`         | The sample table used for the original runs (same samples and barcodes) |
| `save_merged_bam` | Publish the merged BAM files to `outdir/bwameth/alignments/merged/` (default `false`)    |

The previous runs must have published their BAM files (`save_bam: true`). The files are expected in the layout written by a previous run, one per sample and Tn5 well: `<bamDir>/<sample>.<tn5 well>/<sample>.<tn5 well>.bam`. Trimming and alignment statistics are not available in the reports of a run started from BAM files.
