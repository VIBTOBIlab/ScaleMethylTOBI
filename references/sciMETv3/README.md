# sciMETv3 library structures

Barcode lists, library structures and helper scripts for sciMETv3 (Nichols et al. 2025, Cell Genomics 5:100726) sequenced on Illumina. Full documentation: `docs/scimetv3/` (or the "sciMETv3" section of the documentation site).

| File | Description |
|---|---|
| `lib.json` | Library structure for the paper's i5 PCR primers (Table S1B/S1C): `libStructure: "sciMETv3/lib.json"` |
| `lib_D50x.json` | Library structure for TruSeq HT D501-D508 i5 primers (8 bp): `libStructure: "sciMETv3/lib_D50x.json"` |
| `lig_i7.txt` | 96 ligation barcodes, read by Index 1 |
| `pcr_i5.txt` | 192 i5 barcodes of the paper's two primer plates (A01-H12, I01-P12), read by Index 2 |
| `pcr_i5_D50x.txt` | 8 TruSeq HT D501-D508 i5 barcodes (D01-D08) |
| `tgmt.txt` | 288 Tn5 barcodes, read 2 bases 1-8 (same as the ScaleBio kit) |
| `check_barcode_orientation.py` | Checks reads against the barcode lists before a run |
| `rename_amethyst_cells.py` | Prefixes cell names in Amethyst `.h5`, `allCells.csv` and `barcodes.tsv` to combine libraries with the same barcodes |
| `example_bclconvert_samplesheet.csv` | Example bcl-convert samplesheet (PCR wells A01-A02) |
| `Nichols2025_TableS1.xlsx` | Oligo and primer sequences from the paper |

All barcode lists hold the sequence as it appears in the fastq files (Index 2 for reverse-complement-workflow instruments: NovaSeq 6000 v1.5, NovaSeq X, NextSeq).

Quick checks:

    python3 check_barcode_orientation.py lib_D50x.json --I1 x_I1.fastq.gz --I2 x_I2.fastq.gz --R2 x_R2.fastq.gz
    python3 rename_amethyst_cells.py <outDir>/samples <outDir>/samples_renamed
