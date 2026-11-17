# VIBTOBIlab/scalemethyltobi: Output

The outputs are described in detail in [output files](outputs/output-files.md), [QC reports](outputs/qc-reports.md) and [barcode metrics](outputs/barcode-metrics.md). Overview of the output directory (`--outdir`):

| Path                            | Content                                                                                        |
| ------------------------------- | ---------------------------------------------------------------------------------------------- |
| `samples.csv`                   | Regularized sample table used by the run                                                       |
| `report/`                       | HTML QC reports per sample (`sample_reports/`) and per library (`library_report/`)             |
| `samples/`                      | Cell metadata (`<sample>.allCells.csv`), genome-bin matrices and per-cell methylation coverage |
| `samples/genome_bin_matrix/`    | CG and CH methylation matrices (Matrix Market) with their bins and cell barcodes               |
| `samples/methylation_coverage/` | Per-cell coverage files: `cov/` (Bismark), `allc/` (ALLCools), `amethyst/` (Amethyst hdf5)     |
| `metrics_for_reporting/`        | Per-sample metrics used to build the reports (and to restart with `--reporting_only`)          |
| `matrix_generation/`            | Methylation calls per sample and Tn5 well (parquet), needed for `--start_post_extraction`      |
| `barcodes/`                     | Barcode demultiplexing metrics (bc_parser)                                                     |
| `fastq/`                        | FastQC reports, trimming statistics and (optionally) trimmed fastq files                       |
| `multiqc/`                      | MultiQC report of the read QC, trimming and alignment statistics                               |
| `alignments/`                   | Deduplication statistics, cell info and (optionally) BAM files                                 |
| `workflow_info.json`            | Command, parameters, reference genome and version of the run                                   |
| `pipeline_info/`                | Nextflow execution report, timeline, trace and DAG, parameters, and software versions          |

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) writes the files in `pipeline_info/`: `execution_report_*.html`, `execution_timeline_*.html`, `execution_trace_*.txt`, `pipeline_dag_*.html`, `params_*.json` (the parameters of the run) and `scalemethyltobi_software_versions.yml` (the version of each tool).
