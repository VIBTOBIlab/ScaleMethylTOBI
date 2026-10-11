# sciMETv3 quality control

## Checking barcodes before a run

Before a full run, check that the barcode lists match your reads in the right orientation. `check_barcode_orientation.py` (standard Python 3, no extra packages) reads the first reads of a fastq set and reports, for every barcode in a library structure, the fraction of reads that match as read and as reverse complement, plus the most frequent sequences:

```bash
SM=/path/to/ScaleMethyl/references/sciMETv3
python3 $SM/check_barcode_orientation.py $SM/lib_D50x.json \
    --I1 lib_S1_L001_I1_001.fastq.gz \
    --I2 lib_S1_L001_I2_001.fastq.gz \
    --R2 lib_S1_L001_R2_001.fastq.gz
```

Example output (truncated):

```text
i7 (lig_i7.txt, lib_S1_L001_I1_001.fastq.gz): as-read 74.3%, reverse-complement 0.0%
    GCGTAGTACG     9955  G03
    GCCTTCGCCT     3489  D02
tgmt (tgmt.txt, lib_S1_L001_R2_001.fastq.gz): as-read 73.9%, reverse-complement 0.5%
    GTCGGAGC     4286  1D08
```

- Each barcode should match mostly **as read**, with **reverse complement** near 0%. If it is the other way around, reverse-complement the barcode list.
- The first reads of a file come from the edges of the flow cell and match less well than the whole run; 70-90% here is normal, and PhiX reads never match.
- If the most frequent sequences show `no match`, a different primer set was used. Compare them with known index sets; for example, 8 sequences ending in `AC` (`TATAGCCTAC`, `ATAGAGGCAC`, ...) are TruSeq HT D501-D508 ([lib_D50x.json](library-structure.md#truseq-ht-d501-d508-primers)).
- If Index 1 matches nothing, check that the Table S1A ligation oligos were used, and that the PCR used the non-indexed P7 flow-cell primer: an indexed i7 PCR primer replaces the ligation barcode.

A quick shell-only look at the most frequent Index 2 sequences:

```bash
zcat lib_S1_L001_I2_001.fastq.gz | head -4000000 | awk 'NR%4==2' \
    | sort | uniq -c | sort -k1,1nr | head -12
```

## Expected barcode metrics

After demultiplexing, check the barcode statistics in the library report or `barcodes/<libName>.metrics.json` ([Barcode metrics](../outputs/barcode-metrics.md)).

Example from a sciMETv3 library sequenced as a whole lane with PhiX (D501-D508 i5 primers, one Tn5 plate):

| Metric | Value |
|---|---|
| Pass | 79.7% |
| i5 matched (exact + corrected) | 91.4% |
| Ligation (i7) matched | 90.5% |
| Tn5 matched | 91.0%, plus 1.3% ambiguous |
| Corrected (one mismatch), each barcode | about 12% |
| Unknown (Tn5 wells outside the sample table) | 0.6% |

How to read this:

- **The Pass rate is lower than in ScaleBio kit runs** (often about 98%) because the input was a whole lane. In ScaleBio runs, bcl-convert removes reads with unknown index barcodes, including PhiX, before `bc_parser`; here `bc_parser` sees them and counts them as BarcodeError.
- **NoMatch of about 8-10% for every barcode** is mostly the same reads (PhiX, poor clusters).
- **A high Corrected fraction** means error-prone index reads. Low sequence diversity on the index cycles (e.g. only 8 i5 barcodes in a lane) makes base calling harder on two-colour instruments.
- **Ambiguous Tn5 barcodes**: within one Tn5 plate all barcodes differ in at least 4 positions, but some barcodes of different plates differ in only 2. A read with one error can then be equally close to two barcodes and is discarded. When only one Tn5 plate was used, a Tn5 list with only that plate would recover most of these reads.
- **Unknown** well below 1% means little cross-contamination between used and unused Tn5 wells. Samples left out of the sample table on purpose (e.g. another species, analysed separately) also count as Unknown.

## Per-well checks

The `barcode_counts.*.tsv` files and the library report heatmaps show reads per well for each barcode:

- **i5 (PCR wells)**: all sequenced wells present, within about a 2-fold range of each other.
- **Ligation wells**: all 96 present, mostly 0.5-2% of reads each (1.04% would be perfectly even). A well with several times more reads may have received more nuclei; check whether it also has more cells. A nearly empty well usually means the ligation failed in that well; only its nuclei are lost.
- **Tn5 wells / samples**: reads per sample roughly proportional to the number of Tn5 wells of the sample, if the nuclei input per well was similar. Consistently low wells for one sample point to fewer or less efficiently tagmented nuclei.

After alignment and cell calling, check the sample reports: cells per sample, median unique reads per cell, mapping rate (about 94% in the paper) and duplication.
