#!/usr/bin/env python
"""
Generate bed file with genomic windows
"""
import argparse
import gzip
from pathlib import Path


def parse_args():
    """
    Parse command line arguments
    """
    parser = argparse.ArgumentParser(description="Create BED file with genomic windows")
    parser.add_argument("--genomeTiles", type=int, required=True, help="Size of the windows")
    parser.add_argument("--chromSizes", type=Path, required=True, help="Path to the chrom.sizes file")
    parser.add_argument("--blacklist", type=Path, required=False, help="Path to the blacklist file")
    parser.add_argument("--output", type=Path, required=True, help="Path to the output BED file")
    parser.add_argument(
        "--minimumWindowSize",
        type=int,
        required=False,
        default=1,
        help="Minimum size of the windows",
    )
    return parser.parse_args()


def read_blacklist(blacklist: Path) -> dict:
    """
    Read the blacklisted regions of a BED file (plain or gzipped; only the first three columns are used)

    Args:
        blacklist: path to the blacklist BED file

    Returns:
        {chrom: [(start, end), ...]} sorted, with overlapping and adjacent regions merged
    """
    regions = {}
    opener = gzip.open if str(blacklist).endswith(".gz") else open
    with opener(blacklist, "rt") as bl:
        for line in bl:
            fields = line.split()
            if not fields or fields[0].startswith(("#", "track", "browser")):
                continue
            chrom, start, end = fields[0], int(fields[1]), int(fields[2])
            if end > start:
                regions.setdefault(chrom, []).append((start, end))
    merged = {}
    for chrom, intervals in regions.items():
        intervals.sort()
        out = [list(intervals[0])]
        for start, end in intervals[1:]:
            if start <= out[-1][1]:
                out[-1][1] = max(out[-1][1], end)
            else:
                out.append([start, end])
        merged[chrom] = [tuple(interval) for interval in out]
    return merged


def window_pieces(start: int, end: int, regions: list, first: int) -> tuple:
    """
    Parts of the window [start, end) outside the blacklisted regions

    Args:
        start, end: window (0-based, end exclusive)
        regions: sorted, non-overlapping blacklisted regions of the chromosome
        first: index of the first region that can overlap this window (windows are visited in order)

    Returns:
        (list of (start, end) pieces, index of the first region that can overlap the next window)
    """
    # Regions that end before this window cannot overlap any later window
    while first < len(regions) and regions[first][1] <= start:
        first += 1
    pieces = []
    pos = start
    i = first
    while i < len(regions) and regions[i][0] < end:
        bl_start, bl_end = regions[i]
        if bl_start > pos:
            pieces.append((pos, bl_start))
        pos = max(pos, bl_end)
        i += 1
    if pos < end:
        pieces.append((pos, end))
    return pieces, first


def create_windows(
    chrom_sizes_file: Path,
    blacklist: Path,
    window_size: int,
    output_file: Path,
    minimum_window_size: int = 1,
):
    """
    Create a BED file with genomic windows from a window size and a chrom.sizes file.
    Blacklisted regions are cut out of the windows: a window overlapping a blacklisted region is
    replaced by its parts outside the region, and parts shorter than minimum_window_size are dropped.

    Args:
        chrom_sizes_file: path to the chrom.sizes file
        blacklist: path to the blacklist BED file (optional)
        window_size: size of the windows
        output_file: path to the output BED file
        minimum_window_size: minimum size of a window (or part of a window)
    """
    blacklist_regions = read_blacklist(blacklist) if blacklist else {}

    with open(chrom_sizes_file, "r") as f, open(output_file, "w") as out:
        # for each chromosome, create windows of size window_size starting at 0
        for line in f:
            fields = line.split()
            if not fields:
                continue
            chrom, size = fields[0], int(fields[1])
            regions = blacklist_regions.get(chrom, [])
            first = 0
            for start in range(0, size, window_size):
                end = min(start + window_size, size)
                pieces, first = window_pieces(start, end, regions, first)
                for piece_start, piece_end in pieces:
                    if piece_end - piece_start >= minimum_window_size:
                        out.write(f"{chrom}\t{piece_start}\t{piece_end}\n")


def main():
    args = parse_args()
    create_windows(
        args.chromSizes,
        args.blacklist,
        args.genomeTiles,
        args.output,
        args.minimumWindowSize,
    )


if __name__ == "__main__":
    main()
