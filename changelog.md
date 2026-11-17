# Version 1.4.0 (TOBI lab changes)

- sciMETv3 support: library structures, barcode lists and helper scripts in `references/sciMETv3/`
- Alignment no longer fails when the time of the bwa-meth index `.c2t` file cannot be set (index owned by another user)
- Documentation restructured and published as an MkDocs site (`mkdocs.yml`, `docs/`)
- Pipeline restructured with the nf-core template (nf-core/tools 4.2.2) as `VIBTOBIlab/scalemethyltobi`; the outputs are unchanged
  - `main.nf`, `workflows/`, `subworkflows/local/`, one module per process in `modules/local/` (with nf-test tests)
  - Tool arguments and output paths of all processes in `conf/modules.config`, resources in `conf/base.config`
  - Parameters validated with `nextflow_schema.json` (nf-schema) and the sample table with `assets/schema_input.json`; `--help` lists all parameters
  - Software versions in `pipeline_info/scalemethyltobi_software_versions.yml`, together with the Nextflow execution reports
  - Requires Nextflow >= 25.10.4; the code follows the Nextflow strict syntax (`nextflow lint`)
  - GitHub Actions for nf-test, nf-core lint and pre-commit; `.pre-commit-config.yaml`; development tools in `dev-environment.yml`
- bwa-meth is the only aligner: the `aligner` and `parabricksNumGpu` parameters, the BSBolt and Parabricks processes and the `dockerGPU` profile were removed
- Parameters renamed to snake_case:

  | Before                                                                              | Now                                                                                           |
  | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
  | `samples`                                                                           | `input`                                                                                       |
  | `outDir`                                                                            | `outdir`                                                                                      |
  | `runFolder`, `fastqDir`, `fastqSamplesheet`, `bclConvertParams`                     | `run_folder`, `fastq_dir`, `fastq_samplesheet`, `bcl_convert_params`                          |
  | `libStructure`, `splitFastq`, `calculateCH`, `chReadsThreshold`                     | `lib_structure`, `split_fastq`, `calculate_ch`, `ch_reads_threshold`                          |
  | `covOut`, `allcOut`, `amethystOut`, `parquetOut`                                    | `cov_out`, `allc_out`, `amethyst_out`, `parquet_out`                                          |
  | `fastqOut`, `trimOut`, `bamOut`, `bamDedupOut`                                      | `fastq_out`, `trim_out`, `bam_out`, `bam_dedup_out`                                           |
  | `windowMatrixOut`, `windowTileSizeCG`, `windowTileSizeCH`, `minimumWindowSize`      | `window_matrix_out`, `window_tile_size_cg`, `window_tile_size_ch`, `minimum_window_size`      |
  | `topCellPercentile`, `minCellRatio`, `minUniqCount`, `minUniqTotal`, `maxUniqTotal` | `top_cell_percentile`, `min_cell_ratio`, `min_uniq_count`, `min_uniq_total`, `max_uniq_total` |
  | `dedupKey`, `minMapq`, `runTssEnrich`                                               | `dedup_key`, `min_mapq`, `run_tss_enrich`                                                     |
  | `previousOutDir`, `startPostExtraction`, `reportingOnly`                            | `previous_outdir`, `start_post_extraction`, `reporting_only`                                  |
  | `bam1Dir`, `bam2Dir`, `bamMergeOut`                                                 | `bam1_dir`, `bam2_dir`, `bam_merge_out`                                                       |
  | `maxCpus`, `maxMemory`, `maxTime`                                                   | removed: use `process.resourceLimits` in a config file                                        |
  | `trimFastq`, `bamRgHeader`                                                          | removed (they had no effect)                                                                  |

- Fixes
  - `genomeWindowBlackList` in `genome.json` is resolved relative to `genome.json`, like the other paths
  - With `--reporting_only` and several samples, the reports of all samples are generated
  - The samples are always in the same (alphabetical) order in the library metrics (`<library>.combinedPassingCellStats.csv`) and library report

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
