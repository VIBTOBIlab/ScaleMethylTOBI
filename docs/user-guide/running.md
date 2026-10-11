# Running the workflow

## Command

```bash
nextflow run /PATH/TO/ScaleMethyl \
    -profile singularity \
    -params-file runParams.yml \
    -c user.config \
    -resume
```

| Option | Meaning |
|---|---|
| `-profile` | How dependencies are provided: `docker`, `dockerGPU`, `singularity` or `conda` (see [Installation](../getting-started/installation.md)) |
| `-params-file` | YAML file with the analysis parameters (below) |
| `-c` | Optional Nextflow configuration for your system: executor, queues, resource limits, paths |
| `-resume` | Reuse the results of tasks that already completed in a previous run of the same command |

See the [Nextflow documentation](https://www.nextflow.io/docs/latest/index.html) for all `nextflow run` options. Nextflow options start with a single dash (`-profile`); workflow parameters start with two dashes (`--outDir`). Any parameter from the YAML file can also be given (or overridden) on the command line, e.g. `--samples samples.foo.csv`.

## Parameters file

All analysis parameters can be set in a `runParams.yml` file. A minimal example:

```yaml
fastqDir: /path/to/fastqs          # or runFolder: /path/to/illumina/run
samples: /path/to/samples.csv
genome: /path/to/genome.json
outDir: ScaleMethyl.out
```

See [Input data](input-data.md), [Sample table](samples-csv.md), [Reference genomes](reference-genomes.md) and [Parameters](parameters.md) for all options. The test-run example is [runParams.yml](../examples/runParams.yml).

## System configuration

Compute settings belong in a separate config file passed with `-c`. For example, on a SLURM cluster:

```groovy
process.executor = 'slurm'
params.maxMemory = 250.GB   // largest memory a single task may request
params.maxCpus   = 32       // largest number of CPUs a single task may request
params.maxTime   = 72.h     // longest run time for a single task
```

See the [Nextflow configuration documentation](https://www.nextflow.io/docs/latest/config.html) for how configuration files, parameter files and the command line interact, and the [executor documentation](https://www.nextflow.io/docs/latest/executor.html) for HPC schedulers.

## Parallel execution

By default the analysis runs highly parallel, controlled by `splitFastq` (default `true`):

- When starting from a run folder, bcl-convert writes one set of fastq files per PCR (i5) barcode.
- Each set of input fastq files is demultiplexed by a separate `bc_parser` job.
- `bc_parser` splits the reads of each sample by Tn5 well. Trimming, alignment, deduplication and extraction then run as one job per sample and Tn5 well (up to 288 per sample).
- The per-well results are merged again per sample at the end.

When starting from fastq files, the first steps run in parallel per set of input files, so a library delivered as a few very large files is demultiplexed slowly. Splitting the files into chunks helps (see [Input data](input-data.md#large-fastq-files)).

Keep `splitFastq` set to `true` unless your system cannot handle many parallel jobs.

### Parabricks

The Parabricks aligner needs at least one GPU and `-profile dockerGPU` (it does not support conda or singularity). With several GPU instances (e.g. through Seqera Platform on AWS), alignment can be split across them with `parabricksNumGpu`. Docker cannot yet split several GPUs of one machine automatically, so keep `parabricksNumGpu: 1` if in doubt.

## Cloud

Nextflow supports [AWS](https://www.nextflow.io/docs/latest/aws.html), [Azure](https://www.nextflow.io/docs/latest/azure.html) and [Google Cloud](https://www.nextflow.io/docs/latest/google.html). [Seqera Platform](https://seqera.io) (formerly Nextflow Tower) is another way to run the workflow on AWS.

## After a run

- Results are in `outDir` (see [Output files](../outputs/output-files.md)).
- Nextflow's `work/` directory holds all intermediate files and can become very large. Delete it once you no longer need to `-resume`.
- `outDir/workflow_info.json` records the command, parameters, reference and version of the run.
