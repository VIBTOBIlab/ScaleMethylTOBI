# Library structure

The library structure file (`libStructure`, a `.json` file) tells the workflow where the barcodes are in the reads, which barcode sequences are allowed, which part of each read is genomic, and how to build the bcl-convert samplesheet. The included files are in `references/` (see [Parameters](../user-guide/parameters.md#inputs)). The barcode lists named in the file are looked up in the same folder as the `.json` file.

## Example

`references/lib.json` (ScaleBio kit):

```json
{
    "barcodes" : [
        {"read": "index1", "start": 0, "length": 10, "name": "i7", "sequences": "i7.txt"},
        {"read": "index2", "start": 0, "length": 10, "name": "i5", "sequences": "i5.txt"},
        {"read": "read2", "start": 0, "length": 8, "name": "tgmt", "sequences": "tgmt.txt", "alias": "Tagmentation", "level": 1}
    ],
    "sample_barcode": "tgmt",
    "genomic_r1": {"start": 10},
    "genomic_r2": {"start": 28},
    "bcl_convert": {
        "split_on": "index2",
        "index1Seqs": "i7.txt",
        "index2Seqs": "i5.txt",
        "library_barcodes": {}
    }
}
```

## Fields

| Field | Description |
|---|---|
| `barcodes` | List of the barcodes that together identify a cell, see below |
| `sample_barcode` | `name` of the barcode that defines samples (the `barcodes` column of samples.csv refers to its well names) |
| `genomic_r1.start` | First base of genomic sequence in Read 1 (0-based); bases before it are removed |
| `genomic_r2.start` | First base of genomic sequence in Read 2; 28 = 8 bp Tn5 barcode + Tn5 adapter |
| `bcl_convert.split_on` | `index1` or `index2`: write one set of fastq files per barcode of this index read |
| `bcl_convert.index1Seqs` | Barcode list used for Index 1 in the bcl-convert samplesheet |
| `bcl_convert.index2Seqs` | Barcode list used for Index 2 in the bcl-convert samplesheet |
| `bcl_convert.index2RevComp` | Optional, `true` to reverse-complement the Index 2 sequences in the samplesheet |
| `bcl_convert.adapter` | Optional adapter sequence for bcl-convert adapter trimming |
| `bcl_convert.library_barcodes` | Optional file of named index sets that can be used in the `libIndex` columns |

The `bcl_convert` section is only used when starting from a run folder. `OverrideCycles` in the file is not used; the workflow derives it from `RunInfo.xml`.

### Barcodes

| Key | Description |
|---|---|
| `read` | Read that contains the barcode: `read1`, `read2`, `index1` or `index2` |
| `start` | Position of the first base in the read (0-based) |
| `length` | Barcode length; may be shorter than the read (e.g. 8 bp of a 10-cycle index read) |
| `name` | Barcode name, used in the output (`<name>_well` columns in `allCells.csv`, report plots) |
| `sequences` | Barcode list file |
| `alias`, `level` | Optional; the included files set them only for the Tn5 barcode (`Tagmentation`, level 1) |

The order of `barcodes` is the order of the sequences in the cell ID (`i7+i5+tgmt`). The library report plots the two barcodes that are not the sample barcode against each other, so the reports expect exactly three barcodes.

## Barcode list files

Tab-separated, one barcode per line: the sequence as it appears in the fastq files, and a well name.

```text
GAACCGCG	1A01
AGGTTATA	1A02
```

- Sequences must be in the orientation of the reads (see [sciMETv3 barcode orientation](../scimetv3/library-structure.md#barcode-orientation)).
- Well names must be a letter followed by a number (`A01`, `H12`, `P12`); for the sample barcode with a leading plate number (`1A01`). The reports take the plate size from the last line, so list the wells in order with the highest well last.
- No header and no comment lines.

## Making a new library structure

To support another primer set (for example different i5 primers), copy an existing `.json` and its barcode lists into a new folder under `references/`, replace the barcode list, adjust `length` if needed, and select it with `libStructure: "<folder>/<file>.json"`. Check the result on your reads with `check_barcode_orientation.py` ([sciMETv3 QC](../scimetv3/quality-control.md#checking-barcodes-before-a-run)).
