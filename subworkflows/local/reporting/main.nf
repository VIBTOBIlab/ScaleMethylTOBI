//
// QC reports (html):
//   1. Sample report: cells, reads, methylation, TSS enrichment, clustering of the cells (with the
//      CG matrix)
//   2. Library report: all samples of a library
//

include { GENERATE_SAMPLE_REPORT } from '../../../modules/local/generate_sample_report'
include { COMBINED_SAMPLE_REPORT } from '../../../modules/local/combined_sample_report'

workflow REPORTING {

    take:
    ch_report_input        // channel: [ meta, allCells, fragment_hist, dedup_stats, mapping_stats, trimming_stats, tss_enrich, libName, barcodes ]
    ch_passing_cell_stats  // channel: [ meta, passingCellSummaryStats.csv ]
    ch_csv_folder          // channel: [ meta, csv/ ] csv files for the sample plate plots
    ch_combined_csv        // channel: [ [ id: libName ], csv/ ] csv files for the library plate plots
    ch_library_stats       // channel: [ [ id: libName ], [ allCells ], [ passing stats ], metrics.json ]
    ch_cg_mtx              // channel: [ meta, CG.score.mtx.gz ] (only used with_matrix)
    ch_cg_mtx_barcodes     // channel: [ meta, barcodes.tsv ] (only used with_matrix)
    lib_json               // path: library structure definition (.json)
    trimming_and_mapping   // boolean: trimming and mapping statistics are available
    reporting_only         // boolean: only the reports are regenerated (--reporting_only)
    with_matrix            // boolean: the CG matrix is available (used to cluster cells in the report)

    main:
    //
    // 1. Sample reports
    //
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

    //
    // 2. Library reports
    //
    COMBINED_SAMPLE_REPORT(
        ch_library_stats.join(ch_combined_csv),
        lib_json.getParent(),
        lib_json.getName(),
        workflow.manifest.version
    )

    emit:
    sample_report  = GENERATE_SAMPLE_REPORT.out.report // channel: [ meta, report.html ]
    library_report = COMBINED_SAMPLE_REPORT.out.report // channel: [ [ id: libName ], report.html ]
}
