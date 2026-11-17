# Combining libraries

Libraries made with the same barcodes (for example two PCR strips with the same i5 primers) are [run as separate libraries](running.md#several-libraries-with-the-same-barcodes). Their outputs contain the same cell IDs for different cells: `GTCTTAACGT+TATAGCCT+GAACCGCG` in `DonorA-strip1` and in `DonorA-strip2` are two different nuclei. Within one library, one barcode is one cell.

The workflow keeps them apart by writing every output per sample (`allCells.csv`, matrices, Amethyst files), but inside these files cells are named by barcode only. Before combining libraries in one analysis, give every cell a unique name, e.g. by adding the sample or library name: `DonorA-strip1_GTCTTAACGT+TATAGCCT+GAACCGCG`. Otherwise tools either merge the two cells or refuse to combine the data.

## rename_amethyst_cells.py

`references/sciMETv3/rename_amethyst_cells.py` adds a prefix to the cell names in the `samples/` folder of a run, consistently across:

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
- **In-place mode** also rewrites the workflow's own `allCells.csv`. If you later rerun part of the workflow on that output folder (e.g. `start_post_extraction`), the renamed cells no longer match the workflow's intermediate files. Prefer copy mode when in doubt.

!!! note "Older Amethyst files"
    In this version of the workflow each cell is a group (`/CG/<barcode>/1`). Scripts written for the older layout, where each cell was a dataset (`/CG/<barcode>`), rename the dataset `1` instead of the cell and break the files.

## Loading into Amethyst

```r
library(amethyst)
obj <- createScaleObject(directory = "ScaleMethyl.out/samples_renamed",
                         genomeMatrices = c("CG.score"))
```

`createScaleObject` reads every `<sample>.allCells.csv` in the folder (passing cells only), finds each cell's `.h5` file through its `tgmt_well`, and loads the requested matrices from `genome_bin_matrix/<sample>.<matrix>.mtx.gz` with `<sample>.CG.features.tsv` / `<sample>.CH.features.tsv`. The matrix columns are named from `cell_id` in `allCells.csv`, so the renamed IDs carry through.

If `createScaleObject` reports a missing `genome_bin_matrix/<sample>.CG.features.tsv`, the matrix files are not in the folder. Link them from the original run:

```bash
mkdir -p samples_renamed/genome_bin_matrix
for f in samples/genome_bin_matrix/*; do ln -s "$(realpath "$f")" samples_renamed/genome_bin_matrix/; done
```

## Other tools

For matrices loaded outside Amethyst (Seurat, Scanpy), prefix the column names the same way, e.g. from `<sample>.barcodes.tsv`:

```bash
sed "s/^/DonorA-strip1_/" DonorA-strip1.barcodes.tsv > DonorA-strip1.barcodes.renamed.tsv
```
