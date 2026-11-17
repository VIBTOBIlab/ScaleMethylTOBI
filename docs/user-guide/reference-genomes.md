# Reference genomes

The workflow needs a reference genome with a bwa-meth index and annotation, given in one of two ways:

| Parameter       | Use                                                                                                    |
| --------------- | ------------------------------------------------------------------------------------------------------ |
| `--genome`      | A pre-built genome by name: `hg38` or `mm39`. The workflow downloads and unpacks it.                   |
| `--genome_json` | Your own `genome.json`, listing the bwa-meth index and annotation files of a genome you already have. |

## Pre-built genomes (`--genome`)

| `--genome` | Genome               | Archive (ScaleBio)                                                                           |
| ---------- | -------------------- | -------------------------------------------------------------------------------------------- |
| `hg38`     | Human GRCh38         | [grch38-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38-bwa.tgz) |
| `mm39`     | Mouse GRCm39 (mm39)  | [mm39-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/mm39-bwa.tgz)     |

```bash
nextflow run /PATH/TO/ScaleMethyl -profile docker --input samples.csv --genome hg38 --outdir out
```

The genomes are defined in `conf/genomes.config`. Each is a `.tgz` archive (16-18 GB) with the bwa-meth index, the annotation files and a `genome.json` that lists them. The workflow streams the archive from `--genomes_base` (default: the ScaleBio AWS S3 bucket) and unpacks it:

- The genome is unpacked into the work folder of the run (it takes more space than the archive). With `-resume` it is reused; a new run downloads it again. To avoid repeated downloads of a genome you use often, unpack it once and use its `genome.json` with `--genome_json`.
- On a cluster without internet access, copy the archives to a folder and point `--genomes_base` to it (an `https://` URL or a local folder).
- To add a genome, add an entry with its archive to `conf/genomes.config` (in your own config file, `params.genomes`), or unpack it and use `--genome_json`.

The human/mouse barnyard genome ([grch38_mm39-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38_mm39-bwa.tgz)) is not included by name: unpack it and use its `genome.json` with `--genome_json`. Samples from different species need separate runs with the matching genome (or a barnyard genome). Leave the other species' samples out of `samples.csv`; their reads are then simply not assigned to any sample.

## Your own genome (`--genome_json`)

`genome.json` lists all files of a genome. Example: [genome.json](../examples/genome.json), with paths relative to the folder of `genome.json`. An unpacked pre-built genome archive contains one as well.

## genome.json fields

| Field                   | Description                                                                                                    | Required?                               | Example                    |
| ----------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------- | -------------------------- |
| `name`                  | Name of the species / genome version                                                                           | Required                                | `hg38`                     |
| `speciesName`           | Species name                                                                                                   | Optional                                | `Homo sapiens`             |
| `bwa_index`             | bwa-meth (bwa-mem2) index directory                                                                            | Required                                | `/PATH/TO/bwa-meth`        |
| `ref_fasta`             | Name of the fasta file inside the bwa-meth index directory                                                     | Required                                | `hg38.fa`                  |
| `filter_chrs`           | TSV of chromosome labels (e.g. `chrM  mito`) used to filter the deduplicated BAM and count mitochondrial reads | Required                                | `/PATH/TO/filter_chrs.tsv` |
| `tssWin`                | Sorted BED of 200 nt windows centred on TSSs                                                                   | Required unless `run_tss_enrich: false` | `/PATH/TO/tss.bed`         |
| `backgroundWin`         | Sorted BED of 200 nt background windows 1 kb upstream of TSSs                                                  | Required unless `run_tss_enrich: false` | `/PATH/TO/background.bed`  |
| `genomeTiles`           | Sorted BED of genome bins for the CG matrix; overrides `window_tile_size_cg`                                   | Optional                                | `/PATH/TO/50kbp.bed`       |
| `genomeTilesCH`         | Sorted BED of genome bins for the CH matrix; overrides `window_tile_size_ch`                                   | Optional                                | `/PATH/TO/100kbp.bed`      |
| `chromSizes`            | Chromosome sizes file used to make genome bins; created from the fasta if missing                              | Optional                                | `/PATH/TO/chrom.sizes`     |
| `genomeWindowBlackList` | BED of regions removed from the genome bins                                                                    | Optional                                | `/PATH/TO/blacklist.bed`   |

Paths can be:

- absolute (`/path/to/genome`);
- relative to the folder of `genome.json` (`genes/bins.bed`);
- AWS S3 URLs (`s3://path/to/genome`).

Empty entries (`""`) are treated as not set. Older `genome.json` files may still contain `bsbolt_index` or `parabricks_index`; these entries are ignored.

## Genome bins for the matrices

The CG and CH matrices count methylation in non-overlapping genome bins. By default the bins are made from the chromosome sizes with the sizes set by `window_tile_size_cg` (50 kb) and `window_tile_size_ch` (100 kb); bins that become smaller than `minimum_window_size` (200 bp) after removing blacklisted regions are dropped. To use your own bins, give BED files in `genomeTiles` / `genomeTilesCH` (the `window_tile_size_*` parameters are then ignored).

## The bwa-meth index

`bwa_index` in `genome.json` is the directory with the reference fasta (`ref_fasta`) and its `<fasta>.bwameth.c2t*` index files. To build an index, use bwa-meth >= 0.2.7 and bwa-mem2 >= 2.2.1:

```bash
bwameth.py index-mem2 {fasta reference}
```

See the [bwa-meth](https://github.com/brentp/bwa-meth) documentation for more options.

!!! note "Shared bwa-meth indexes"
    `bwameth.py` refuses to align when the `<ref_fasta>.bwameth.c2t` file is newer than its index files (`<ref_fasta>.bwameth.c2t.*`), which can happen after copying an index. Before each alignment the workflow therefore sets the time of the `.c2t` file 2 hours back. Only the owner of a file may set its time, so on an index owned by someone else this step is skipped. The alignment then still works as long as the `.c2t` file is older than all `.c2t.*` files; check with `ls -l --time-style=full-iso /PATH/TO/bwa-meth/`.
