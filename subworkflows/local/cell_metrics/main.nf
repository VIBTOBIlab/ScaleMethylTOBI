//
// Call cells, compute per-cell metrics (incl. TSS enrichment) and combine them per library
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
    ch_trim_map_stats      // channel: [ meta, mapping_stats.csv, trimming_stats.csv ] (only used with trimming_and_mapping)
    ch_tss_enrich          // channel: [ meta, tss_enrich.csv or [] ] from a previous run (only used with from_previous_run)
    ch_dedup_bam           // channel: [ meta, dedup.bam ] per sample and Tn5 well (only used without from_previous_run)
    ch_samples             // channel: [ map ] rows of the regularized samples.csv
    lib_json               // path: library structure definition (.json)
    tss_bed                // channel: path(TSS windows)
    background_bed         // channel: path(background windows)
    trimming_and_mapping   // boolean: trimming and mapping statistics are available
    from_previous_run      // boolean: metrics are regenerated from the outputs of a previous run

    main:
    // [ meta, cell_stats, cellInfo, threshold, mapping_stats, trimming_stats ]
    def ch_metrics_input = trimming_and_mapping
        ? ch_merged_stats.join(ch_trim_map_stats)
        : ch_merged_stats.map { meta, cellStats, cellInfo, threshold -> [meta, cellStats, cellInfo, threshold, [], []] }

    GENERATE_METRICS(ch_metrics_input, lib_json.getParent(), lib_json.getName(), trimming_and_mapping)

    // [ meta, allCells, fragment_hist, dedup_stats, mapping_stats, trimming_stats ]
    def ch_report_stats = trimming_and_mapping
        ? GENERATE_METRICS.out.all_cells.join(ch_fragment_hist).join(ch_dedup_stats).join(ch_trim_map_stats)
        : GENERATE_METRICS.out.all_cells.join(ch_fragment_hist).join(ch_dedup_stats).map { row -> row + [[], []] }

    //
    // TSS enrichment per sample and Tn5 well
    //
    def ch_tss_by_sample = ch_tss_enrich
    if (!from_previous_run) {
        if (params.run_tss_enrich) {
            // [ well meta, allCells, dedup.bam ]
            def ch_tss_input = GENERATE_METRICS.out.all_cells
                .combine(ch_dedup_bam.map { meta, bam -> [[id: meta.sample], meta, bam] }, by: 0)
                .map { _sample, allCells, meta, bam -> [meta, allCells, bam] }
            TSS_ENRICH(ch_tss_input, tss_bed, background_bed)
            ch_tss_by_sample = TSS_ENRICH.out.enrich
                .filter { _meta, csv -> csv.size() > 1 }
                .map { meta, csv -> [[id: meta.sample], csv] }
                .groupTuple()
        } else {
            ch_tss_by_sample = ch_samples.map { row -> [[id: row.sample], []] }
        }
    }

    // [ meta, allCells, fragment_hist, dedup_stats, mapping_stats, trimming_stats, tss_enrich, libName, barcodes ]
    def ch_report_input = ch_report_stats
        .join(ch_tss_by_sample)
        .join(ch_samples.map { row -> [[id: row.sample], row.libName, row.barcodes] })

    //
    // Combine the metrics of all samples of a library
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

    COMBINED_GENERATE_METRICS(ch_library_stats, lib_json.getParent(), lib_json.getName(), workflow.manifest.version)

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
