# Installation

## Requirements

- Linux system with GLIBC >= 2.17 (for example CentOS 7 or later)
- Java 11 or later
- [Nextflow](https://www.nextflow.io) 23.10 or later
- 64 GB of RAM and 12 CPU cores. For large datasets a distributed compute system (HPC or cloud) is strongly recommended.
- Working storage of about 5x the input data size, e.g. about 4 TB of temporary storage for deep sequencing of a ScaleBio *small kit*.

## Get the workflow

Install Nextflow, then download (clone) this workflow to your machine. Nextflow runs it with `nextflow run /PATH/TO/ScaleMethyl ...`.

## Dependencies

The workflow needs a number of tools: ScaleBio executables, open-source software and Python libraries. Pick one of the approaches below and select the matching Nextflow `-profile`.

### Docker or Singularity (recommended)

Pre-built containers include every dependency, and the workflow uses them automatically:

| Profile | Use |
|---|---|
| `-profile docker` | Systems with Docker |
| `-profile dockerGPU` | Docker with GPU access, required for the Parabricks aligner |
| `-profile singularity` | Systems with Singularity / Apptainer (2.3.x or newer), common on HPC clusters |

For Singularity:

- `NXF_SINGULARITY_CACHEDIR` controls where images are stored. It should be writable and available on all compute nodes.
- Set `TMPDIR` to a location that is writable from the container if `/tmp` is not.
- All input and output paths must be visible inside the container. Nextflow handles this for Docker; for Singularity, *user mounts* must be enabled in the system-wide configuration. Paths reached through symbolic links must also be visible, so add their target folders to the bind paths if needed (see [Troubleshooting](../reference/troubleshooting.md)).

See [Nextflow containers](https://www.nextflow.io/docs/latest/container.html) for more options.

### Conda

With `-profile conda`, Nextflow creates a conda environment with most dependencies (`envs/scaleMethylTools.conda.yml`). In addition:

- Update conda: `conda update -n base -c defaults conda`
- Install the [ScaleBio tools](#scalebio-tools) (not available through conda)
- When starting from a run folder, Illumina [BCL Convert](https://support.illumina.com/sequencing/sequencing_software/bcl-convert.html) must be installed and on `$PATH`.

Automatic installation works best when the `base` conda environment is clean. See the [Nextflow conda documentation](https://www.nextflow.io/docs/latest/conda.html).

### Manual installation

All requirements are listed in `envs/scaleMethylTools.conda.yml` and `envs/download-scale-tools.sh`. Every tool must be on `$PATH` or in `ScaleMethyl/bin/`.

## ScaleBio tools

Two steps use executables developed by ScaleBio, described in [ScaleBio tools](../reference/scalebio-tools.md):

- `bc_parser`: barcode extraction, error correction and demultiplexing
- `sc_dedup`: barcode-aware BAM deduplication

They are included in the container image, so with a container profile nothing needs to be installed. They are not available through conda; without a container, download the pre-compiled Linux (x86_64) binaries into `ScaleMethyl/bin/` with:

```bash
/PATH/TO/ScaleMethyl/envs/download-scale-tools.sh
```
