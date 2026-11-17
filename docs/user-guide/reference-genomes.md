# Reference genomes

The workflow needs a reference genome with a bwa-meth index and annotation. All files and settings for a genome are listed in a `genome.json` file, selected with `--genome /path/to/genome.json`. Example: [genome.json](../examples/genome.json).

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

## Building an index

Build the index with bwa-meth >= 0.2.7 and bwa-mem2 >= 2.2.1:

```bash
bwameth.py index-mem2 {fasta reference}
```

See the [bwa-meth](https://github.com/brentp/bwa-meth) documentation for more options.

!!! note "Shared bwa-meth indexes"
    `bwameth.py` refuses to align when the `<ref_fasta>.bwameth.c2t` file is newer than its index files (`<ref_fasta>.bwameth.c2t.*`), which can happen after copying an index. Before each alignment the workflow therefore sets the time of the `.c2t` file 2 hours back. Only the owner of a file may set its time, so on an index owned by someone else this step is skipped. The alignment then still works as long as the `.c2t` file is older than all `.c2t.*` files; check with `ls -l --time-style=full-iso /PATH/TO/bwa-meth/`.

## Pre-built genomes

ScaleBio provides pre-built references. Download, unpack, and use e.g. `--genome /PATH/TO/unpacked/folder/genome.json`.

| Genome               | bwa-meth index                                                                                         |
| -------------------- | ------------------------------------------------------------------------------------------------------ |
| Human (GRCh38)       | [grch38-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38-bwa.tgz)           |
| Mouse (mm39)         | [mm39-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/mm39-bwa.tgz)               |
| Human/mouse barnyard | [grch38_mm39-bwa.tgz](https://s3.us-east-2.amazonaws.com/scale.pub/genomes/methyl/grch38_mm39-bwa.tgz) |

Samples from different species need separate runs with the matching genome (or a barnyard genome). Leave the other species' samples out of `samples.csv`; their reads are then simply not assigned to any sample.
