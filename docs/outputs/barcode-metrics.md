# Barcode metrics

`bc_parser` reports how well the barcodes of each read matched the barcode lists of the library structure. The numbers are in the library report and in `barcodes/<libName>.metrics.json`.

## Read-level metrics

| Status        | Description                                                                                    |
| ------------- | ---------------------------------------------------------------------------------------------- |
| Pass          | All expected barcodes were found                                                               |
| BarcodeError  | At least one barcode could not be matched to its barcode list                                  |
| LinkerError   | A fixed linker sequence between barcodes was not found (not used by the methylation libraries) |
| TooShortError | The read was too short for barcode matching                                                    |

## Barcode-level metrics

For each barcode (e.g. `i7`, `i5`, `tgmt`):

| Category  | Description                                                                                        |
| --------- | -------------------------------------------------------------------------------------------------- |
| Exact     | The sequence exactly matches a barcode in the list                                                 |
| Corrected | The sequence has a mismatch but is closest to a single barcode in the list, and is corrected to it |
| Ambiguous | The sequence is equally close to two barcodes in the list, and is discarded                        |
| NoMatch   | The sequence cannot be matched to any barcode in the list                                          |
| Error     | No barcode sequence could be extracted, typically because a linker was not found                   |

## metrics.json

```json
{
  "barcodes": {"i7": {"Exact": [157818224, "78.9%"], "Corrected": [...], "Ambiguous": [...], "NoMatch": [...]}, ...},
  "reads":    {"Pass": [159565166, "79.7%"], "BarcodeError": [...], ...},
  "samples":  {"Unknown": {"reads": [...]}, "<sample>": {"reads": [...], "barcodes": {"1A01": {"sequence": "...", "reads": ...}}}}
}
```

The `samples` section counts the reads per sample and Tn5 well. `Unknown` holds reads with a valid Tn5 barcode that is not assigned to any sample in samples.csv (unused Tn5 wells, or samples left out of the table).

## Interpreting the numbers

- **Compare like with like.** When the fastq files were demultiplexed by index (bcl-convert with the index sequences, as with the ScaleBio samplesheets), reads with unreadable or unknown index barcodes, including PhiX, end up in `Undetermined` and never reach `bc_parser`. The Pass rate is then close to 100%. When a whole lane is given as input (e.g. facility fastq files without index demultiplexing), those reads count as BarcodeError. Add the `Undetermined` percentage from bcl-convert to compare runs.
- **NoMatch similar for all barcodes** points to reads that carry no library barcodes at all: PhiX, empty or low-quality clusters.
- **NoMatch high for one barcode only** points to a problem with that barcode: a wrong barcode list, the wrong orientation (reverse complement) or a different primer set. Check the most frequent unmatched sequences, e.g. with `check_barcode_orientation.py` ([sciMETv3 QC](../scimetv3/quality-control.md#checking-barcodes-before-a-run)).
- **Corrected** reflects sequencing errors in the barcodes. A high fraction is not a problem by itself, but more reads with one error also means more reads with two errors, which are lost.
- **Ambiguous** occurs when barcodes in the list differ in only two positions. Removing unused barcodes from the list (e.g. Tn5 plates that were not used) reduces it.
- **Unknown** should be small (well below 1%) when all used Tn5 wells are assigned to samples; reads on unused Tn5 wells indicate cross-contamination or misread barcodes.
