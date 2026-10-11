# ScaleMethyl workflow (with sciMETv3 support)

A Nextflow workflow for single-cell DNA methylation libraries made by combinatorial indexing. It takes sequencing reads to alignments, per-cell methylation calls (bismark `.cov`, ALLC, Amethyst `.h5`), genome-bin matrices and QC reports.

This repository is a copy of the ScaleBio Seq Suite: Methylation workflow (v1.3.1), originally available at https://github.com/ScaleBio/ScaleMethyl. It adds library structures and helper scripts for **sciMETv3** libraries (Nichols et al. 2025, *Cell Genomics* 5:100726), a fix for alignment against shared bwa-meth indexes, and restructured documentation.

## Supported libraries

| Library | `libStructure` |
|---|---|
| ScaleBio Single Cell Methylation kit v1.0 / v1.1 | `lib.json` (default) |
| ScaleBio alpha kit | `prev_pcr/lib.json` |
| sciMETv3 with the paper's i5 primers | `sciMETv3/lib.json` |
| sciMETv3 with TruSeq HT D501-D508 i5 primers | `sciMETv3/lib_D50x.json` |

## Quick start

Requirements: Linux, Java 11+, [Nextflow](https://www.nextflow.io) 23.10+, and Docker, Singularity/Apptainer or Conda.

Test run with the example data (downloaded automatically):

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker \
    -params-file /PATH/TO/ScaleMethyl/docs/examples/runParams.yml --outDir ScaleMethyl.out
```

Your own data, with a `runParams.yml` such as:

```yaml
fastqDir: /path/to/fastqs          # or runFolder: /path/to/illumina/run
samples: samples.csv
genome: /path/to/genome.json
libStructure: "lib.json"
outDir: ScaleMethyl.out
```

```bash
nextflow run /PATH/TO/ScaleMethyl -profile singularity -params-file runParams.yml
```

## Documentation

The full documentation is in [docs/](docs/index.md):

- [Installation](docs/getting-started/installation.md) and [test run](docs/getting-started/test-run.md)
- [Running the workflow](docs/user-guide/running.md), [input data](docs/user-guide/input-data.md), [sample table](docs/user-guide/samples-csv.md), [reference genomes](docs/user-guide/reference-genomes.md), [parameters](docs/user-guide/parameters.md), [restarting and merging](docs/user-guide/restarting-and-merging.md)
- [Output files](docs/outputs/output-files.md), [QC reports](docs/outputs/qc-reports.md), [barcode metrics](docs/outputs/barcode-metrics.md)
- [sciMETv3](docs/scimetv3/index.md)
- [Troubleshooting](docs/reference/troubleshooting.md) and [changelog](changelog.md)

The documentation can be built as a website with [MkDocs](https://www.mkdocs.org):

```bash
pip install -r requirements-docs.txt
mkdocs serve          # preview at http://127.0.0.1:8000
```

On GitHub, `.github/workflows/docs.yml` builds the site for pull requests that change the docs and publishes it to GitHub Pages on every push to `main` (set *Settings > Pages > Source* to **GitHub Actions**).

## License
By purchasing product(s) and downloading the software product(s) of ScaleBio, You accept all of the terms of the [License Agreement](LICENSE.md). If You do not agree to these terms and conditions, You may not use or download any of the software product(s) of ScaleBio.
