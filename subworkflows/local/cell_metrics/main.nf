//
// Cells and metrics:
//   1. Cell calling and per-cell metrics per sample (GENERATE_METRICS)
//   2. TSS enrichment per sample and Tn5 well (not with --skip_tss_enrich)
//   3. Library metrics: the metrics of all samples of a library, in sample order
//

include { GENERATE_METRICS          } from '../../../modules/local/generate_metrics'
include { TSS_ENRICH                } from '../../../modules/local/tss_enrich'
include { COMBINED_GENERATE_METRICS } from '../../../modules/local/combined_generate_metrics'

workflow CELL_METRICS {

    take:
    ch_merged_stats        // channel: [ meta, cell_stats.csv, cellInfo.csv, threshold ] per sample
    ch_fragment_hist       // channel: [ meta, fragment_hist.csv ]
    ch_dedup_stats         // channel: [ meta, dedup_stats.csv ]
    ch_demux_metrics       // channel: [ [ id: libName ], metrics.json or [] ]
    ch_trim_map_stats      // channel: [ meta, mapping_stats.csv, trimming_stats.csv ]
    ch_dedup_bam           // channel: [ meta, dedup.bam ] per sample and Tn5 well
    ch_samples             // channel: [ map ] one per sample, from the samplesheet
    lib_json               // path: library structure definition (.json)
    tss_bed                // channel: path(TSS windows)
    background_bed         // channel: path(background windows)

    main:
    //
    // 1. Cell calling and per-cell metrics
    //
    // [ meta, cell_stats, cellInfo, threshold, mapping_stats, trimming_stats ]
    GENERATE_METRICS(ch_merged_stats.join(ch_trim_map_stats), lib_json.getParent(), lib_json.getName())

    // [ meta, allCells, fragment_hist, dedup_stats, mapping_stats, trimming_stats ]
    def ch_report_stats = GENERATE_METRICS.out.all_cells
        .join(ch_fragment_hist)
        .join(ch_dedup_stats)
        .join(ch_trim_map_stats)

    //
    // 2. TSS enrichment per sample and Tn5 well
    //
    // [ [ id: sample ], [ tss_enrich.csv ] ] (empty list without TSS enrichment)
    def ch_tss_by_sample = channel.empty()
    if (!params.skip_tss_enrich) {
        // [ well meta, allCells, dedup.bam ]
        def ch_tss_input = GENERATE_METRICS.out.all_cells
            .combine(ch_dedup_bam.map { meta, bam -> [[id: meta.sample], meta, bam] }, by: 0)
            .map { _sample, allCells, meta, bam -> [meta, allCells, bam] }
        TSS_ENRICH(ch_tss_input, tss_bed, background_bed)
        // Sorted by file name: the list order is part of the task hash of the consumers (-resume)
        ch_tss_by_sample = TSS_ENRICH.out.enrich
            .filter { _meta, csv -> csv.size() > 1 }
            .map { meta, csv -> [[id: meta.sample], csv] }
            .groupTuple(sort: { a, b -> a.name <=> b.name })
    } else {
        ch_tss_by_sample = ch_samples.map { row -> [[id: row.sample], []] }
    }

    // [ meta, allCells, fragment_hist, dedup_stats, mapping_stats, trimming_stats, tss_enrich, libName, barcodes ]
    def ch_report_input = ch_report_stats
        .join(ch_tss_by_sample)
        .join(ch_samples.map { row -> [[id: row.sample], row.libName, row.barcodes] })

    //
    // 3. Combine the metrics of all samples of a library
    //
    def ch_sample_lib = ch_samples.map { row -> [[id: row.sample], row.libName] }
    // The files are sorted by sample name so that the samples are always in the same order
    // in the library metrics and report
    // [ [ id: libName ], [ allCells.csv of all samples ] ]
    def ch_all_cells_by_lib = ch_sample_lib
        .join(GENERATE_METRICS.out.all_cells)
        .groupTuple(by: 1)
        .map { samples, libName, allCells -> [[id: libName], sortBySample(samples, allCells)] }
    // [ [ id: libName ], [ passingCellSummaryStats.csv of all samples ] ]
    def ch_passing_stats_by_lib = ch_sample_lib
        .join(GENERATE_METRICS.out.passing_cell_stats)
        .groupTuple(by: 1)
        .map { samples, libName, stats -> [[id: libName], sortBySample(samples, stats)] }
    // [ [ id: libName ], [ allCells.csv ], [ passingCellSummaryStats.csv ], metrics.json ]
    def ch_library_stats = ch_all_cells_by_lib
        .join(ch_passing_stats_by_lib)
        .join(ch_demux_metrics)

    // [ [ id: libName ], [ tss_enrich.csv of all samples ] ] (empty list without TSS enrichment)
    def ch_tss_by_lib = ch_sample_lib
        .join(ch_tss_by_sample)
        .groupTuple(by: 1)
        .map { samples, libName, tss -> [[id: libName], sortBySample(samples, tss).flatten()] }
    // [ [ id: libName ], [ allCells.csv ], [ passingCellSummaryStats.csv ], metrics.json, [ tss_enrich.csv ] ]
    def ch_combined_metrics_input = ch_library_stats
        .join(ch_tss_by_lib, remainder: true)
        .map { meta, allCells, stats, demux, tss -> [meta, allCells, stats, demux, tss ?: []] }

    COMBINED_GENERATE_METRICS(ch_combined_metrics_input, lib_json.getParent(), lib_json.getName(), workflow.manifest.version)

    emit:
    all_cells          = GENERATE_METRICS.out.all_cells           // channel: [ meta, allCells.csv ]
    report_input       = ch_report_input                          // channel: input of the sample report
    passing_cell_stats = GENERATE_METRICS.out.passing_cell_stats  // channel: [ meta, passingCellSummaryStats.csv ]
    csv_folder         = GENERATE_METRICS.out.csv_folder          // channel: [ meta, csv/ ]
    combined_csv       = COMBINED_GENERATE_METRICS.out.csv_folder // channel: [ [ id: libName ], csv/ ]
    library_stats      = ch_library_stats                         // channel: [ [ id: libName ], [ allCells ], [ passing stats ], metrics.json ]
}

//
// Files of a library ordered by the name of their sample (samples: list of sample meta maps)
//
def sortBySample(samples, files) {
    return [samples, files].transpose().sort { pair -> pair[0].id }.collect { pair -> pair[1] }
}
