# Running sciMETv3

## Parameters

```yaml
fastq_dir: /full/path/to/fastqs # or run_folder: /path/to/illumina/run
input: samples.csv
genome: /path/to/genome.json
lib_structure: "sciMETv3/lib.json" # or "sciMETv3/lib_D50x.json"
outdir: sciMETv3.out
```

The `references/sciMETv3/` folder must be present in the copy of the workflow you run, because `lib_structure` is resolved relative to `references/`. Alternatively give the full path to the `.json` file.

Both index reads must be sequenced with at least 10 cycles.

## Sample table

Samples are defined by their Tn5 wells, as for the ScaleBio kit ([Sample table](../user-guide/samples-csv.md)):

```csv
sample,barcodes,libName
DonorA,1A01-1D12,sciMETv3
DonorB,1E01-1H12,sciMETv3
```

If samples were loaded into the Tn5 plate by column, list every well: a range such as `1A01-1G01` is read row by row and covers 73 wells, not column 1.

```csv
sample,barcodes,libName
DonorA,1A01;1B01;1C01;1D01;1E01;1F01;1G01,sciMETv3
DonorB,1A02;1B02;1C02;1D02;1E02;1F02;1G02,sciMETv3
```

## Several libraries with the same barcodes

A cell is identified only by its barcode sequences. When separate PCR libraries were made with the same i5 primers (for example two PCR strips with D501-D508, sequenced on two lanes), the same barcode combinations occur in both, but they belong to different nuclei. Analysed as one library, cells with identical barcodes from the two libraries would be merged into one; at about 750 nuclei per PCR well and 96 Tn5 barcodes that affects roughly 8% of cells.

Give each library its own `libName`, and list each sample once per library with a unique name:

```csv
sample,barcodes,libName
DonorA-strip1,1A01;1B01;1C01;1D01;1E01;1F01;1G01,strip1
DonorB-strip1,1A02;1B02;1C02;1D02;1E02;1F02;1G02,strip1
DonorA-strip2,1A01;1B01;1C01;1D01;1E01;1F01;1G01,strip2
DonorB-strip2,1A02;1B02;1C02;1D02;1E02;1F02;1G02,strip2
```

The fastq files of each library must start with its `libName` (`strip1_...`, `strip2_...`); see [Renaming files](../user-guide/input-data.md#renaming-files). In the run you then see one demultiplexing job per library (`BarcodeDemux (strip1)`, `BarcodeDemux (strip2)`) and separate reports per sample and library. To analyse the libraries together afterwards, see [Combining libraries](combining-libraries.md).

If the libraries used different i5 primers, the i5 barcode already tells them apart and they can share one `libName`.

## Starting from fastq files

Facility fastq files can be used directly, also when a whole lane (including PhiX) was delivered as one set of files. Requirements ([Input data](../user-guide/input-data.md#starting-from-fastq-files)):

- R1, R2, I1 and I2 files for each set;
- full-length index reads (10 bp; check that the facility did not mask or shorten them);
- file names starting with the `libName`.

No index demultiplexing is needed beforehand: `bc_parser` matches all three barcodes, and reads without them (PhiX, empty clusters) are discarded.

`bc_parser` writes one pair of fastq files per Tn5 well of each sample, plus one pair (`_S0_`) for reads that are not assigned to any sample. With one fully used Tn5 plate that is 97 pairs per demultiplexing job.

## Starting from a run folder

### bcl-convert samplesheet

bcl-convert only uses the index reads, so it sees the ligation and PCR barcodes but not the Tn5 barcode. The samplesheet lists every PCR well you sequenced together with all 96 ligation barcodes, i.e. 96 rows per PCR well:

```text
Sample_ID,index,index2
sciMETv3_A01,GTCTTAACGT,TCATACCGCT
sciMETv3_A01,GGTTGGATAG,TCATACCGCT
...
sciMETv3_A02,GTCTTAACGT,TGCCGCCGAT
```

All 96 rows of a PCR well share one `Sample_ID`, so bcl-convert writes one set of fastq files per PCR well. The index reads are kept in the `I1` / `I2` files (`CreateFastqForIndexReads,1`), so every read keeps its own barcodes; the Tn5 barcode is read later by `bc_parser`. Reads with an unknown Index 1 go to `Undetermined`.

With `run_folder`, the workflow builds this samplesheet from samples.csv and `RunInfo.xml` and publishes it to `outdir/fastq/samplesheet.csv`. Use `libIndex2` in samples.csv to list only the PCR wells you sequenced (sequences from `pcr_i5.txt`); otherwise bcl-convert writes a set of (empty) fastq files for every i5 in the list, and empty sets can make `bc_parser` fail. Leave `libIndex` empty to use all 96 ligation barcodes.

```csv
sample,barcodes,libName,libIndex2
DonorA,1A01-1D12,sciMETv3,AGCGGTATGA;ATCGGCGGCA
DonorB,1E01-1H12,sciMETv3,AGCGGTATGA;ATCGGCGGCA
```

`references/sciMETv3/example_bclconvert_samplesheet.csv` is an example for PCR wells A01 and A02, 151/10/10/151 cycles, on an instrument whose `RunInfo.xml` marks Index 2 as reverse complement (NextSeq 1000/2000, NovaSeq X). On those instruments `index2` is the i5 as written in the primer and bcl-convert reverse-complements it; on a NovaSeq 6000, `index2` must be the sequence from `pcr_i5.txt`.

When running bcl-convert outside the workflow, the `Sample_ID` must start with the `libName` followed by `_`; then start the workflow with `--fastq_dir`. Libraries that share all index combinations can only be separated by lane (a `Lane` column in the samplesheet).

## Enzymatic conversion on Illumina

The paper reports that enzymatic (EM-seq) conversion over-converts bases of the Read 2 / Index 1 primer region that is added by ligation, which lowers the fraction of clusters passing filter on Illumina instruments. This is a library chemistry issue, not something the workflow can correct.
