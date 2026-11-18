//
// From alignments per sample and Tn5 well to methylation calls and per-sample statistics:
//   1. Deduplication per cell barcode (sc_dedup)
//   2. Methylation calls per cell (met_extract), for wells with passing reads
//   3. Per-sample statistics: the per-well files (and the trimming / alignment statistics,
//      when starting from fastq files) are merged per sample for the reports
//

include { SC_DEDUP    } from '../../../modules/local/sc_dedup'
include { MET_EXTRACT } from '../../../modules/local/met_extract'
include { MERGE_STATS } from '../../../modules/local/merge_stats'

workflow BAM_DEDUP_EXTRACT {

    take:
    ch_bam               // channel: [ meta, bam ] aligned reads per sample and Tn5 well
    ch_ref               // channel: [ bwa-meth index directory, reference fasta name ]
    filter_chrs          // channel: path(chromosome labels used by sc_dedup)
    ch_align_logs        // channel: [ meta, bwa_meth.log ] per sample and Tn5 well (empty without trimming_and_mapping)
    ch_trim_stats        // channel: [ meta, trim_stats.json ] per sample and Tn5 well (empty without trimming_and_mapping)
    trimming_and_mapping // boolean: trimming and alignment statistics are available (start from fastq files)

    main:
    //
    // 1. Deduplicate reads per cell barcode
    //
    SC_DEDUP(ch_bam, filter_chrs)

    //
    // 2. Extract the methylation calls (skip wells without passing reads)
    //
    MET_EXTRACT(
        SC_DEDUP.out.bam
            .join(SC_DEDUP.out.total_reads)
            .filter { _meta, _bam, totalReads -> totalReads as int > 0 },
        ch_ref
    )

    //
    // 3. Merge the per-well statistics of each sample
    //
    // [ [ id: sample ], [ cell_stats ], [ fragment_hist ], [ cellInfo ], [ dedup_stats ] ]
    def ch_well_stats = bySample(SC_DEDUP.out.cell_stats)
        .join(bySample(SC_DEDUP.out.fragment_hist))
        .join(bySample(MET_EXTRACT.out.cell_info))
        .join(bySample(SC_DEDUP.out.dedup_stats))
    // + [ [ aligner logs ], [ trimming stats ] ] (empty lists when starting from BAM files)
    def ch_merge_input = trimming_and_mapping
        ? ch_well_stats.join(bySample(ch_align_logs)).join(bySample(ch_trim_stats))
        : ch_well_stats.map { row -> row + [[], []] }
    MERGE_STATS(ch_merge_input)

    emit:
    merged_stats               = MERGE_STATS.out.merged_stats               // channel: [ meta, cell_stats.csv, cellInfo.csv ] per sample
    fragment_hist              = MERGE_STATS.out.fragment_hist              // channel: [ meta, fragment_hist.csv ]
    dedup_stats                = MERGE_STATS.out.dedup_stats                // channel: [ meta, dedup_stats.csv ]
    trimming_and_mapping_stats = MERGE_STATS.out.trimming_and_mapping_stats // channel: [ meta, mapping_stats.csv, trimming_stats.csv ]
    dedup_bam                  = SC_DEDUP.out.bam                           // channel: [ meta, dedup.bam ] per sample and Tn5 well
    met_cg                     = MET_EXTRACT.out.met_cg.groupTuple()        // channel: [ meta, [ met_CG.parquet ] ] per sample and Tn5 well
    met_ch                     = MET_EXTRACT.out.met_ch.groupTuple()        // channel: [ meta, [ met_CH.parquet ] ] per sample and Tn5 well
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Group per-well files by sample: [ well meta, file ] -> [ [ id: sample ], [ files ] ]
//
def bySample(ch_files) {
    return ch_files
        .map { meta, f -> [[id: meta.sample], f] }
        .groupTuple()
}
