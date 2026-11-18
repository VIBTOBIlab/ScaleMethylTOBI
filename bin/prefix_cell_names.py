#!/usr/bin/env python
"""
Prefix the cell names of a sample, so that the cells of different samples and libraries
have unique names (e.g. two libraries with the same barcodes) when loaded together in
Amethyst. Writes renamed copies to <out_dir>:
    <sample>.allCells.csv    cell_id   ->  <prefix>_<cell_id>
    <sample>.barcodes.tsv    <barcode> ->  <prefix>_<barcode>
Names that already carry the prefix are left as they are.
"""
import argparse
import csv
from pathlib import Path


def new_name(name: str, prefix: str) -> str:
    return name if name.startswith(f"{prefix}_") else f"{prefix}_{name}"


def prefix_all_cells(all_cells: Path, out_dir: Path, prefix: str):
    with open(all_cells, newline="") as f:
        reader = csv.DictReader(f)
        fields = reader.fieldnames
        rows = list(reader)
    for row in rows:
        row["cell_id"] = new_name(row["cell_id"], prefix)
    with open(out_dir / all_cells.name, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def prefix_barcodes(barcodes: Path, out_dir: Path, prefix: str):
    lines = [new_name(line, prefix) for line in barcodes.read_text().splitlines() if line]
    (out_dir / barcodes.name).write_text("".join(f"{line}\n" for line in lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--prefix", required=True, help="Prefix of the cell names (the sample name)")
    parser.add_argument("--all_cells", type=Path, required=True, help="<sample>.allCells.csv")
    parser.add_argument("--barcodes", type=Path, nargs="*", default=[], help="<sample>.barcodes.tsv of the matrices")
    parser.add_argument("--out_dir", type=Path, default=Path("prefixed"))
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    prefix_all_cells(args.all_cells, args.out_dir, args.prefix)
    for barcodes in args.barcodes:
        prefix_barcodes(barcodes, args.out_dir, args.prefix)


if __name__ == "__main__":
    main()
