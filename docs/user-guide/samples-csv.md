# Samplesheet (samples.csv)

The samplesheet (`--input`) lists the samples in an analysis, their sample barcodes (Tn5 wells), the fastq files of their sequencing libraries and optional per-sample settings. It is a comma-separated file with a header line. Example: [samples.csv](../examples/samples.csv).

```csv
sample,barcodes,libName,fastq_1,fastq_2,index_1,index_2
PBMC-S1,1A01-2D12,ScaleMethyl,fastq/ScaleMethyl_S1_R1_001.fastq.gz,fastq/ScaleMethyl_S1_R2_001.fastq.gz,fastq/ScaleMethyl_S1_I1_001.fastq.gz,fastq/ScaleMethyl_S1_I2_001.fastq.gz
PBMC-S2,2E01-3H12,ScaleMethyl,fastq/ScaleMethyl_S1_R1_001.fastq.gz,fastq/ScaleMethyl_S1_R2_001.fastq.gz,fastq/ScaleMethyl_S1_I1_001.fastq.gz,fastq/ScaleMethyl_S1_I2_001.fastq.gz
```

The samplesheet is validated against [assets/schema_input.json](https://github.com/VIBTOBIlab/ScaleMethylTOBI/blob/main/assets/schema_input.json) before the run starts.

## Columns

Column names are case-sensitive.

| Column      | Description                                                                 | Example                  | Default                                                    |
| ----------- | --------------------------------------------------------------------------- | ------------------------ | ---------------------------------------------------------- |
| `sample`    | Sample name                                                                 | `Foobar-2`               | required                                                   |
| `libName`   | Name of the sequencing library                                              | `ScaleMethyl`            | required                                                   |
| `barcodes`  | Tn5 wells used for this sample                                              | `1A01-1H12;2A01-2D12`    | all wells in the Tn5 barcode list (`1A01-3H12`)            |
| `fastq_1`   | Read 1 fastq file of the library                                            | `run1/Lib_R1_001.fastq.gz` | see [Fastq files](#fastq-files)                          |
| `fastq_2`   | Read 2 fastq file (Tn5 barcode and genomic read)                            | `run1/Lib_R2_001.fastq.gz` |                                                          |
| `index_1`   | Index 1 (i7) fastq file                                                     | `run1/Lib_I1_001.fastq.gz` |                                                          |
| `index_2`   | Index 2 (i5) fastq file                                                     | `run1/Lib_I2_001.fastq.gz` |                                                          |
| `threshold` | Unique reads above which a barcode is called a cell                         | `1000`                   | calculated, see [cell calling](parameters.md#cell-calling) |
| `split`     | Split this sample by Tn5 well for parallel processing                       | `true`                   | value of `split_fastq`                                     |
| `resultDir` | Output folder of a previous run, see [merging runs](restarting-and-merging.md) | `run1.out`            |                                                            |

- `sample` and `libName` may contain only letters, numbers and dashes (`-`), and should start with a letter.
- `libIndex` / `libIndex2` (subsets of the i7 / i5 sequences) are only used by the bcl-convert samplesheet helper, see [Input data](input-data.md#generating-fastq-files).

## Fastq files

The fastq columns give the fastq files of a **library** (one sequencing run of it), not of a sample: all samples of a library are in the same files and are separated by their Tn5 barcodes.

- Give the fastq files in at least one row of each library. Rows of the same library with the same files are combined, so the files can be repeated on every row (as in the example above) or given only once.
- `fastq_1`, `fastq_2` and `index_1` are required together; `index_2` is needed by all included [library structures](../reference/library-structure.md).
- Paths can be absolute, URLs (`s3://...`), or relative to the folder of the samplesheet.
- The file names do not matter.

### Several sequencing runs

To combine several sequencing runs (or lanes, or chunks) of the same library, add a row with the fastq files of each run. A sample is listed once per run; its other columns must be the same in every row:

```csv
sample,barcodes,libName,fastq_1,fastq_2,index_1,index_2
PBMC-S1,1A01-2D12,ScaleMethyl,run1/Lib_R1.fastq.gz,run1/Lib_R2.fastq.gz,run1/Lib_I1.fastq.gz,run1/Lib_I2.fastq.gz
PBMC-S2,2E01-3H12,ScaleMethyl,run1/Lib_R1.fastq.gz,run1/Lib_R2.fastq.gz,run1/Lib_I1.fastq.gz,run1/Lib_I2.fastq.gz
PBMC-S1,1A01-2D12,ScaleMethyl,run2/Lib_R1.fastq.gz,run2/Lib_R2.fastq.gz,run2/Lib_I1.fastq.gz,run2/Lib_I2.fastq.gz
```

Each run of a library is demultiplexed on its own (one `bc_parser` job per set of fastq files); the reads of all runs are then combined per sample and Tn5 well before trimming, and deduplicated together. The runs may have identical file names.

## libName: one per library

`libName` names a sequencing library, not a sample. All samples in the same library share the same `libName`. Several libraries can be analysed in one run by giving them different `libName`s. This is required when libraries share the same barcodes, e.g. two PCR libraries made with the same index primers: a cell is identified only by its barcode sequences, so within one `libName` cells with identical barcodes from different libraries would be merged. List each sample once per library, with a unique name:

```csv
sample,barcodes,libName,fastq_1,fastq_2,index_1,index_2
DonorA-lib1,1A01-1D12,lib1,lib1_R1.fastq.gz,lib1_R2.fastq.gz,lib1_I1.fastq.gz,lib1_I2.fastq.gz
DonorB-lib1,1E01-1H12,lib1,lib1_R1.fastq.gz,lib1_R2.fastq.gz,lib1_I1.fastq.gz,lib1_I2.fastq.gz
DonorA-lib2,1A01-1D12,lib2,lib2_R1.fastq.gz,lib2_R2.fastq.gz,lib2_I1.fastq.gz,lib2_I2.fastq.gz
DonorB-lib2,1E01-1H12,lib2,lib2_R1.fastq.gz,lib2_R2.fastq.gz,lib2_I1.fastq.gz,lib2_I2.fastq.gz
```

## Specifying Tn5 wells

During analysis, the reads of each library are assigned to samples by their Tn5 barcode. The Tn5 wells of each sample are given in `barcodes` as:

- a single well: `1A01` (plate 1, row A, column 1). Plates range from 1-3, rows from A-H and columns from 1-12 (288 wells);
- a range: `1A01-3H12`;
- a list of wells and/or ranges, separated by `;`: `1A01;1A02-1H02`.

!!! warning "Ranges are read row by row"
    Ranges run first by plate, then **row by row**: `1A01-1B12` is rows A and B of plate 1, and `1A01-2D12` is all of plate 1 plus rows A-D of plate 2. A range such as `1A01-1G01` therefore covers 73 wells (rows A-F completely, plus 1G01), **not** column 1.

    If samples were loaded by column, list every well: `1A01;1B01;1C01;1D01;1E01;1F01;1G01`.

!!! danger "Overlapping wells are not reported"
    The workflow does not stop when two samples list the same well. Each such well goes to the **last** sample in the table that lists it. Check that every well appears for only one sample; the library report shows the reads per sample.

### Examples

| sample | barcodes                                                                          | Meaning                                             |
| ------ | --------------------------------------------------------------------------------- | --------------------------------------------------- |
| One    | `1A01-2D12`                                                                       | Tn5 plate 1 and the first half of plate 2, row-wise |
| Two    | `2E01-2H12`                                                                       | Second half of plate 2, from row E                  |
| Three  | `3A01-3A06;3B01-3B06;3C01-3C06;3D01-3D06;3E01-3E06;3F01-3F06;3G01-3G06;3H01-3H06` | Plate 3, columns 1-6                                |
| Four   | `3A07-3A12;3B07-3B12;3C07-3C12;3D07-3D12;3E07-3E12;3F07-3F12;3G07-3G12;3H07-3H12` | Plate 3, columns 7-12                               |
| Five   | `1A05;1B05;1C05;1D05;1E05;1F05;1G05`                                              | Plate 1, column 5, rows A-G                         |
