//
// Generate the html QC reports per sample and per library
//

include { GENERATE_SAMPLE_REPORT } from '../../../modules/local/generate_sample_report'
include { COMBINED_SAMPLE_REPORT } from '../../../modules/local/combined_sample_report'

workflow REPORTING {

    take:
    ch_report_input        // channel: [ sample, allCells, fragment_hist, dedup_stats, mapping_stats, trimming_stats, tss_enrich, libName, barcodes ]
    ch_passing_cell_stats  // channel: [ sample, passingCellSummaryStats.csv ]
    ch_csv_folder          // channel: [ sample, csv/ ] csv files for the sample plate plots
    ch_combined_csv        // channel: [ libName, csv/ ] csv files for the library plate plots
    ch_library_stats       // channel: [ libName, [ allCells ], [ passing stats ], metrics.json ]
    ch_cg_mtx              // channel: [ sample, CG.score.mtx.gz ] (only used with_matrix)
    ch_cg_mtx_barcodes     // channel: [ sample, barcodes.tsv ] (only used with_matrix)
    lib_json               // path: library structure definition (.json)
    trimming_and_mapping   // boolean: trimming and mapping statistics are available
    reporting_only         // boolean: only the reports are regenerated (--reporting_only)
    with_matrix            // boolean: the CG matrix is available (used to cluster cells in the report)

    main:
    def ch_sample_report_input = ch_report_input
        .join(ch_passing_cell_stats)
        .join(ch_csv_folder)
    ch_sample_report_input = with_matrix
        ? ch_sample_report_input.join(ch_cg_mtx).join(ch_cg_mtx_barcodes)
        : ch_sample_report_input.map { row -> row + [[], []] }

    GENERATE_SAMPLE_REPORT(
        ch_sample_report_input,
        lib_json.getParent(),
        lib_json.getName(),
        trimming_and_mapping,
        reporting_only,
        workflow.manifest.version
    )

    COMBINED_SAMPLE_REPORT(
        ch_library_stats.join(ch_combined_csv),
        lib_json.getParent(),
        lib_json.getName(),
        workflow.manifest.version
    )

    emit:
    sample_report  = GENERATE_SAMPLE_REPORT.out.report // channel: [ sample, report.html ]
    library_report = COMBINED_SAMPLE_REPORT.out.report // channel: [ libName, report.html ]
}
