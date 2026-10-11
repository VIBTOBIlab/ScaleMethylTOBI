# sciMETv3

[sciMETv3](https://doi.org/10.1016/j.xgen.2024.100726) (Nichols et al. 2025, *Cell Genomics* 5:100726) adds a ligation barcode to the sciMETv2 / ScaleBio design, raising the number of cells per experiment. On Illumina, sciMETv3 libraries have the same read layout as ScaleBio kit libraries, so the workflow processes them unchanged; only the barcode lists differ. These are provided in `references/sciMETv3/`.

## How cells are barcoded

Each nucleus picks up three barcodes in three rounds of split-and-pool:

1. **Tagmentation (barcode 1).** Nuclei are split across up to 96 wells per Tn5 plate. The Tn5 in each well adds its own barcode (e.g. well `1A03`). All wells are pooled.
2. **Ligation (barcode 2).** The pool is split across 96 wells, and each well ligates its own barcode (e.g. well `B07`). All wells are pooled again.
3. **PCR (barcode 3).** About 750-1,000 nuclei are diluted into each PCR well, and the indexing PCR adds that well's i5 barcode (e.g. well `A01`).

Because nuclei are randomly redistributed after each pool, any Tn5 barcode can occur together with any ligation barcode. With one Tn5 plate that gives 96 x 96 = 9,216 possible Tn5 + ligation pairs. All nuclei in one PCR well share the same i5, so inside a PCR well the Tn5 + ligation pair tells nuclei apart. A cell is identified by all three barcodes together.

Only about 750-1,000 of the possible pairs are occupied in each PCR well. Two nuclei end up with the same full barcode only when they have the same Tn5 + ligation pair and land in the same PCR well. As a rough estimate, about 8% of nuclei share their barcode with another nucleus at 750 nuclei per well and 96 Tn5 barcodes; about 3% with all 288 Tn5 barcodes. Fewer nuclei per well also lowers it.

Samples are defined by Tn5 wells (`barcodes` column of samples.csv), as for the ScaleBio kit.

## Differences from the ScaleBio kit

| | ScaleBio kit | sciMETv3 |
|---|---|---|
| Index 1 (i7) | i7 PCR barcode | Ligation barcode (96) |
| Index 2 (i5) | i5 PCR barcode | i5 PCR barcode (paper's primers or TruSeq HT D501-D508) |
| Read 2, bases 1-8 | Tn5 barcode | Tn5 barcode (same 288 barcodes) |
| Nuclei per PCR well | 15-60 (sciMETv2) | 750-1,000 |
| Library structure | `lib.json` | `sciMETv3/lib.json` or `sciMETv3/lib_D50x.json` |

Trimming, alignment, extraction and cell calling are the same.

## Files in references/sciMETv3

| File | Description |
|---|---|
| `lib.json` | Library structure for sciMETv3 with the paper's i5 primers (Table S1B/S1C) |
| `lib_D50x.json` | Library structure for sciMETv3 with TruSeq HT D501-D508 i5 primers |
| `lig_i7.txt` | The 96 ligation barcodes (Index 1) |
| `pcr_i5.txt` | The 192 i5 barcodes of the paper's two primer plates (Index 2) |
| `pcr_i5_D50x.txt` | The 8 TruSeq HT D501-D508 i5 barcodes (Index 2) |
| `tgmt.txt` | The 288 Tn5 barcodes (same as the ScaleBio kit) |
| `check_barcode_orientation.py` | Checks reads against the barcode lists before a run |
| `rename_amethyst_cells.py` | Gives cells unique names when combining libraries |
| `example_bclconvert_samplesheet.csv` | Example bcl-convert samplesheet |
| `Nichols2025_TableS1.xlsx` | Oligo and primer sequences from the paper (Table S1) |

## Pages in this section

- [Library structure](library-structure.md): read layout, barcode lists and their orientation
- [Running sciMETv3](running.md): sample table, multiple libraries, fastq or run-folder input
- [Quality control](quality-control.md): checking barcodes before a run, expected barcode metrics
- [Combining libraries](combining-libraries.md): unique cell names and loading into Amethyst
