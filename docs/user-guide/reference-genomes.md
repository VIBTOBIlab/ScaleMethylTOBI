# Reference genomes

The workflow needs a reference genome with an aligner index and annotation. All files and settings for a genome are listed in a `genome.json` file, selected with `--genome /path/to/genome.json`. Example: [genome.json](../examples/genome.json).

## genome.json fields

| Field | Description | Required? | Example |
|---|---|---|---|
| `name` | Name of the species / genome version | Required | `hg38` |
| `speciesName` | Species name | Optional | `Homo sapiens` |
| `bwa_index` | bwa-meth (bwa-mem2) index directory | Required for `aligner: bwa-meth` (default) | `/PATH/TO/bwa-meth` |
| `parabricks_index` | bwa-meth (bwa-mem) index directory for Parabricks | Required for `aligner: parabricks` | `/PATH/TO/parabricks` |
| `bsbolt_index` | BSBolt index directory | Required for `aligner: bsbolt` | `/PATH/TO/bsbolt` |
| `ref_fasta` | Name of the fasta file inside the bwa-meth / Parabricks index directory | Required with `bwa_index` or `parabricks_index` | `hg38.fa` |
| `filter_chrs` | TSV of chromosome labels (e.g. `chrM  mito`) used to filter the deduplicated BAM and count mitochondrial reads | Required | `/PATH/TO/filter_chrs.tsv` |
| `tssWin` | Sorted BED of 200 nt windows centred on TSSs | Required unless `runTssEnrich: false` | `/PATH/TO/tss.bed` |
| `backgroundWin` | Sorted BED of 200 nt background windows 1 kb upstream of TSSs | Required unless `runTssEnrich: false` | `/PATH/TO/background.bed` |
| `genomeTiles` | Sorted BED of genome bins for the CG matrix; overrides `windowTileSizeCG` | Optional | `/PATH/TO/50kbp.bed` |
| `genomeTilesCH` | Sorted BED of genome bins for the CH matrix; overrides `windowTileSizeCH` | Optional | `/PATH/TO/100kbp.bed` |
| `chromSizes` | Chromosome sizes file used to make genome bins; created from the fasta if missing | Optional | `/PATH/TO/chrom.sizes` |
| `genomeWindowBlackList` | BED of regions removed from the genome bins | Optional | `/PATH/TO/blacklist.bed` |

Paths can be:

- absolute (`/path/to/genome`);
- relative to the folder of `genome.json` (`genes/bins.bed`);
- AWS S3 URLs (`s3://path/to/genome`).

Give `genomeWindowBlackList` as an absolute path; it is not resolved relative to `genome.json`.

## Genome bins for the matrices

The CG and CH matrices count methylation in non-overlapping genome bins. By default the bins are made from the chromosome sizes with the sizes set by `windowTileSizeCG` (50 kb) and `windowTileSizeCH` (100 kb); bins that become smaller than `minimumWindowSize` (200 bp) after removing blacklisted regions are dropped. To use your own bins, give BED files in `genomeTiles` / `genomeTilesCH` (the `windowTileSize` parameters are then ignored).

## Building an index

=== "bwa-meth (default)"

    Build with bwa-meth >= 0.2.7 and bwa-mem2 >= 2.2.1:

    ```bash
    bwameth.py index-mem2 {fasta reference}
    ```

=== "Parabricks (GPU)"

    Build with bwa-meth >= 0.2.7 and bwa >= 0.7.19:

    ```bash
    bwameth.py index {fasta reference}
    ```

=== "BSBolt (legacy)"

    Build with BSBolt >= 1.5.0:

    ```bash
    bsbolt Index -G {fasta reference} -DB {database output}
    ```

See the [bwa-meth](https://github.com/brentp/bwa-meth) and [BSBolt](https://bsbolt.readthedocs.io/en/latest/bsb_index/) documentation for more options.

!!! note "Shared bwa-meth indexes"
    `bwameth.py` refuses to align when the `<ref_fasta>.bwameth.c2t` file is newer than its index files (`<ref_fasta>.bwameth.c2t.*`), which can happen after copying an index. Before each alignment the workflow therefore sets the time of the `.c2t` file 2 hours back. Only the owner of a file may set its time, so on an index owned by someone else this step is skipped. The alignment then still works as long as the `.c2t` file is older than all `.c2t.*` files; check with `ls -l --time-style=full-iso /PATH/TO/bwa-meth/`.

## Pre-built genomes

ScaleBio provides pre-built references. Download, unpack, and use e.g. `--genome /PATH/TO/unpacked/folder/genome.json`.

| Genome | bwa-meth (default) | Parabricks (GPU) | BSBolt (legacy) |
|---|---|---|---|
| Human (GRCh38) | [grch38-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38-bwa.tgz) | [grch38-parabricks.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38-parabricks.tgz) | [grch38-bsbolt.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38-bsbolt.tgz) |
| Mouse (mm39) | [mm39-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/mm39-bwa.tgz) | [mm39-parabricks.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/mm39-parabricks.tgz) | [mm39-bsbolt.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/mm39-bsbolt.tgz) |
| Human/mouse barnyard | [grch38_mm39-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38_mm39-bwa.tgz) | [grch38_mm39-parabricks.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38_mm39-parabricks.tgz) | [grch38_mm39-bsbolt.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38_mm39-bsbolt.tgz) |

Samples from different species need separate runs with the matching genome (or a barnyard genome). Leave the other species' samples out of `samples.csv`; their reads are then simply not assigned to any sample.
