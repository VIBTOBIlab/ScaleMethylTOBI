# Test run

A small test dataset (downsampled PBMCs, ScaleBio kit v1.1) is stored online. Use it to check that the workflow and its dependencies work on your system:

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker \
    -params-file /PATH/TO/ScaleMethyl/docs/examples/runParams.yml \
    --outDir ScaleMethyl.out
```

Replace `docker` with the profile for your system (see [Installation](installation.md)). Nextflow downloads the example data from AWS S3, so the compute nodes need internet access and some storage space.

Alternatively, download the data first with the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html):

```bash
aws s3 sync s3://scale.pub/testData/methylation/reference/ reference --no-sign-request
aws s3 sync s3://scale.pub/testData/methylation/downsampled_pbmcs_v1.1/ fastqs --no-sign-request
```

and run with the local copies:

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker \
    -params-file /PATH/TO/ScaleMethyl/docs/examples/runParams.yml \
    --genome reference/genome.json --fastqDir fastqs --outDir ScaleMethyl.out
```

The test only checks that the workflow runs; it is not a complete dataset.

The example files used by the test are in the repository under `docs/examples/`: [runParams.yml](../examples/runParams.yml), [samples.csv](../examples/samples.csv) and [genome.json](../examples/genome.json).

## Next: your own data

1. Download or build a [reference genome](../user-guide/reference-genomes.md).
2. Write a [sample table](../user-guide/samples-csv.md) (`samples.csv`).
3. Write a `runParams.yml` with your inputs and options ([Parameters](../user-guide/parameters.md)).
4. Launch the workflow ([Running the workflow](../user-guide/running.md)).

For sciMETv3 libraries, read the [sciMETv3 section](../scimetv3/index.md) first.
