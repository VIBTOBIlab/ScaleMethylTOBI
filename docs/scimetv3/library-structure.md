# sciMETv3 library structure

## Read layout

| Read | Barcode | Barcode list | Source |
|---|---|---|---|
| Index 1 (10 bp) | Ligation barcode (barcode 2) | `lig_i7.txt` (96, A01-H12) | Table S1A; reverse complement of the barcode in the oligo |
| Index 2 (10 bp) | PCR i5 barcode (barcode 3) | `pcr_i5.txt` (192) or `pcr_i5_D50x.txt` (8) | Table S1B as A01-H12 and Table S1C as I01-P12; reverse complement of the primer index. Or TruSeq HT D501-D508 |
| Read 2, bases 1-8 | Tn5 barcode (barcode 1, sample barcode) | `tgmt.txt` (288) | Unchanged from ScaleBio (identical to the Adey lab s3 Tn5 set) |

The ligation oligo (Table S1A) contains the P7 flow-cell sequence, the 10 bp ligation barcode and the 5' half of the Read 2 primer, so the ligation barcode is read by Index 1, where the ScaleBio kit has its i7 PCR barcode. The indexing PCR uses a non-indexed P7 flow-cell primer and indexed i5 primers.

In the workflow output, a cell ID is the three barcode sequences joined as `ligation+i5+Tn5` (the order of `barcodes` in the library structure), e.g. `GTCTTAACGT+TATAGCCT+GAACCGCG`. `allCells.csv` also lists the matching wells in `i7_well` (ligation), `i5_well` and `tgmt_well`.

## Choosing the library structure

| i5 primers used in the indexing PCR | `libStructure` | i5 barcode |
|---|---|---|
| The paper's primers (Table S1B / S1C) | `sciMETv3/lib.json` | 10 bp, `pcr_i5.txt` |
| Illumina TruSeq HT D501-D508 | `sciMETv3/lib_D50x.json` | 8 bp, `pcr_i5_D50x.txt` |
| Another set | Make a copy of `lib.json` with your own i5 list (see [Library structure](../reference/library-structure.md)) | |

If you are not sure which primers were used, look at the most frequent Index 2 sequences ([Quality control](quality-control.md#checking-barcodes-before-a-run)).

### TruSeq HT D501-D508 primers

D501-D508 are 8 bp indexes. With a 10-cycle Index 2 read, the last two cycles read into the adapter after the index, so every I2 read ends in `AC` (e.g. `TATAGCCTAC` for D501). `lib_D50x.json` uses only the first 8 bases: the `AC` carries no information, and sequencing errors in it would otherwise cost reads. The barcodes are named D01-D08 for D501-D508.

`lib_D50x.json` is meant for fastq input (`--fastqDir`). Starting from a run folder with a 10-cycle Index 2 read would need `OverrideCycles` with `I8N2` for Index 2, which the generated bcl-convert samplesheet does not do.

With only 8 i5 barcodes, separate PCR libraries (e.g. PCR strips) often use the same D501-D508 set. These must be run as [separate libraries](running.md#several-libraries-with-the-same-barcodes).

## Barcode orientation

All barcode lists hold the sequence as it appears in the fastq files.

- **Index 1** reads the reverse complement of the barcode as written in the P7-side oligo, on every instrument.
- **Index 2** depends on the instrument. `pcr_i5.txt` assumes a reverse-complement-workflow instrument (NovaSeq 6000 v1.5, NovaSeq X, NextSeq 500/550/1000/2000), the same convention as the ScaleBio `i5.txt`. For a forward-strand instrument (MiSeq, NovaSeq 6000 with v1.0 reagents), reverse-complement the sequences in `pcr_i5.txt`.

Always check the orientation on your own reads before a full run ([Quality control](quality-control.md#checking-barcodes-before-a-run)).

## Well names

The QC reports only accept well names made of a letter followed by a number. The two i5 plates use the same well names in Table S1, so the second plate (S1C) is named I01-P12 in `pcr_i5.txt`.
