# QC reports

The workflow writes an HTML report per sample and per library in `outdir/report/`.

## Sample report

`report/sample_reports/<sample>/<sample>.report.html` summarises one sample, i.e. all or a subset of the Tn5 wells of a library.

### Read statistics

| Metric                 | Description                                                           |
| ---------------------- | --------------------------------------------------------------------- |
| Total Reads            | Reads with valid barcodes assigned to the sample                      |
| Reads Passing Trimming | Percentage of total reads that pass adapter trimming                  |
| Reads Passing Mapping  | Percentage of total reads that map to the genome                      |
| Reads Per Passing Cell | Total reads divided by the number of passing cells                    |
| Saturation             | Sequencing saturation of the sample: 1 - (unique reads / total reads) |

### Cell statistics

All numbers in this table depend on the cells called, and so on the unique reads threshold shown in the barcode rank plot.

| Metric                  | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| Number of Passing Cells | Cell barcodes above the unique reads threshold                    |
| Reads in Passing Cells  | Percentage of total reads that belong to passing cells            |
| Median Unique Reads     | Median unique reads per cell                                      |
| Median CG's Covered     | Median number of covered cytosines in CG context per cell         |
| Median CH's Covered     | Median number of covered cytosines in CH context per cell         |
| Median CG Methylation   | Median percentage of methylated cytosines in CG context           |
| Median CH Methylation   | Median percentage of methylated cytosines in CA, CT or CC context |
| Median TSS Enrichment   | Median TSS enrichment per cell                                    |

### Plots

- **Barcode rank plot**: unique reads per cell barcode, sorted from high to low (log/log). The dashed line is the cell-calling threshold.
- **Reads per cell**: unique reads per barcode, as an absolute number and relative to total reads, coloured by called cells and background barcodes.

### Cell stats tab

- **Fragment length histogram**: genomic distance between the aligned read pairs.
- **TSS enrichment**: coverage within +/- 1 kb of transcription start sites relative to control regions.
- **Mitochondrial reads**: reads mapping to the mitochondrial chromosome.

### Barcodes tab

Heatmaps of the number of reads (left) and passing cells (right) per Tn5 well.

### UMAP tab

A UMAP of the 20,000 most variable windows from the matrix generation step, with nearest-neighbour clustering (knn = min(100, number of passing cells - 1)).

## Library report

`report/library_report/<libName>/library.<libName>.report.html` summarises a whole library: sequencing, barcodes and demultiplexing for all samples in it.

### Barcode metrics

Barcode matching statistics for the full library. Reads that fail barcode matching are not assigned to any sample and are excluded from all further analysis and metrics.

| Status       | Description                                                            |
| ------------ | ---------------------------------------------------------------------- |
| Pass         | All expected barcodes were found                                       |
| BarcodeError | At least one barcode could not be found or matched to its barcode list |

See [Barcode metrics](barcode-metrics.md) for the detailed categories and how to interpret them.

### Cells called

Cell barcodes passing the unique reads threshold, per sample.

### Barcodes tab

Heatmaps of reads (left) and passing cells (right) per i5 barcode (first row) and per i7 barcode (second row). For sciMETv3 the i7 barcode is the ligation barcode.
