# Parameters

Parameters are set in the `runParams.yml` file or on the command line (`--name value`). Defaults are defined in `nextflow.config`; all parameters are described and validated with `nextflow_schema.json` (`nextflow run VIBTOBIlab/scalemethyltobi --help`). Parameter names use snake_case, as in nf-core pipelines; see the [changelog](../changelog.md) for the names used before version 1.4.0.

## Inputs

| Parameter       | Default           | Description                                                                                                                                |
| --------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `input`         |                   | Samplesheet with the samples and the fastq files of their libraries, required; see [Samplesheet](samples-csv.md)                           |
| `lib_structure` | `lib.json`        | Library structure definition, as an absolute path or relative to `references/`; see [Library structure](../reference/library-structure.md) |
| `outdir`        | `ScaleMethyl.out` | Output folder                                                                                                                              |

Library structures included in `references/`:

| `lib_structure`          | Library                                      |
| ------------------------ | -------------------------------------------- |
| `lib.json`               | ScaleBio kit v1.0 / v1.1, fastq split by i5  |
| `lib_split_on_i7.json`   | ScaleBio kit, fastq split by i7              |
| `prev_pcr/lib.json`      | ScaleBio alpha kit                           |
| `sciMETv3/lib.json`      | sciMETv3 with the paper's i5 primers         |
| `sciMETv3/lib_D50x.json` | sciMETv3 with TruSeq HT D501-D508 i5 primers |

## Reference genome

Give either `genome` or `genome_json`; see [Reference genomes](reference-genomes.md).

| Parameter       | Default                                      | Description                                                                                  |
| --------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `genome`        |                                              | Pre-built genome by name: `hg38` or `mm39` (`conf/genomes.config`); downloaded and unpacked  |
| `genome_json`   |                                              | Your own `genome.json` with the bwa-meth index and annotation files                          |
| `genomes_base`  | ScaleBio AWS S3 bucket                       | Location of the pre-built genome archives (URL or folder), e.g. a local mirror               |

## Optional outputs

| Parameter           | Default | Description                                                                                                                  |
| ------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `fastq_out`         | `false` | Publish the demultiplexed sample fastq files                                                                                 |
| `trim_out`          | `false` | Publish the trimmed fastq files (`fastq/trim/`)                                                                              |
| `bam_out`           | `false` | Publish the aligned BAM files                                                                                                |
| `bam_dedup_out`     | `false` | Publish the deduplicated BAM files                                                                                           |
| `cov_out`           | `true`  | Per-cell methylation in bismark `.cov` format (`chr`, `pos`, `percent_methylated`, `methylated_count`, `unmethylated_count`) |
| `allc_out`          | `true`  | Per-cell methylation in [ALLCools](https://lhqing.github.io/ALLCools/intro.html) format (tabix-indexed)                      |
| `amethyst_out`      | `true`  | Per-cell methylation in [Amethyst](https://github.com/lrylaarsdam/amethyst) `.h5` format (Amethyst 1.0.0+)                   |
| `parquet_out`       | `true`  | Publish the per-well methylation calls (`matrix_generation/`), needed for `start_post_extraction`                            |
| `window_matrix_out` | `true`  | Genome-bin methylation matrices                                                                                              |

BAM and fastq outputs take a lot of time and storage; enable them only when needed.

## Matrix generation

| Parameter             | Default  | Description                                                                         |
| --------------------- | -------- | ----------------------------------------------------------------------------------- |
| `window_tile_size_cg` | `50000`  | Bin size (bp) for the CG matrix; ignored when `genomeTiles` is set in `genome.json` |
| `window_tile_size_ch` | `100000` | Bin size (bp) for the CH matrix; ignored when `genomeTilesCH` is set                |
| `minimum_window_size` | `200`    | Bins smaller than this after removing blacklisted regions are dropped               |
| `calculate_ch`        | `true`   | Calculate CH methylation (reports, matrices, coverage files)                        |

## Cell calling

By default a barcode is called a cell based on its number of unique (deduplicated) reads:

1. All barcodes with more than `min_uniq_count` unique reads are potential cells.
2. The read count of the top cells (_topCount_) is the `top_cell_percentile` percentile of those barcodes.
3. The threshold is _topCount_ / `min_cell_ratio`, but never below `min_uniq_count`.

| Parameter             | Default | Description                                                                  |
| --------------------- | ------- | ---------------------------------------------------------------------------- |
| `min_uniq_count`      | `1000`  | Minimum unique reads for a potential cell, and lowest possible threshold     |
| `top_cell_percentile` | `99`    | Percentile used as the "robust maximum" of the potential cells               |
| `min_cell_ratio`      | `20`    | Ratio between the top cells and the threshold                                |
| `min_uniq_total`      | `1`     | Also require at least this percentage of unique reads (unique / total reads) |
| `max_uniq_total`      | `100`   | ... and at most this percentage                                              |

A fixed threshold per sample can be set in the `threshold` column of [samples.csv](samples-csv.md); it replaces the calculated one. The sample report plots unique reads against percent unique reads (`report/sample_reports/<sample>/png/<sample>.complexityTotal.png`), which helps to choose `min_uniq_total` / `max_uniq_total`.

To try a different threshold without rerunning everything, use the [reporting-only workflow](restarting-and-merging.md#reporting-only).

## Read processing

| Parameter            | Default                            | Description                                                                                                       |
| -------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `ch_reads_threshold` | `50`                               | Reads with more than this percentage of CH methylation are discarded as failed bisulfite conversion               |
| `dedup_key`          | `Leftmost`                         | Position used by `sc_dedup` to identify duplicates; see [ScaleBio tools](../reference/scalebio-tools.md#sc_dedup) |
| `min_mapq`           | `10`                               | Minimum mapping quality kept during deduplication                                                                 |
| `run_tss_enrich`     | `true`                             | Calculate TSS enrichment (needs `tssWin` and `backgroundWin` in `genome.json`)                                    |
| `fastqc`             | `true`                             | Run FastQC on all input fastq files                                                                               |
| `adapters`           | `references/SciMETv2_Adapters.tsv` | Adapter list used by FastQC                                                                                       |

Adapter trimming always runs with fixed `cutadapt` settings: the reverse complement of the Tn5 adapter (`CTATCTCTTATA`) is trimmed from the 3' end of Read 1, the TruSeq adapter (`AGATCGGAAGAGC`) from the 3' end of Read 2, plus the last 10 bases of Read 2; reads shorter than 20 bp are dropped. The first 10 bases of Read 1 and the barcode and adapter at the start of Read 2 are removed during demultiplexing, as defined in the library structure.

## MultiQC

| Parameter       | Default | Description                                                                                   |
| --------------- | ------- | --------------------------------------------------------------------------------------------- |
| `skip_multiqc`  | `false` | Do not make the MultiQC report (FastQC, cutadapt and samtools flagstat, in `outdir/multiqc/`) |
| `multiqc_title` |         | Title of the MultiQC report                                                                   |

## Restarting and merging

| Parameter               | Default | Description                                                                                 |
| ----------------------- | ------- | ------------------------------------------------------------------------------------------- |
| `start_post_extraction` | `false` | Start after methylation extraction; see [Restarting and merging](restarting-and-merging.md) |
| `reporting_only`        | `false` | Only regenerate cell calling and reports                                                    |
| `previous_outdir`       |         | Output folder of the previous run                                                           |
| `merged`                | `false` | Merge several previous runs, using the `resultDir` column in samples.csv                    |
| `bam1_dir`, `bam2_dir`  |         | Start from the BAM files of two previous runs                                               |
| `bam_merge_out`         | `false` | Publish the merged BAM files                                                                |

## Compute resources

| Parameter     | Default | Description                                                                                             |
| ------------- | ------- | ------------------------------------------------------------------------------------------------------- |
| `split_fastq` | `true`  | Split by PCR barcode and Tn5 well for parallel processing; see [Running](running.md#parallel-execution) |

Reads are aligned with bwa-meth (bwa-mem2). Per-process resources are set in `conf/base.config` and can be changed in your own config file (`-c`). Use `process.resourceLimits` to cap what a single task may request (this replaces the former `maxMemory`, `maxCpus` and `maxTime` parameters); see [Running](running.md#system-configuration).
