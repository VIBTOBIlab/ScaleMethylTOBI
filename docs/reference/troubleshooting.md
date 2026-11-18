# Troubleshooting

## Input and samples

**`No fastq files (fastq_1, fastq_2, index_1, index_2 columns) in samples.csv for library: X`**
: Every library (`libName`) needs its fastq files in the fastq columns of at least one row of the samplesheet ([Fastq files](../user-guide/samples-csv.md#fastq-files)).

**`File in the samplesheet ... not found`**
: Relative fastq paths are resolved relative to the folder of the samplesheet, not the launch folder. Use absolute paths or paths relative to the samplesheet.

**One sample gets most of the reads; other samples only one Tn5 well each**
: The Tn5 ranges in samples.csv overlap. Ranges are read row by row, so `1A01-1G01` is 73 wells, not column 1, and each overlapping well goes to the last sample listing it. List column-wise wells individually ([Sample table](../user-guide/samples-csv.md#specifying-tn5-wells)).

**`bc_parser` fails for some fastq sets**
: bcl-convert writes (empty) fastq files for every barcode in its samplesheet. Do not list the empty sets, or restrict the PCR wells to those you sequenced with `libIndex` / `libIndex2` when writing the bcl-convert samplesheet with `bin/bcl_convert_sheet.py`.

## Barcode metrics

**Pass rate near 0%, one barcode with about 100% NoMatch**
: The library structure does not fit the library: wrong barcode list, wrong orientation, or different primers (for example `sciMETv3/lib.json` used for a library made with D501-D508 i5 primers). Check the reads with `check_barcode_orientation.py` ([sciMETv3 QC](../scimetv3/quality-control.md#checking-barcodes-before-a-run)).

**Pass rate around 80% instead of about 98%**
: Usually not a problem: the input was a whole lane including PhiX and reads with unreadable index barcodes, which bcl-convert would otherwise have removed. See [Barcode metrics](../outputs/barcode-metrics.md#interpreting-the-numbers).

## Alignment

**`touch: setting times of '.../<ref>.bwameth.c2t': Operation not permitted`**
: The bwa-meth index belongs to another user. Only the owner of a file may set its time. In this copy of the workflow the failing `touch` is ignored; the alignment works as long as the `.c2t` file is older than its `.c2t.*` index files (see [Reference genomes](../user-guide/reference-genomes.md#building-an-index)).

**`first run bwameth.py index`**
: The `.c2t` file of the bwa-meth index is newer than its index files. Ask the index owner to run `touch <ref>.bwameth.c2t.*` in the index folder, or copy the index folder, run `touch -d "$(date -R -r <ref>.bwameth.c2t) - 2 hours" -m <ref>.bwameth.c2t` in your copy, and point `bwa_index` in genome.json to it.

## Containers and HPC

**File not found inside the container, for inputs given as symbolic links**
: Singularity must be able to see the folder the links point to. Add it to the bind paths in your config, e.g. `singularity.runOptions = '... -B /path/to/original/fastq'` (keep the options already set by the `singularity` profile in `nextflow.config`).

**`INFO: Environment variable SINGULARITYENV_... is set, but APPTAINERENV_... is preferred`**
: Harmless message from Apptainer.

**Trimming and alignment start before `MergeDemux` has finished**
: Expected. `MergeDemux` only merges barcode statistics for the report; trimming uses the demultiplexed fastq files directly.

## Downstream analysis

**Amethyst `createScaleObject` cannot find `genome_bin_matrix/<sample>.CG.features.tsv`**
: The folder passed to `createScaleObject` has no matrix files, e.g. a renamed copy made with an older version of `rename_amethyst_cells.py`. Link them from the original run ([Combining libraries](../scimetv3/combining-libraries.md#loading-into-amethyst)).

**Identical cell IDs in two libraries**
: Expected when libraries share barcodes; they are different cells. Prefix the cell names before combining ([Combining libraries](../scimetv3/combining-libraries.md)).
