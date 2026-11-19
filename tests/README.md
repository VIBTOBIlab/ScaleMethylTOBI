# Tests

The tests use [nf-test](https://www.nf-test.com/) and a tiny synthetic dataset in `tests/data/`:

- `tests/default.nf.test`: the whole pipeline with `-profile test`; the snapshot holds every output path and the content of the reproducible outputs. A second test selects the genome by name (`--genome hg38`, with `--genomes_base` pointing to `data/genomes/`, the synthetic test genome packed like the ScaleBio genome archives) and checks that the same cells are found.
- `tests/options.nf.test`: the whole pipeline with non-default inputs and options:
  - `samples_multi.csv` with `--split_fastq false`: two libraries (`ScaleMethyl`, `LibB`), two sequencing runs of `ScaleMethyl` (`data/fastq/run2/` links to the same fastq files), `split=true` for one sample only, and a sample without passing cells (`threshold` above any cell). Checks the bc_parser folder of each fastq set, the reads of both runs in the library metrics, which samples are split by Tn5 well, and the report without matrix of the sample without cells.
  - `--skip_ch_context --skip_tss_enrich --skip_window_matrix --skip_cell_prefix`: no CH, matrix or TSS outputs, barcodes as cell names, and empty CH columns in `allCells.csv`.
- `modules/local/<module>/tests/main.nf.test`: tests of single modules

nf-test, Nextflow and nf-core/tools are pinned in `dev-environment.yml` (`conda env create -f dev-environment.yml`).

## Running

From the repository root, with Docker running:

```bash
nf-test test --profile +docker                 # all tests
nf-test test --profile +docker --tag modules   # module tests only (fast)
nf-test test --profile +docker --tag pipeline  # whole workflow
```

`nf-test.config` always adds the `test` profile (`conf/test.config`); `+docker` adds a container engine. Use `+singularity` on an HPC.

The whole workflow can also be run directly on the test data:

```bash
nextflow run . -profile test,docker --outdir results
```

## Snapshots

Tests compare outputs with the stored snapshots (`*.nf.test.snap`). After an intended change in the output, update them with

```bash
nf-test test --profile +docker --update-snapshot
```

and commit the changed `.snap` files together with the code change.

The pipeline snapshot (`tests/default.nf.test.snap`) has two entries:

- `-profile test`: the path of every published file (except `pipeline_info/`), the md5 of the sorted lines of the text and gzipped outputs (cells are written in a different order on each run), the header line of the `.mtx.gz` matrices and, for `report_clusters.tsv`, only the cell IDs (the cluster labels of the random synthetic cells change between runs). HTML, PNG, parquet, h5, tbi, `workflow_info.json`, the cutadapt reports (`.trim_log`) and the MultiQC files are only checked by name.
- `software_versions`: `pipeline_info/scalemethyltobi_software_versions.yml` without the Nextflow version. It changes with the pipeline version and the container.

## Test data

| Path                          | Content                                                                                                                        |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `data/samples.csv`            | Samplesheet: two samples, Tn5 wells 1A01-1A03 and 1A07-1A09, with the fastq files (paths relative to the samplesheet)          |
| `data/fastq/`                 | 3,690 read pairs in the ScaleBio v1.1 layout (`references/lib.json`): 12 cells with 300 reads each plus 30 background barcodes |
| `data/genome/`                | Random 72 kb genome (chr1, chr2, chrM), bwa-meth index, TSS and background windows                                             |
| `data/genomes/grch38-bwa.tgz` | `data/genome/` packed like the ScaleBio genome archives, for the `--genome` test                                               |

The reads are bisulfite converted (CpG methylated with probability 0.8, CH unmethylated), so CpG methylation should come out near 80% and CH methylation near 0%.

`make_test_data.py` writes the fastq and genome files; the output is fixed by its random seed. After regenerating the genome, rebuild the bwa-meth index with the workflow's container:

```bash
python3 tests/data/make_test_data.py
mkdir -p tests/data/genome/bwa_meth
cp tests/data/genome/genome.fa tests/data/genome/bwa_meth/
docker run --rm -v "$PWD/tests/data/genome/bwa_meth":/idx -w /idx \
    public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106 \
    bwameth.py index-mem2 genome.fa
COPYFILE_DISABLE=1 tar -czf tests/data/genomes/grch38-bwa.tgz -C tests/data genome
```
