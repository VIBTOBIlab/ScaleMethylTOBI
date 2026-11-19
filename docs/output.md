# VIBTOBIlab/scalemethyltobi: Output

The outputs are described in detail in [output files](outputs/output-files.md), [QC reports](outputs/qc-reports.md) and [barcode metrics](outputs/barcode-metrics.md). Overview of the output directory (`--outdir`):

| Path                            | Content                                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `samples.csv`                   | Regularized sample table used by the run                                                                    |
| `reports/`                      | HTML QC reports per sample (`samples/`) and per library (`libraries/`)                                      |
| `cell_metrics/`                 | Per-sample metrics used to build the reports (and to restart with `--reporting_only`)                       |
| `methylation_calls/`            | Cell coverage per sample and Tn5 well; methylation calls (`parquet/`), needed for `--start_post_extraction` |
| `bwameth/`                      | Alignment statistics, deduplication statistics and (optionally) BAM files                                   |
| `cutadapt/`                     | FastQC reports (`fastqc/`), trimming statistics (`logs/`) and (optionally) trimmed fastq files              |
| `bc_parser/`                    | Barcode demultiplexing metrics                                                                              |
| `multiqc/`                      | MultiQC report of the read QC, trimming and alignment statistics                                            |
| `samples/`                      | Cell metadata (`<sample>.allCells.csv`), genome-bin matrices and per-cell methylation coverage              |
| `samples/genome_bin_matrix/`    | CG and CH methylation matrices (Matrix Market) with their bins and cell barcodes                            |
| `samples/methylation_coverage/` | Per-cell coverage files: `cov/` (Bismark), `allc/` (ALLCools), `amethyst/` (Amethyst hdf5)                  |
| `workflow_info.json`            | Command, parameters, reference genome and version of the run                                                |
| `pipeline_info/`                | Nextflow execution report, timeline, trace and DAG, parameters, and software versions                       |

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) writes the files in `pipeline_info/`: `execution_report_*.html`, `execution_timeline_*.html`, `execution_trace_*.txt`, `pipeline_dag_*.html`, `params_*.json` (the parameters of the run) and `scalemethyltobi_software_versions.yml` (the version of each tool).
