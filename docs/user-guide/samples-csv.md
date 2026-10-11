# Sample table (samples.csv)

The sample table lists the samples in an analysis, their sample barcodes (Tn5 wells) and optional per-sample settings. It is a comma-separated file with a header line and one sample per line. Example: [samples.csv](../examples/samples.csv).

```csv
sample,barcodes,libName
PBMC-S1,1A01-2D12,ScaleMethyl
PBMC-S2,2E01-3H12,ScaleMethyl
```

## Columns

The first column must be `sample`; all others are optional. Column names are case-sensitive.

| Column | Description | Example | Default |
|---|---|---|---|
| `sample` | Sample name | `Foobar-2` | |
| `barcodes` | Tn5 wells used for this sample | `1A01-1H12;2A01-2D12` | all wells in the Tn5 barcode list (`1A01-3H12`) |
| `libName` | Name of the sequencing library / fastq files | `ScaleMethyl` | `ScaleMethyl` |
| `libIndex` | Subset of Index 1 (i7) sequences used, separated by `;` | `TTGATATGAA;CCTAAGCGGT` | all sequences in the i7 list |
| `libIndex2` | Subset of Index 2 (i5) sequences used, separated by `;` | `TATCATGATC;GAGCATATGG` | all sequences in the i5 list |
| `threshold` | Unique reads above which a barcode is called a cell | `1000` | calculated, see [cell calling](parameters.md#cell-calling) |
| `split` | Split this sample by Tn5 well for parallel processing | `true` | value of `splitFastq` |

- `sample` and `libName` may contain only letters, numbers and dashes (`-`), and should start with a letter.
- `libIndex` / `libIndex2` are only used to build the bcl-convert samplesheet when starting from a run folder. Give the sequences as they appear in the barcode lists of the library structure.

## libName: one per library

`libName` names a sequencing library, i.e. one set of fastq files, not a sample. All samples in the same library share the same `libName`. Do not give each sample its own `libName`: the workflow would then look for fastq files named after each sample.

When starting from fastq files, `libName` must match the first part of the file names (`ScaleMethyl` for `ScaleMethyl_*.fastq.gz`).

Several libraries can be analysed in one run by giving them different `libName`s. This is required when libraries share the same barcodes, e.g. two PCR libraries made with the same index primers: a cell is identified only by its barcode sequences, so within one `libName` cells with identical barcodes from different libraries would be merged. List each sample once per library, with a unique name:

```csv
sample,barcodes,libName
DonorA-lib1,1A01-1D12,lib1
DonorB-lib1,1E01-1H12,lib1
DonorA-lib2,1A01-1D12,lib2
DonorB-lib2,1E01-1H12,lib2
```

## Specifying Tn5 wells

During analysis, reads are first assigned to libraries (fastq files) and then to samples by their Tn5 barcode. The Tn5 wells of each sample are given in `barcodes` as:

- a single well: `1A01` (plate 1, row A, column 1). Plates range from 1-3, rows from A-H and columns from 1-12 (288 wells);
- a range: `1A01-3H12`;
- a list of wells and/or ranges, separated by `;`: `1A01;1A02-1H02`.

!!! warning "Ranges are read row by row"
    Ranges run first by plate, then **row by row**: `1A01-1B12` is rows A and B of plate 1, and `1A01-2D12` is all of plate 1 plus rows A-D of plate 2. A range such as `1A01-1G01` therefore covers 73 wells (rows A-F completely, plus 1G01), **not** column 1.

    If samples were loaded by column, list every well: `1A01;1B01;1C01;1D01;1E01;1F01;1G01`.

!!! danger "Overlapping wells are not reported"
    The workflow does not stop when two samples list the same well. Each such well goes to the **last** sample in the table that lists it. Check that every well appears for only one sample; the library report shows the reads per sample.

### Examples

| sample | barcodes | Meaning |
|---|---|---|
| One | `1A01-2D12` | Tn5 plate 1 and the first half of plate 2, row-wise |
| Two | `2E01-2H12` | Second half of plate 2, from row E |
| Three | `3A01-3A06;3B01-3B06;3C01-3C06;3D01-3D06;3E01-3E06;3F01-3F06;3G01-3G06;3H01-3H06` | Plate 3, columns 1-6 |
| Four | `3A07-3A12;3B07-3B12;3C07-3C12;3D07-3D12;3E07-3E12;3F07-3F12;3G07-3G12;3H07-3H12` | Plate 3, columns 7-12 |
| Five | `1A05;1B05;1C05;1D05;1E05;1F05;1G05` | Plate 1, column 5, rows A-G |
