# Version 1.5.0

- Pipeline restructured with the nf-core template (nf-core/tools 4.2.2) as `VIBTOBIlab/scalemethyltobi`; the output files are unchanged, only their folders (see below)
  - `main.nf`, `workflows/`, `subworkflows/local/`, one module per process in `modules/local/` (with nf-test tests)
  - Tool arguments and output paths of all processes in `conf/modules.config`, resources in `conf/base.config`
  - Parameters validated with `nextflow_schema.json` (nf-schema) and the sample table with `assets/schema_input.json`; `--help` lists all parameters
  - Software versions in `pipeline_info/scalemethyltobi_software_versions.yml`, together with the Nextflow execution reports
  - Requires Nextflow >= 26.04.0 (typed parameters in `main.nf`); the code follows the Nextflow strict syntax (`nextflow lint`)
  - GitHub Actions for nf-test, nf-core lint and pre-commit; `.pre-commit-config.yaml`; development tools in `dev-environment.yml`
- Input from one samplesheet (`--input`): the fastq files of each library are given in the `fastq_1`, `fastq_2`, `index_1` and `index_2` columns (absolute, relative to the samplesheet, or URLs), so file names no longer matter
  - Several sequencing runs (or lanes, or chunks) of a library are given as additional rows; each set of fastq files is demultiplexed by its own `bc_parser` job and the runs are combined per sample and Tn5 well before trimming
  - `--fastq_dir` and `--run_folder` (with the bcl-convert step, `--fastq_samplesheet` and `--bcl_convert_params`) were removed; `bin/bcl_convert_sheet.py` can still write a bcl-convert samplesheet before the run
  - `libName` is required in the samplesheet
- Reference genome: `--genome` selects a pre-built genome by name (`hg38` or `mm39`, `conf/genomes.config`), which is downloaded from the ScaleBio archives and unpacked (`--genomes_base` reads a mirror); your own `genome.json` is given with `--genome_json` (previously `--genome`)
- MultiQC report (`multiqc/`) of FastQC, cutadapt and samtools flagstat (`--skip_multiqc`, `--multiqc_title`)
- Channels carry nf-core style meta maps (`[id, sample, well]`) instead of names parsed from file names
- bwa-meth is the only aligner: the `aligner` and `parabricksNumGpu` parameters, the BSBolt and Parabricks processes and the `dockerGPU` profile were removed
- Parameters renamed to the nf-core conventions (snake_case; `skip_*` for steps that run by default, `save_*` for published intermediate files):

  | Before                                                                              | Now                                                                                                 |
  | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
  | `samples`                                                                           | `input`                                                                                             |
  | `genome` (genome.json)                                                              | `genome_json`; `genome` now selects a pre-built genome (`hg38`, `mm39`)                             |
  | `outDir`                                                                            | `outdir`                                                                                            |
  | `runFolder`, `fastqDir`, `fastqSamplesheet`, `bclConvertParams`                     | removed: fastq files are listed in the samplesheet                                                  |
  | `libStructure`, `splitFastq`, `chReadsThreshold`                                    | `lib_structure`, `split_fastq`, `ch_reads_threshold`                                                |
  | `calculateCH`, `runTssEnrich`, `windowMatrixOut` (default `true`)                   | `skip_ch_context`, `skip_tss_enrich`, `skip_window_matrix` (default `false`)                        |
  | `fastqc` (default `true`)                                                           | `skip_fastqc` (default `false`)                                                                     |
  | `covOut`, `allcOut`, `amethystOut` (default `true`)                                 | `skip_cov`, `skip_allc`, `skip_amethyst` (default `false`)                                          |
  | `parquetOut`, `fastqOut`, `trimOut`, `bamOut`, `bamDedupOut`, `bamMergeOut`         | `save_parquet`, `save_demux_fastq`, `save_trimmed`, `save_bam`, `save_dedup_bam`, `save_merged_bam` |
  | `windowTileSizeCG`, `windowTileSizeCH`, `minimumWindowSize`                         | `window_tile_size_cg`, `window_tile_size_ch`, `minimum_window_size`                                 |
  | `topCellPercentile`, `minCellRatio`, `minUniqCount`, `minUniqTotal`, `maxUniqTotal` | `top_cell_percentile`, `min_cell_ratio`, `min_uniq_count`, `min_uniq_total`, `max_uniq_total`       |
  | `dedupKey`, `minMapq`                                                               | `dedup_key`, `min_mapq`                                                                             |
  | `previousOutDir`, `startPostExtraction`, `reportingOnly`, `merged`                  | `previous_outdir`, `start_post_extraction`, `reporting_only`, `merge_runs`                          |
  | `bam1Dir`, `bam2Dir`                                                                | `bam1_dir`, `bam2_dir`                                                                              |
  | `maxCpus`, `maxMemory`, `maxTime`                                                   | removed: use `process.resourceLimits` in a config file                                              |
  | `trimFastq`, `bamRgHeader`                                                          | removed (they had no effect)                                                                        |

- The samplesheet is read with nf-schema (`samplesheetToList`, `assets/schema_input.json`) in the pipeline initialisation, which replaces `bin/regularize_samples_csv.py`: the default barcodes (all wells of the library structure), the `split` column and the checks (conflicting rows of a sample, more than one sample of a library without barcodes) are done there; `samples.csv` in the output folder is unchanged
- The main workflow is a short sequence of commented steps; the read processing up to the alignment is one subworkflow (`FASTQ_DEMUX_TRIM_ALIGN`) and the per-sample statistics are merged in `BAM_DEDUP_EXTRACT`
- Cells are named `<sample>_<barcode>` in `samples/` (`allCells.csv`, matrix barcodes and Amethyst `.h5` files), so that all samples and libraries can be loaded together in Amethyst without `rename_amethyst_cells.py`; `--skip_cell_prefix` keeps the barcodes as names. The workflow itself keeps using the barcodes (`cell_metrics/<sample>.allCells.csv`)
- Output folders organised per tool, as in nf-core/methylseq (the file names and contents are unchanged; `samples/` keeps the layout read by Amethyst). Output folders of previous versions can still be used to restart (`--reporting_only`, `--start_post_extraction`, `--merge_runs`, `--bam1_dir` / `--bam2_dir`):

  | Before                                                  | Now                                                                                                                       |
  | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
  | `fastq/fastqc/`                                         | `cutadapt/fastqc/`                                                                                                        |
  | `fastq/trim/<sample>.<well>/`                           | `cutadapt/logs/` (with the cutadapt report `<sample>.<well>.trim_log`); trimmed fastq files in `cutadapt/`                |
  | `barcodes/`                                             | `bc_parser/`                                                                                                              |
  | `alignments/bam/<sample>.<well>/`                       | `bwameth/alignments/` (with `samtools_stats/<sample>.<well>.flagstat.txt`)                                                |
  | `bamMerge/<sample>.<well>/`                             | `bwameth/alignments/merged/`                                                                                              |
  | `alignments/dedup/<sample>.<well>/`                     | `bwameth/deduplicated/` (BAM files) and `bwameth/deduplicated/logs/` (statistics); `cellInfo.txt` in `methylation_calls/` |
  | `matrix_generation/`                                    | `methylation_calls/parquet/`                                                                                              |
  | `metrics_for_reporting/`                                | `cell_metrics/`                                                                                                           |
  | `report/sample_reports/`, `report/library_report/`      | `reports/samples/`, `reports/libraries/`                                                                                  |
  | `samples/`, `samples.csv`, `multiqc/`, `pipeline_info/` | unchanged                                                                                                                 |

- Fixes
  - `genomeWindowBlackList` in `genome.json` is resolved relative to `genome.json`, like the other paths
  - Parameters given on the command line as `true`/`false` or numbers are converted (with Nextflow 26 they stayed strings, so e.g. `--split_fastq false` had no effect)
  - `--split_fastq false` no longer fails in the matrix generation (the per-sample and merged matrices had the same file names)
  - With `--reporting_only` and several samples, the reports of all samples are generated
  - The samples are always in the same (alphabetical) order in the library metrics (`<library>.combinedPassingCellStats.csv`) and library report

# Version 1.4.0 (TOBI lab changes)

- sciMETv3 support: library structures, barcode lists and helper scripts in `references/sciMETv3/`
- Alignment no longer fails when the time of the bwa-meth index `.c2t` file cannot be set (index owned by another user)
- Documentation restructured and published as an MkDocs site (`mkdocs.yml`, `docs/`)

# Version 1.3

## 1.3.1

- Fix to using custom windows for CH contexts

## 1.3.0

- Provides updated Amethyst output for v1.0.0, update your Amethyst to 1.0.0 to use final output.
- Adds support for BWA-meth/parabricks aligner and sets BWA-meth as new default, providing improved runtime performance and filtering spurious low-coverage methylation sites.
- Numerous reporting improvements, including UMAP generation

# Version 1.2

## 1.2.3

- Fix to Amethyst output (CG and CH context was being output switched)
  - Introduced in v1.2.0 and affecting runs with --amethystOut True
  - Can use --startPostExtraction True and --previousOutDir options to fix without re-running the entire workflow

## 1.2.2

- Fix to sample merging (especially when calculating CH contexts)
- Using local tempdir to avoid permission errors in reporting

## 1.2.1

- Fix remote URL in sample and library QC reports (HTML)

## 1.2.0

- Analysis workflow support for individual plates & subsequent plate merging (docs/mergeMultipleAlignments.md)
- Window-size input for matrix gen, rather than file-format upload (including blacklist)
- Post-alignment checkpoint - allows for quick re-run of matrix gen
- Optional CH context calculations
- allcools files are tabix indexed automatically
- Reporting updates

# Version 1.1.0

- Added Amethyst compatible .h5 cell-methylation outputs
- Changed matrix format (see Outputs > Output files).
- Filter reads/fragments with artifically high CH methylation signal
- Updated QC metrics and sample QC (HTML) report (see Outputs > QC reports)
- Updated output directory structure (see Outputs > Output files)
- Updated per-cell methylation signal extraction to handle indel errors in reads as well as improve runtime performance
- Combined all depenencies in a single conda environment / docker container
- Use cutadapt directly for adapter trimming

# Version 1.0.4

- Added optional single-cell output formats (see User guide > Parameters): ALLC and Bismark coverage files

# Version 1.0.3

- Upgraded datapane version and downgraded urllib version in containers

# Version 1.0.2

- Updated the testing dataset including examples for runParams.yml, samples.csv and samplesheet.csv's
- Option for TSS enrichment `--runTssEnrich`
- Add option to pass a different bin size to CG and CH matrix generation
  - `tssWin` and `backgroundWin` in genome.json (see User guide > Reference genomes)

# Version 1.0.1

- Add TSS enrichment to sample QC reports
  - `genomeTiles` and `genomeTilesCH` in genome.json (see User guide > Reference genomes)
- Add options for filtering passing cells by a percent uniquely mapped reads
  - See `--minUniqTotal` and `--maxUniqTotal`
- Add options to turn off CG or CH matrix generation
  - See `--matrixGenerationCG` and `--matrixGenerationCH`
- Add library structure for splitting by i7 rather than i5 during bcl-convert. See `references/lib_split_on_i7.json`
- Add multiqc for trimmed fastqs
- README updates

# Version 1.0

Initial Release
