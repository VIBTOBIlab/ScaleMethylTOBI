# VIBTOBIlab/scalemethyltobi: Usage

This page summarises how to run the pipeline. The full user guide is in the [documentation site](index.md):
[running](user-guide/running.md), [input data](user-guide/input-data.md), [sample table](user-guide/samples-csv.md),
[reference genomes](user-guide/reference-genomes.md), [parameters](user-guide/parameters.md) and
[restarting and merging](user-guide/restarting-and-merging.md).

## Samplesheet input

Create a samplesheet with one row per sample and the fastq files of its library, and pass it with `--input`:

```csv title="samples.csv"
sample,barcodes,libName,fastq_1,fastq_2,index_1,index_2
PBMC-S1,1A01-2D12,ScaleMethyl,fastq/Lib_R1_001.fastq.gz,fastq/Lib_R2_001.fastq.gz,fastq/Lib_I1_001.fastq.gz,fastq/Lib_I2_001.fastq.gz
PBMC-S2,2E01-3H12,ScaleMethyl,fastq/Lib_R1_001.fastq.gz,fastq/Lib_R2_001.fastq.gz,fastq/Lib_I1_001.fastq.gz,fastq/Lib_I2_001.fastq.gz
```

| Column      | Description                                                                               |
| ----------- | ----------------------------------------------------------------------------------------- |
| `sample`    | Sample name; letters, digits and dashes only. Required.                                   |
| `libName`   | Library name; letters, digits and dashes only. Required.                                  |
| `barcodes`  | Tn5 (sample) barcode wells of the sample, as ranges separated by `;`. Default: all wells. |
| `fastq_1`   | Read 1 fastq file of the library                                                          |
| `fastq_2`   | Read 2 fastq file of the library                                                          |
| `index_1`   | Index 1 (i7) fastq file of the library                                                    |
| `index_2`   | Index 2 (i5) fastq file of the library                                                    |
| `threshold` | Optional fixed unique-read threshold for cell calling.                                    |
| `resultDir` | Output directory of a previous run, only used with `--merge_runs`.                        |

The fastq files belong to the library, which holds all its samples: give them in at least one row per library. Add rows (repeating a sample) for more sequencing runs of a library; the runs are combined per sample and Tn5 well. Relative paths are relative to the samplesheet. The file is validated with [assets/schema_input.json](../assets/schema_input.json). See the [samplesheet](user-guide/samples-csv.md) page for details.

## Running the pipeline

```bash
nextflow run VIBTOBIlab/scalemethyltobi \
    -profile docker \
    --input samples.csv \
    --genome hg38 \
    --outdir ScaleMethyl.out
```

The reference genome is a pre-built genome selected by name (`--genome hg38` or `--genome mm39`, downloaded by the workflow) or your own `genome.json` (`--genome_json`), see [Reference genomes](user-guide/reference-genomes.md). Fastq files must be generated before the run (bcl-convert with index reads, see [Input data](user-guide/input-data.md)).

Parameters can also be given in a YAML or JSON file with `-params-file`:

```yaml title="params.yaml"
input: "samples.csv"
genome: "hg38"
outdir: "ScaleMethyl.out"
```

```bash
nextflow run VIBTOBIlab/scalemethyltobi -profile docker -params-file params.yaml
```

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

Run `nextflow run VIBTOBIlab/scalemethyltobi --help` to list all parameters (`--help_full` for the hidden ones). They are described in [parameters](user-guide/parameters.md) and `nextflow_schema.json`.

## Core Nextflow arguments

### `-profile`

Use this parameter to choose a configuration profile:

- `test`: a complete configuration for a test run on the small synthetic dataset in `tests/data` (no other parameters needed)
- `docker`, `singularity`, `apptainer`, `podman`: run the tools in the ScaleMethyl container (`public.ecr.aws/o5l3p3e4/scale-methyl-tools`)
- `conda`, `mamba`: create the conda environment `envs/scaleMethylTools.conda.yml`; the ScaleBio tools `bc_parser` and `sc_dedup` must be installed separately (see [installation](getting-started/installation.md))

Profiles can be combined, e.g. `-profile test,docker`. Institutional profiles from [nf-core/configs](https://github.com/nf-core/configs) can be used as well.

### `-resume`

Restart a pipeline run, reusing the results of the tasks that already completed. Only tasks whose inputs changed are rerun.

### `-c`

Custom configuration file, e.g. for the executor of an HPC cluster or the resource limits of your machine:

```groovy title="custom.config"
process {
    executor = 'slurm'
    resourceLimits = [ cpus: 32, memory: 250.GB, time: 72.h ]
}
```

## Updating the pipeline

When running the pipeline from GitHub, Nextflow caches it. Update to the latest version with:

```bash
nextflow pull VIBTOBIlab/scalemethyltobi
```

To make your results reproducible, give the version of the pipeline with `-r` (e.g. `-r 1.4.0`). The version is recorded in `pipeline_info/` and `workflow_info.json` of the output directory.
