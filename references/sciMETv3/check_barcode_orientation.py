#!/usr/bin/env python
"""
Check that the barcode whitelists in a library structure json match the reads
as sequenced (and not their reverse complement).

Usage:
    check_barcode_orientation.py lib.json --I1 x_I1.fastq.gz --I2 x_I2.fastq.gz --R2 x_R2.fastq.gz
"""
import argparse
import collections
import gzip
import json
from pathlib import Path


def revComp(seq: str) -> str:
    return seq.translate(str.maketrans("ACGTN", "TGCAN"))[::-1]


def read_seqs(fq: Path, start: int, length: int, n: int):
    seqs = []
    with gzip.open(fq, "rt") as f:
        for i, line in enumerate(f):
            if i % 4 == 1:
                seqs.append(line.strip()[start : start + length])
                if len(seqs) >= n:
                    break
    return seqs


def main(libJson: Path, fastqs: dict, n: int):
    lib = json.load(open(libJson))
    readNames = {"index1": "I1", "index2": "I2", "read1": "R1", "read2": "R2"}
    for bc in lib["barcodes"]:
        fq = fastqs.get(readNames[bc["read"]])
        if fq is None:
            continue
        wl = {}
        for line in open(libJson.parent / bc["sequences"]):
            seq, name = line.split()[:2]
            wl[seq] = name
        seqs = read_seqs(fq, bc["start"], bc["length"], n)
        asRead = sum(s in wl for s in seqs) / len(seqs)
        rc = sum(revComp(s) in wl for s in seqs) / len(seqs)
        top = collections.Counter(seqs).most_common(5)
        print(f"{bc['name']} ({bc['sequences']}, {fq.name}): as-read {asRead:.1%}, reverse-complement {rc:.1%}")
        for s, c in top:
            print(f"    {s}  {c:>7}  {wl.get(s, 'rc:' + wl[revComp(s)] if revComp(s) in wl else 'no match')}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("libJson", type=Path)
    parser.add_argument("--I1", type=Path)
    parser.add_argument("--I2", type=Path)
    parser.add_argument("--R2", type=Path)
    parser.add_argument("-n", type=int, default=200000, help="Number of reads to check")
    args = parser.parse_args()
    fastqs = {k: v for k, v in (("I1", args.I1), ("I2", args.I2), ("R2", args.R2)) if v}
    main(args.libJson, fastqs, args.n)
