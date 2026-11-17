# VIBTOBIlab/scalemethyltobi: Usage

This page summarises how to run the pipeline. The full user guide is in the [documentation site](index.md):
[running](user-guide/running.md), [input data](user-guide/input-data.md), [sample table](user-guide/samples-csv.md),
[reference genomes](user-guide/reference-genomes.md), [parameters](user-guide/parameters.md) and
[restarting and merging](user-guide/restarting-and-merging.md).

## Samplesheet input

Create a `samples.csv` with one row per sample and pass it with `--input`:

```csv title="samples.csv"
sample,barcodes,libName
PBMC-S1,1A01-2D12,ScaleMethyl
PBMC-S2,2E01-3H12,ScaleMethyl
```

| Column      | Description                                                                               |
| ----------- | ----------------------------------------------------------------------------------------- |
| `sample`    | Sample name; letters, digits and dashes only. Required.                                   |
| `barcodes`  | Tn5 (sample) barcode wells of the sample, as ranges separated by `;`. Default: all wells. |
| `libName`   | Library name: the prefix of the fastq file names. Default: `ScaleMethyl`.                 |
| `threshold` | Optional fixed unique-read threshold for cell calling.                                    |
| `resultDir` | Output directory of a previous run, only used with `--merged`.                            |

The file is validated with [assets/schema_input.json](../assets/schema_input.json). See the [sample table](user-guide/samples-csv.md) page for details.

## Running the pipeline

```bash
nextflow run VIBTOBIlab/scalemethyltobi \
    -profile docker \
    --input samples.csv \
    --genome /path/to/genome.json \
    --fastq_dir /path/to/fastqs \
    --outdir ScaleMethyl.out
```

Use `--run_folder` instead of `--fastq_dir` to start from an Illumina run folder (BCL files). The reference genome is described by a [genome.json](user-guide/reference-genomes.md) file with a bwa-meth index.

Parameters can also be given in a YAML or JSON file with `-params-file`:

```yaml title="params.yaml"
input: "samples.csv"
genome: "/path/to/genome.json"
fastq_dir: "/path/to/fastqs"
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
