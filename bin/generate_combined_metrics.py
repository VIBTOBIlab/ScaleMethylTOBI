#!/usr/bin/env python
"""
Generate combined sample report for all samples in a library
"""
import argparse
import pandas as pd
from pathlib import Path
from reporting.reporting import (
    WhitelistAndLibJsonHelper,
    GenerateMetrics,
)


def accept_args() -> argparse.Namespace:
    """
    Accept command line arguments
    """
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Generate combined sample report",
    )
    parser.add_argument("--library_name", type=str, required=True, help="Identifier for this library")
    parser.add_argument(
        "--out_dir",
        default=".",
        type=Path,
        help="Path to output directory for plots and report",
    )
    parser.add_argument("--all_cells", nargs="+", type=Path, help="Path to complexity stats files")
    parser.add_argument(
        "--passing_cell_stats",
        nargs="+",
        type=Path,
        required=True,
        help="Path to passing methyl stats files",
    )
    parser.add_argument(
        "--library_structure_json",
        type=Path,
        help="Path to library structure json file",
    )
    parser.add_argument("--workflow_version", type=str, help="Version of the workflow")
    parser.add_argument(
        "--tss_enrich",
        nargs="*",
        type=Path,
        default=[],
        help="Per-cell TSS enrichment files (<sample>[.<well>].tss_enrich.csv) of the samples of the library",
    )
    args = parser.parse_args()
    return args


def median_tss_enrich(tss_files: list[Path], passing_cells: pd.DataFrame) -> dict:
    """
    Median TSS enrichment of the passing cells of each sample

    Args:
        tss_files: TSS enrichment files; the file name starts with the sample name
        passing_cells: Passing cells (columns cell_id, sample)

    Returns:
        {sample: median TSS enrichment, as a string rounded to 2 decimals}
    """
    # Longest name first, so that sample "A" does not claim the files of sample "A.1"
    samples = sorted(passing_cells["sample"].astype(str).unique(), key=len, reverse=True)
    tss_by_sample = {}
    for file in tss_files:
        if file.stat().st_size <= 1:  # no passing cells in this well
            continue
        sample = next((s for s in samples if file.name.startswith(f"{s}.")), None)
        if sample is None:
            continue
        tss_by_sample.setdefault(sample, []).append(pd.read_csv(file, usecols=["cell_id", "tss_enrich"]))
    medians = {}
    for sample, dfs in tss_by_sample.items():
        cells = passing_cells.loc[passing_cells["sample"].astype(str) == sample, ["cell_id"]]
        tss = cells.merge(pd.concat(dfs, ignore_index=True), on="cell_id")["tss_enrich"]
        if not tss.dropna().empty:
            medians[sample] = str(round(tss.median(), 2))
    return medians


def main():
    args = accept_args()
    write_dir = args.out_dir
    write_dir.mkdir(parents=True, exist_ok=True)
    Path(write_dir / "csv").mkdir(exist_ok=True)

    all_cells = [pd.read_csv(all_cell, dtype={"tgmt_well": "str"}) for all_cell in args.all_cells]
    library_all_cells = pd.concat(all_cells, ignore_index=True, axis=0)
    library_methyl_df = library_all_cells[library_all_cells["pass"] == "pass"]
    library_methyl_df = library_methyl_df.sort_values(by="sample")

    lib_json = WhitelistAndLibJsonHelper.get_lib_json(args.library_structure_json)
    barcode_list = lib_json["barcodes"]
    barcode_name_list = []
    for barcodes in barcode_list:
        if barcodes["name"] != "umi" and barcodes["name"] != lib_json["sample_barcode"]:
            barcode_name_list.append(barcodes["name"])

    GenerateMetrics.build_combined_plate_plot_csv(
        library_methyl_df,
        barcode_name_list,
        args.library_name,
        write_dir,
        args.library_structure_json,
    )

    # The per-sample stats are written before TSS enrichment is computed, so add its median here
    tss_medians = median_tss_enrich(args.tss_enrich, library_methyl_df)
    GenerateMetrics.build_combined_passing_met_stats_table_csv(
        write_dir, args.library_name, args.passing_cell_stats, tss_medians
    )


if __name__ == "__main__":
    main()
