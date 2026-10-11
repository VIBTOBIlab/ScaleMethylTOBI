# Parameters

Parameters are set in the `runParams.yml` file or on the command line (`--name value`). Defaults are defined in `nextflow.config`.

## Inputs

| Parameter | Default | Description |
|---|---|---|
| `runFolder` | | Illumina run folder; see [Input data](input-data.md) |
| `fastqDir` | | Folder with fastq files; see [Input data](input-data.md) |
| `samples` | | Sample table, required; see [Sample table](samples-csv.md) |
| `genome` | | `genome.json` of the reference, required; see [Reference genomes](reference-genomes.md) |
| `libStructure` | `lib.json` | Library structure definition, as an absolute path or relative to `references/`; see [Library structure](../reference/library-structure.md) |
| `aligner` | `bwa-meth` | `bwa-meth` (bwa-mem2), `bsbolt` (original aligner) or `parabricks` (GPU, bwa-mem; needs `-profile dockerGPU`). The genome needs the matching index. |
| `outDir` | `ScaleMethyl.out` | Output folder |

Library structures included in `references/`:

| `libStructure` | Library |
|---|---|
| `lib.json` | ScaleBio kit v1.0 / v1.1, fastq split by i5 |
| `lib_split_on_i7.json` | ScaleBio kit, fastq split by i7 |
| `prev_pcr/lib.json` | ScaleBio alpha kit |
| `sciMETv3/lib.json` | sciMETv3 with the paper's i5 primers |
| `sciMETv3/lib_D50x.json` | sciMETv3 with TruSeq HT D501-D508 i5 primers |

## Optional outputs

| Parameter | Default | Description |
|---|---|---|
| `fastqOut` | `false` | Publish the bcl-convert fastq files and the demultiplexed sample fastq files |
| `trimOut` | `false` | Publish the trimmed fastq files (`fastq/trim/`) |
| `bamOut` | `false` | Publish the aligned BAM files |
| `bamDedupOut` | `false` | Publish the deduplicated BAM files |
| `covOut` | `true` | Per-cell methylation in bismark `.cov` format (`chr`, `pos`, `percent_methylated`, `methylated_count`, `unmethylated_count`) |
| `allcOut` | `true` | Per-cell methylation in [ALLCools](https://lhqing.github.io/ALLCools/intro.html) format (tabix-indexed) |
| `amethystOut` | `true` | Per-cell methylation in [Amethyst](https://github.com/lrylaarsdam/amethyst) `.h5` format (Amethyst 1.0.0+) |
| `parquetOut` | `true` | Publish the per-well methylation calls (`matrix_generation/`), needed for `startPostExtraction` |
| `windowMatrixOut` | `true` | Genome-bin methylation matrices |

BAM and fastq outputs take a lot of time and storage; enable them only when needed.

## Matrix generation

| Parameter | Default | Description |
|---|---|---|
| `windowTileSizeCG` | `50000` | Bin size (bp) for the CG matrix; ignored when `genomeTiles` is set in `genome.json` |
| `windowTileSizeCH` | `100000` | Bin size (bp) for the CH matrix; ignored when `genomeTilesCH` is set |
| `minimumWindowSize` | `200` | Bins smaller than this after removing blacklisted regions are dropped |
| `calculateCH` | `true` | Calculate CH methylation (reports, matrices, coverage files) |

## Cell calling

By default a barcode is called a cell based on its number of unique (deduplicated) reads:

1. All barcodes with more than `minUniqCount` unique reads are potential cells.
2. The read count of the top cells (*topCount*) is the `topCellPercentile` percentile of those barcodes.
3. The threshold is *topCount* / `minCellRatio`, but never below `minUniqCount`.

| Parameter | Default | Description |
|---|---|---|
| `minUniqCount` | `1000` | Minimum unique reads for a potential cell, and lowest possible threshold |
| `topCellPercentile` | `99` | Percentile used as the "robust maximum" of the potential cells |
| `minCellRatio` | `20` | Ratio between the top cells and the threshold |
| `minUniqTotal` | `1` | Also require at least this percentage of unique reads (unique / total reads) |
| `maxUniqTotal` | `100` | ... and at most this percentage |

A fixed threshold per sample can be set in the `threshold` column of [samples.csv](samples-csv.md); it replaces the calculated one. The sample report plots unique reads against percent unique reads (`report/sample_reports/<sample>/png/<sample>.complexityTotal.png`), which helps to choose `minUniqTotal` / `maxUniqTotal`.

To try a different threshold without rerunning everything, use the [reporting-only workflow](restarting-and-merging.md#reporting-only).

## Read processing

| Parameter | Default | Description |
|---|---|---|
| `chReadsThreshold` | `50` | Reads with more than this percentage of CH methylation are discarded as failed bisulfite conversion |
| `dedupKey` | `Leftmost` | Position used by `sc_dedup` to identify duplicates; see [ScaleBio tools](../reference/scalebio-tools.md#sc_dedup) |
| `minMapq` | `10` | Minimum mapping quality kept during deduplication |
| `runTssEnrich` | `true` | Calculate TSS enrichment (needs `tssWin` and `backgroundWin` in `genome.json`) |
| `fastqc` | `true` | Run FastQC on all input fastq files |
| `adapters` | `references/SciMETv2_Adapters.tsv` | Adapter list used by FastQC |

Adapter trimming always runs with fixed `cutadapt` settings: the reverse complement of the Tn5 adapter (`CTATCTCTTATA`) is trimmed from the 3' end of Read 1, the TruSeq adapter (`AGATCGGAAGAGC`) from the 3' end of Read 2, plus the last 10 bases of Read 2; reads shorter than 20 bp are dropped. The first 10 bases of Read 1 and the barcode and adapter at the start of Read 2 are removed during demultiplexing, as defined in the library structure. The `trimFastq` parameter has no effect in this version.

## Fastq generation

| Parameter | Default | Description |
|---|---|---|
| `fastqSamplesheet` | | Custom bcl-convert samplesheet, replacing the generated one |
| `bclConvertParams` | `--no-lane-splitting true` | Extra bcl-convert options |

## Restarting and merging

| Parameter | Default | Description |
|---|---|---|
| `startPostExtraction` | `false` | Start after methylation extraction; see [Restarting and merging](restarting-and-merging.md) |
| `reportingOnly` | `false` | Only regenerate cell calling and reports |
| `previousOutDir` | | Output folder of the previous run |
| `merged` | `false` | Merge several previous runs, using the `resultDir` column in samples.csv |
| `bam1Dir`, `bam2Dir` | | Start from the BAM files of two previous runs |
| `bamMergeOut` | `false` | Publish the merged BAM files |

## Compute resources

| Parameter | Default | Description |
|---|---|---|
| `splitFastq` | `true` | Split by PCR barcode and Tn5 well for parallel processing; see [Running](running.md#parallel-execution) |
| `maxMemory` | `124.GB` | Largest memory a single task may request |
| `maxCpus` | `32` | Largest number of CPUs a single task may request |
| `maxTime` | `24.h` | Longest run time of a single task |
| `parabricksNumGpu` | `1` | Number of GPU jobs Parabricks alignment is split into |

Per-process resources are set in `nextflow.config` and can be changed in your own config file (`-c`).
