# Test run

## Built-in test profile

The repository contains a tiny synthetic dataset (`tests/data/`, 12 cells in two samples). The `test` profile runs the whole workflow on it in a few minutes, without downloading anything:

```bash
nextflow run /PATH/TO/ScaleMethyl -profile test,docker --outdir test_results
```

The same run is the pipeline test of the repository (`nf-test test --profile +docker`, see `tests/README.md`).

## PBMC example data

A small test dataset (downsampled PBMCs, ScaleBio kit v1.1) is stored online. Use it to check that the workflow and its dependencies work on your system:

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker \
    -params-file /PATH/TO/ScaleMethyl/docs/examples/runParams.yml \
    --outdir ScaleMethyl.out
```

Replace `docker` with the profile for your system (see [Installation](installation.md)). Nextflow downloads the example data and the hg38 genome (an 18 GB archive) from AWS S3, so the compute nodes need internet access and enough storage space.

Alternatively, download the data first with the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html):

```bash
aws s3 sync s3://scale.pub/testData/methylation/downsampled_pbmcs_v1.1/ fastqs --no-sign-request
aws s3 cp s3://scale.pub/genomes/methyl/grch38-bwa.tgz genomes/ --no-sign-request
```

point the samplesheet at the local copies, and run with them:

```bash
sed 's#s3://scale.pub/testData/methylation/downsampled_pbmcs_v1.1/#fastqs/#' \
    /PATH/TO/ScaleMethyl/docs/examples/samples.csv > samples.csv
nextflow run /PATH/TO/ScaleMethyl -profile docker \
    --input samples.csv --genome hg38 --genomes_base $PWD/genomes --min_uniq_count 1000 --outdir ScaleMethyl.out
```

The test only checks that the workflow runs; it is not a complete dataset.

The example files used by the test are in the repository under `docs/examples/`: [runParams.yml](../examples/runParams.yml) and [samples.csv](../examples/samples.csv).

## Next: your own data

1. Download or build a [reference genome](../user-guide/reference-genomes.md).
2. Write a [sample table](../user-guide/samples-csv.md) (`samples.csv`).
3. Write a `runParams.yml` with your inputs and options ([Parameters](../user-guide/parameters.md)).
4. Launch the workflow ([Running the workflow](../user-guide/running.md)).

For sciMETv3 libraries, read the [sciMETv3 section](../scimetv3/index.md) first.
