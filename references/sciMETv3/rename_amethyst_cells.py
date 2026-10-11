#!/usr/bin/env python
"""
Prefix cell names in ScaleMethyl Amethyst outputs, so that libraries with the same
barcodes (e.g. two PCR strips with the same i5 primers) can be combined.

Renames, for every sample in <samples_dir>:
    methylation_coverage/amethyst/<sample>/<sample>.<well>_cov.h5
        /CG/<barcode>  ->  /CG/<prefix>_<barcode>   (same for CH)
    <sample>.allCells.csv
        cell_id  ->  <prefix>_<cell_id>
    genome_bin_matrix/<sample>.barcodes.tsv
        <barcode>  ->  <prefix>_<barcode>

By default renamed copies are written to <out_dir> with the same layout (the matrix
files in genome_bin_matrix/ are linked, not copied) and the original files are left
untouched, so <out_dir> can be used directly with Amethyst's createScaleObject. With --inplace the original files are changed
instead (fast, no extra disk space). Names that already carry the prefix are left
as they are, so running the script twice does not add the prefix twice.

Usage:
    rename_amethyst_cells.py <samples_dir> <out_dir> [--prefix sample|lib]
    rename_amethyst_cells.py <samples_dir> --inplace [--prefix sample|lib]
"""
import argparse
import csv
import sys
from pathlib import Path

import h5py


def get_prefix(sample: str, mode: str) -> str:
    """Cell name prefix: the full sample name, or the part after the last '-' (e.g. L1)"""
    return sample if mode == "sample" else sample.rsplit("-", 1)[-1]


def new_name(name: str, prefix: str, sep: str) -> str:
    return name if name.startswith(prefix + sep) else f"{prefix}{sep}{name}"


def rename_h5_copy(h5_in: Path, h5_out: Path, prefix: str, sep: str) -> int:
    """Copy h5_in to h5_out with renamed barcode groups; returns the number of cells"""
    h5_out.parent.mkdir(parents=True, exist_ok=True)
    cells = set()
    with h5py.File(h5_in, "r") as f_in, h5py.File(h5_out, "w") as f_out:
        f_out.attrs.update(f_in.attrs)
        for context, item in f_in.items():
            if not isinstance(item, h5py.Group):
                f_in.copy(item, f_out, name=context)
                continue
            out_group = f_out.create_group(context)
            out_group.attrs.update(item.attrs)
            for bc in item:
                f_in.copy(item[bc], out_group, name=new_name(bc, prefix, sep))
                cells.add(bc)
    return len(cells)


def rename_h5_inplace(h5_file: Path, prefix: str, sep: str) -> int:
    """Rename barcode groups inside h5_file; returns the number of cells"""
    cells = set()
    with h5py.File(h5_file, "r+") as f:
        for context, item in f.items():
            if not isinstance(item, h5py.Group):
                continue
            for bc in list(item):
                renamed = new_name(bc, prefix, sep)
                if renamed != bc:
                    item.move(bc, renamed)
                cells.add(bc)
    return len(cells)


def rename_csv(csv_in: Path, csv_out: Path, prefix: str, sep: str):
    """Write csv_in to csv_out with prefixed cell_id"""
    with open(csv_in, newline="") as f:
        reader = csv.DictReader(f)
        fields = reader.fieldnames
        rows = list(reader)
    for row in rows:
        row["cell_id"] = new_name(row["cell_id"], prefix, sep)
    csv_out.parent.mkdir(parents=True, exist_ok=True)
    with open(csv_out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def handle_matrices(samples_dir: Path, out_dir, inplace: bool, mode: str, sep: str):
    """
    Make genome_bin_matrix/ available next to the renamed files (Amethyst's createScaleObject
    reads the .mtx.gz and .features.tsv files from there). Matrices are linked, not copied;
    <sample>.barcodes.tsv files get the same prefix as the cells.
    """
    mtx_dir = samples_dir / "genome_bin_matrix"
    if not mtx_dir.is_dir():
        return
    target_dir = mtx_dir if inplace else out_dir / "genome_bin_matrix"
    if not inplace and target_dir.exists() and target_dir.resolve() == mtx_dir.resolve():
        print(f"  {target_dir} links to the original genome_bin_matrix; left unchanged", file=sys.stderr)
        return
    target_dir.mkdir(parents=True, exist_ok=True)
    for f in sorted(mtx_dir.iterdir()):
        target = target_dir / f.name
        if f.name.endswith(".barcodes.tsv"):
            prefix = get_prefix(f.name[: -len(".barcodes.tsv")], mode)
            lines = [new_name(line, prefix, sep) for line in f.read_text().splitlines() if line]
            if target.is_symlink():  # never write through a link into the original folder
                target.unlink()
            target.write_text("\n".join(lines) + "\n")
        elif not inplace and not target.exists():
            target.symlink_to(f.resolve())


def main(samples_dir: Path, out_dir, inplace: bool, mode: str, sep: str):
    amethyst_dir = samples_dir / "methylation_coverage" / "amethyst"
    sample_dirs = sorted(d for d in amethyst_dir.iterdir() if d.is_dir()) if amethyst_dir.is_dir() else []
    if not sample_dirs:
        sys.exit(f"No sample folders found in {amethyst_dir}")

    for sample_dir in sample_dirs:
        sample = sample_dir.name
        prefix = get_prefix(sample, mode)
        h5_files = sorted(sample_dir.glob(f"{sample}.*_cov.h5"))
        n_cells = 0
        for h5 in h5_files:
            if inplace:
                n_cells += rename_h5_inplace(h5, prefix, sep)
            else:
                out = out_dir / "methylation_coverage" / "amethyst" / sample / h5.name
                n_cells += rename_h5_copy(h5, out, prefix, sep)

        all_cells = samples_dir / f"{sample}.allCells.csv"
        if all_cells.exists():
            rename_csv(all_cells, all_cells if inplace else out_dir / all_cells.name, prefix, sep)
        else:
            print(f"  warning: {all_cells.name} not found", file=sys.stderr)
        print(f"{sample}: {len(h5_files)} h5 files, {n_cells} cells, prefix '{prefix}{sep}'")

    handle_matrices(samples_dir, out_dir, inplace, mode, sep)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("samples_dir", type=Path, help="ScaleMethyl <outDir>/samples folder")
    parser.add_argument("out_dir", type=Path, nargs="?", help="Folder for the renamed copies")
    parser.add_argument("--inplace", action="store_true", help="Rename in the original files instead of writing copies")
    parser.add_argument(
        "--prefix",
        choices=["sample", "lib"],
        default="sample",
        help="Prefix with the full sample name (DNA170481-L1, default) or only the part after the last '-' (L1)",
    )
    parser.add_argument("--sep", default="_", help="Separator between prefix and barcode (default: _)")
    args = parser.parse_args()

    if args.inplace == (args.out_dir is not None):
        parser.error("give either <out_dir> or --inplace")
    if args.out_dir and args.out_dir.resolve() == args.samples_dir.resolve():
        parser.error("<out_dir> must differ from <samples_dir>; use --inplace to change the original files")
    main(args.samples_dir, args.out_dir, args.inplace, args.prefix, args.sep)
