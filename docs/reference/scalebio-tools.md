# ScaleBio tools

Besides open-source software, the workflow uses two executables developed by ScaleBio. They are included in the container image; for installation without containers see [Installation](../getting-started/installation.md#scalebio-tools).

## bc_parser

`bc_parser` handles combinatorial barcodes: it finds the barcodes in the reads, corrects sequencing errors and demultiplexes the reads by sample. Run `bc_parser --help` for all options.

### Inputs

- Fastq files: `--reads` (all files of a set, e.g. `--reads S1*.fastq.gz` for bcl-convert names with `_R1`, `_R2`, `_I1`, `_I2`) or `--read1 --read2 ...`. Index-read fastq files are needed when the library has barcodes in the index reads.
- Library structure (`--lib-struct`), defining the position and allowed sequences of every barcode ([Library structure](library-structure.md)).
- Sample table (`--demux`), assigning sample barcodes to samples.

### Outputs

- Fastq files per sample (`--write-fastq`) with the corrected barcodes in the read names, joined with `+` in the order of the library structure (e.g. `i7+i5+tgmt`). With `split_fastq: true` the files are also split by sample barcode (Tn5 well), plus one set (`_S0_`) for reads not assigned to any sample.
- `metrics.json` with read- and barcode-level statistics ([Barcode metrics](../outputs/barcode-metrics.md)).
- `barcode_counts.<barcode>.tsv` with the reads per barcode sequence.

## sc_dedup

`sc_dedup` removes duplicate reads from a coordinate-sorted BAM file. It is barcode-aware: reads with different cell barcodes are never duplicates of each other. Run `sc_dedup --help` for all options.

As used in the workflow (`--duplicate-key Leftmost`, parameter `dedup_key`), `sc_dedup` takes the leftmost aligned position of a read pair and compares it to the reads seen before with the same barcode. For single reads, and pairs with one unmapped mate, the position of the mapped read is used. After the first read at a position, later reads starting there are discarded as duplicates. Reads below `min_mapq` (default 10) are removed.

### Inputs

- A coordinate-sorted BAM file with the cell barcodes in the read names.
- `--genome <genome.tsv>`: chromosome labels (the `filter_chrs` file of the [genome](../user-guide/reference-genomes.md)). Include the line `chrM    mito` to get correct mitochondrial and unique read counts.

### Outputs

Per sample and Tn5 well, in `alignments/dedup/<sample>.<well>/`:

| File                                | Description                                                          |
| ----------------------------------- | -------------------------------------------------------------------- |
| `<sample>.<well>.dedup.bam`         | Reads that are not duplicates (published with `bam_dedup_out: true`) |
| `<sample>.<well>.cell_stats.tsv`    | Read metrics per cell barcode                                        |
| `<sample>.<well>.dedup_stats.tsv`   | Summary statistics of the deduplicated reads                         |
| `<sample>.<well>.fragment_hist.tsv` | Fragment length histogram                                            |
