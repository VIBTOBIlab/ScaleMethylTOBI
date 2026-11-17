# ScaleMethyl workflow

ScaleMethyl is a [Nextflow](https://www.nextflow.io) workflow for single-cell DNA methylation libraries made by combinatorial indexing. It takes sequencing data (an Illumina run folder or fastq files) to per-cell methylation calls, genome-bin matrices and QC reports.

This copy is based on the ScaleBio Seq Suite: Methylation workflow (v1.3.1), originally available at [github.com/ScaleBio/ScaleMethyl](https://github.com/ScaleBio/ScaleMethyl). It adds library structures and documentation for **sciMETv3** libraries (Nichols et al. 2025, _Cell Genomics_ 5:100726).

## Supported libraries

| Library type                                             | Library structure (`lib_structure`) | Documentation                 |
| -------------------------------------------------------- | ----------------------------------- | ----------------------------- |
| ScaleBio Single Cell Methylation kit v1.0 / v1.1         | `lib.json` (default)                | this site                     |
| ScaleBio alpha kit (previous PCR primers)                | `prev_pcr/lib.json`                 | this site                     |
| sciMETv3 with the paper's i5 PCR primers (Table S1B/S1C) | `sciMETv3/lib.json`                 | [sciMETv3](scimetv3/index.md) |
| sciMETv3 with Illumina TruSeq HT D501-D508 i5 primers    | `sciMETv3/lib_D50x.json`            | [sciMETv3](scimetv3/index.md) |

## What the workflow does

1. **Fastq generation** (only when starting from a run folder): Illumina `bcl-convert` writes one set of fastq files per PCR well.
2. **Barcode demultiplexing**: `bc_parser` finds and error-corrects the cell barcodes and splits reads by sample and Tn5 well.
3. **Adapter trimming** with `cutadapt`.
4. **Alignment** with bwa-meth (bwa-mem2).
5. **Deduplication**: `sc_dedup` removes PCR duplicates per cell barcode.
6. **Methylation extraction**: per-cell CG and CH methylation calls.
7. **Cell calling and QC**: passing cells are selected by unique reads; HTML reports per sample and per library.
8. **Outputs**: per-cell coverage files (bismark `.cov`, ALLC, Amethyst `.h5`) and genome-bin methylation matrices.

## Where to start

- New to the workflow: [Installation](getting-started/installation.md), then the [test run](getting-started/test-run.md).
- Running your own data: [Running the workflow](user-guide/running.md), [Input data](user-guide/input-data.md) and the [sample table](user-guide/samples-csv.md).
- sciMETv3 data: start at [sciMETv3 overview](scimetv3/index.md).
- Understanding results: [Output files](outputs/output-files.md) and [QC reports](outputs/qc-reports.md).

## License

The workflow is distributed under the ScaleBio license agreement (`LICENSE.md` in the repository). By using the ScaleBio software you accept its terms.
