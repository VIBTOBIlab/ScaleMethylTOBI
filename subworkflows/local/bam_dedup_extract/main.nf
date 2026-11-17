//
// Deduplicate aligned reads per cell and extract the methylation calls
//

include { SC_DEDUP    } from '../../../modules/local/sc_dedup'
include { MET_EXTRACT } from '../../../modules/local/met_extract'

workflow BAM_DEDUP_EXTRACT {

    take:
    ch_bam      // channel: [ meta, bam ] aligned reads per sample and Tn5 well
    ch_ref      // channel: [ bwa-meth index directory, reference fasta name ]
    filter_chrs // channel: path(chromosome labels used by sc_dedup)

    main:
    SC_DEDUP(ch_bam, filter_chrs)

    // Skip methylation extraction for wells without passing reads
    MET_EXTRACT(
        SC_DEDUP.out.bam
            .join(SC_DEDUP.out.total_reads)
            .filter { _meta, _bam, totalReads -> totalReads as int > 0 },
        ch_ref
    )

    // Group the per-well files by sample: [ [ id: sample ], [ files ] ]
    def ch_cell_stats = SC_DEDUP.out.cell_stats
        .map { meta, f -> [[id: meta.sample], f] }
        .groupTuple()
    def ch_fragment_hist = SC_DEDUP.out.fragment_hist
        .map { meta, f -> [[id: meta.sample], f] }
        .groupTuple()
    def ch_cell_info = MET_EXTRACT.out.cell_info
        .map { meta, f -> [[id: meta.sample], f] }
        .groupTuple()
    def ch_dedup_stats = SC_DEDUP.out.dedup_stats
        .map { meta, f -> [[id: meta.sample], f] }
        .groupTuple()

    emit:
    reads_frags = ch_cell_stats.join(ch_fragment_hist) // channel: [ meta, [ cell_stats.tsv ], [ fragment_hist.tsv ] ]
    cell_info   = ch_cell_info                         // channel: [ meta, [ cellInfo.txt ] ]
    dedup_stats = ch_dedup_stats                       // channel: [ meta, [ dedup_stats.tsv ] ]
    dedup_bam   = SC_DEDUP.out.bam                     // channel: [ meta, dedup.bam ] per sample and Tn5 well
    met_cg      = MET_EXTRACT.out.met_cg               // channel: [ meta, met_CG.parquet ] per sample and Tn5 well
    met_ch      = MET_EXTRACT.out.met_ch               // channel: [ meta, met_CH.parquet ] per sample and Tn5 well
}
