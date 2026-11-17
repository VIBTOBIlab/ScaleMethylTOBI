//
// Deduplicate aligned reads per cell and extract the methylation calls
//

include { SC_DEDUP    } from '../../../modules/local/sc_dedup'
include { MET_EXTRACT } from '../../../modules/local/met_extract'

workflow BAM_DEDUP_EXTRACT {

    take:
    ch_bam // channel: [ sample.well, bam ] aligned reads
    genome // map: reference genome definition

    main:
    SC_DEDUP(ch_bam, genome.filter_chrs)

    // Skip methylation extraction for wells without passing reads
    MET_EXTRACT(
        SC_DEDUP.out.bam
            .join(SC_DEDUP.out.total_reads)
            .filter { _sample, _bam, totalReads -> totalReads as int > 0 },
        genome.bwa_index,
        genome.ref_fasta
    )

    // Group the per-well files by sample (the part of the file name before the first '.')
    def ch_cell_stats = SC_DEDUP.out.cell_stats
        .map { _id, f -> [sampleOf(f), f] }
        .groupTuple()
    def ch_fragment_hist = SC_DEDUP.out.fragment_hist
        .map { _id, f -> [sampleOf(f), f] }
        .groupTuple()
    def ch_cell_info = MET_EXTRACT.out.cell_info
        .map { _id, f -> [sampleOf(f), f] }
        .groupTuple()
    def ch_dedup_stats = SC_DEDUP.out.dedup_stats
        .map { _id, f -> [sampleOf(f), f] }
        .groupTuple()

    emit:
    reads_frags = ch_cell_stats.join(ch_fragment_hist) // channel: [ sample, [ cell_stats.tsv ], [ fragment_hist.tsv ] ]
    cell_info   = ch_cell_info                         // channel: [ sample, [ cellInfo.txt ] ]
    dedup_stats = ch_dedup_stats                       // channel: [ sample, [ dedup_stats.tsv ] ]
    dedup_bam   = SC_DEDUP.out.bam                     // channel: [ sample.well, dedup.bam ]
    met_cg      = MET_EXTRACT.out.met_cg               // channel: [ sample.well, met_CG.parquet ]
    met_ch      = MET_EXTRACT.out.met_ch               // channel: [ sample.well, met_CH.parquet ]
}

//
// Sample name of a per-well file: the part of the file name before the first '.'
//
def sampleOf(f) {
    return f.getName().tokenize('.')[0]
}
