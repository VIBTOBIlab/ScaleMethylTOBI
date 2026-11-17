#!/usr/bin/env python3
"""
Generate the tiny synthetic dataset used by the nf-test pipeline tests.

Writes, next to this script:
  genome/genome.fa            two random chromosomes (chr1, chr2) and a small chrM
  genome/filter_chrs.tsv      chrM labelled as mito
  genome/tss.bed              200 bp windows treated as TSSs
  genome/background.bed       200 bp windows 1 kb upstream of them
  fastq/ScaleMethyl_S1_L001_{I1,I2,R1,R2}_001.fastq.gz

Reads follow the ScaleBio v1.1 layout in references/lib.json:
  I1 = i7 barcode (10 bp), I2 = i5 barcode (10 bp)
  R2 = Tn5 barcode (8 bp) + 20 bp of Tn5 adapter + genomic sequence
  R1 = 10 bp of adapter + genomic sequence

Genomic sequence is bisulfite converted (directional library): R2 reads the
converted original strand, R1 reads the reverse complement of its other end.
CpGs are methylated with probability 0.8, all CH positions are unmethylated.

The output is fixed by the random seed, so re-running the script reproduces
the committed files. The bwa-meth index in genome/ is built separately (see
tests/README.md).
"""
import gzip
import random
from pathlib import Path

SEED = 42
HERE = Path(__file__).resolve().parent
REFS = HERE.parent.parent / "references"

CHROMS = {"chr1": 40_000, "chr2": 30_000, "chrM": 2_000}
CELLS_PER_SAMPLE = 6
READS_PER_CELL = 300
BACKGROUND_BARCODES = 30  # barcode combinations with only a few reads (not cells)
READS_PER_BACKGROUND = 3
READ_LEN_GENOMIC = 70
R1_PREFIX = 10  # genomic_r1.start in lib.json
TN5_ADAPTER = "AGATGTGTATAAGAGACAGA"  # 20 bp between Tn5 barcode and insert (genomic_r2.start 28)
R1_ADAPTER = "TCGTCGGCAG"  # 10 bp before the insert in R1

# Tn5 wells per sample; must match tests/data/samples.csv
SAMPLES = {"SampleA": ["1A01", "1A02", "1A03"], "SampleB": ["1A07", "1A08", "1A09"]}

COMP = str.maketrans("ACGTN", "TGCAN")


def revcomp(s):
    return s.translate(COMP)[::-1]


def read_whitelist(name):
    bcs = {}
    for line in (REFS / name).read_text().splitlines():
        if line.strip():
            seq, well = line.split("\t")[:2]
            bcs[well] = seq
    return bcs


def bisulfite(seq, rng):
    """Convert one strand: unmethylated C -> T. CpG C stays C with p=0.8."""
    out = []
    for i, base in enumerate(seq):
        if base == "C":
            is_cpg = i + 1 < len(seq) and seq[i + 1] == "G"
            out.append("C" if is_cpg and rng.random() < 0.8 else "T")
        else:
            out.append(base)
    return "".join(out)


def fastq_record(name, seq):
    return f"@{name}\n{seq}\n+\n{'I' * len(seq)}\n"


def main():
    rng = random.Random(SEED)
    genome_dir = HERE / "genome"
    fastq_dir = HERE / "fastq"
    genome_dir.mkdir(exist_ok=True)
    fastq_dir.mkdir(exist_ok=True)

    genome = {c: "".join(rng.choice("ACGT") for _ in range(n)) for c, n in CHROMS.items()}
    with open(genome_dir / "genome.fa", "w") as fa:
        for c, s in genome.items():
            fa.write(f">{c}\n")
            for i in range(0, len(s), 60):
                fa.write(s[i : i + 60] + "\n")
    (genome_dir / "filter_chrs.tsv").write_text("chrM\tmito\n")

    # TSS windows every 2 kb on the nuclear chromosomes, background 1 kb upstream
    tss, bg = [], []
    for c in ("chr1", "chr2"):
        for pos in range(2_000, CHROMS[c] - 1_000, 2_000):
            tss.append((c, pos - 100, pos + 100))
            bg.append((c, pos - 1_200, pos - 1_000))
    for name, rows in (("tss.bed", tss), ("background.bed", bg)):
        with open(genome_dir / name, "w") as f:
            for c, s, e in sorted(rows):
                f.write(f"{c}\t{s}\t{e}\n")

    i7 = read_whitelist("i7.txt")
    i5 = read_whitelist("i5.txt")
    tgmt = read_whitelist("tgmt.txt")
    i7_wells, i5_wells = sorted(i7), sorted(i5)

    # Cells: (i7 well, i5 well, tgmt well, number of reads)
    barcodes = []
    used = set()
    for wells in SAMPLES.values():
        n = 0
        while n < CELLS_PER_SAMPLE:
            combo = (rng.choice(i7_wells), rng.choice(i5_wells), rng.choice(wells))
            if combo not in used:
                used.add(combo)
                barcodes.append((*combo, READS_PER_CELL))
                n += 1
    all_wells = [w for ws in SAMPLES.values() for w in ws]
    n = 0
    while n < BACKGROUND_BARCODES:
        combo = (rng.choice(i7_wells), rng.choice(i5_wells), rng.choice(all_wells))
        if combo not in used:
            used.add(combo)
            barcodes.append((*combo, READS_PER_BACKGROUND))
            n += 1

    # Weighted towards nuclear chromosomes; a few reads on chrM
    chrom_names = list(CHROMS)
    chrom_weights = [CHROMS[c] for c in chrom_names]

    records = []
    read_id = 0
    for w7, w5, wt, nreads in barcodes:
        for _ in range(nreads):
            chrom = rng.choices(chrom_names, chrom_weights)[0]
            frag_len = rng.randint(150, 300)
            start = rng.randint(0, CHROMS[chrom] - frag_len)
            frag = genome[chrom][start : start + frag_len]
            if rng.random() < 0.5:
                frag = revcomp(frag)
            conv = bisulfite(frag, rng)
            r2_gen = conv[:READ_LEN_GENOMIC]
            r1_gen = revcomp(conv[-READ_LEN_GENOMIC:])
            read_id += 1
            name = f"SYN:1:FC:1:1:{read_id}:1"
            records.append(
                (
                    fastq_record(f"{name} 1:N:0:1", R1_ADAPTER + r1_gen),
                    fastq_record(f"{name} 2:N:0:1", tgmt[wt] + TN5_ADAPTER + r2_gen),
                    fastq_record(f"{name} 1:N:0:1", i7[w7]),
                    fastq_record(f"{name} 2:N:0:1", i5[w5]),
                )
            )
    rng.shuffle(records)

    prefix = fastq_dir / "ScaleMethyl_S1_L001"
    # mtime=0 keeps the gzip files byte-identical between runs
    handles = [
        gzip.GzipFile(f"{prefix}_{r}_001.fastq.gz", "wb", mtime=0) for r in ("R1", "R2", "I1", "I2")
    ]
    for rec in records:
        for h, r in zip(handles, rec):
            h.write(r.encode())
    for h in handles:
        h.close()
    print(f"Wrote {len(records)} read pairs for {len(barcodes)} barcode combinations")


if __name__ == "__main__":
    main()
