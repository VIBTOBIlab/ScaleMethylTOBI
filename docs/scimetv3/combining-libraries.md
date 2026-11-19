# Combining libraries

Libraries made with the same barcodes (for example two PCR strips with the same i5 primers) are [run as separate libraries](running.md#several-libraries-with-the-same-barcodes). Their outputs contain the same cell IDs for different cells: `GTCTTAACGT+TATAGCCT+GAACCGCG` in `DonorA-strip1` and in `DonorA-strip2` are two different nuclei. Within one library, one barcode is one cell.

The workflow keeps them apart by writing every output per sample (`allCells.csv`, matrices, Amethyst files). Since version 1.5.0 it also names the cells in `samples/` `<sample>_<barcode>`, e.g. `DonorA-strip1_GTCTTAACGT+TATAGCCT+GAACCGCG`, in all three places Amethyst reads:

| File                                                            | Cell names                                          |
| --------------------------------------------------------------- | --------------------------------------------------- |
| `<sample>.allCells.csv`                                         | `cell_id` = `<sample>_<barcode>`                    |
| `genome_bin_matrix/<sample>.barcodes.tsv`                       | `<sample>_<barcode>`                                |
| `methylation_coverage/amethyst/<sample>/<sample>.<well>_cov.h5` | Groups `/CG/<sample>_<barcode>`, `/CH/<sample>_<barcode>` |

With unique sample names per library (as recommended), every cell has a unique name, and the `samples/` folder can be loaded directly with Amethyst (see [below](#loading-into-amethyst)). The workflow itself keeps working with the barcodes: `cell_metrics/<sample>.allCells.csv` has the barcodes as cell names and is used to restart, and the per-cell `.cov` / `.allc` files keep their barcode file names. Use `--skip_cell_prefix` to keep the barcodes as cell names in `samples/` as well.

## Outputs of earlier versions: rename_amethyst_cells.py

For output folders of versions before 1.5.0 (or runs with `--skip_cell_prefix`), `references/sciMETv3/rename_amethyst_cells.py` adds the prefix afterwards, consistently across:

| File                                                            | Change                                                                                                   |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `methylation_coverage/amethyst/<sample>/<sample>.<well>_cov.h5` | Groups `/CG/<barcode>` and `/CH/<barcode>` renamed to `/CG/<prefix>_<barcode>`, `/CH/<prefix>_<barcode>` |
| `<sample>.allCells.csv`                                         | `cell_id` prefixed                                                                                       |
| `genome_bin_matrix/<sample>.barcodes.tsv`                       | Barcodes prefixed                                                                                        |

It needs Python 3 with `h5py` (on an HPC e.g. `module load h5py`).

```bash
SCRIPT=/path/to/ScaleMethyl/references/sciMETv3/rename_amethyst_cells.py

# renamed copies in a new folder (originals untouched)
python $SCRIPT ScaleMethyl.out/samples ScaleMethyl.out/samples_renamed

# prefix with the part after the last '-' of the sample name (strip1_, strip2_) instead of the full name
python $SCRIPT ScaleMethyl.out/samples ScaleMethyl.out/samples_renamed --prefix lib

# rename in the original files (fast, no extra disk space)
python $SCRIPT ScaleMethyl.out/samples --inplace
```

It prints one line per sample with the number of files and cells and the prefix used. Names that already carry the prefix are left unchanged, so running it twice is safe.

- **Copy mode** (default) writes renamed `.h5` and `allCells.csv` files to the new folder and links the matrix files of `genome_bin_matrix/` into it (only `barcodes.tsv` is rewritten). The new folder can be loaded directly with Amethyst. The `.h5` copies need as much disk space as the originals; check with `du -sh samples/methylation_coverage/amethyst`.
- **In-place mode** also rewrites the workflow's own `allCells.csv`. If you later rerun the workflow with `-resume` into that output folder, the renamed cells no longer match the workflow's intermediate files. Prefer copy mode when in doubt.

!!! note "Older Amethyst files"
    In this version of the workflow each cell is a group (`/CG/<barcode>/1`). Scripts written for the older layout, where each cell was a dataset (`/CG/<barcode>`), rename the dataset `1` instead of the cell and break the files.

## Loading into Amethyst

```r
library(amethyst)
obj <- createScaleObject(directory = "ScaleMethyl.out/samples", # or samples_renamed for earlier versions
                         genomeMatrices = c("CG.score"))
```

`createScaleObject` reads every `<sample>.allCells.csv` in the folder (passing cells only), finds each cell's `.h5` file through its `tgmt_well`, and loads the requested matrices from `genome_bin_matrix/<sample>.<matrix>.mtx.gz` with `<sample>.CG.features.tsv` / `<sample>.CH.features.tsv`. The matrix columns are named from `cell_id` in `allCells.csv`, so the `<sample>_<barcode>` names carry through.

If `createScaleObject` reports a missing `genome_bin_matrix/<sample>.CG.features.tsv`, the matrix files are not in the folder. Link them from the original run:

```bash
mkdir -p samples_renamed/genome_bin_matrix
for f in samples/genome_bin_matrix/*; do ln -s "$(realpath "$f")" samples_renamed/genome_bin_matrix/; done
```

## Other tools

The matrix columns in `genome_bin_matrix/<sample>.barcodes.tsv` already carry the `<sample>_` prefix, so matrices loaded outside Amethyst (Seurat, Scanpy) have unique cell names too. For outputs of earlier versions, prefix them the same way:

```bash
sed "s/^/DonorA-strip1_/" DonorA-strip1.barcodes.tsv > DonorA-strip1.barcodes.renamed.tsv
```
