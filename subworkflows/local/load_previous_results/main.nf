//
// Load the outputs of previous runs:
//   1. Per-sample metrics, from --previous_outdir, or combined from the runs in the resultDir
//      column of the samplesheet (--merge_runs)
//   2. With --start_post_extraction: the cell metadata and the methylation calls per Tn5 well,
//      to regenerate the matrices and coverage files
//

include { COMBINE_BARCODE_CSVS } from '../../../modules/local/combine_barcode_csvs'
include { COMBINE_SUMMARY_CSVS } from '../../../modules/local/combine_summary_csvs'

workflow LOAD_PREVIOUS_RESULTS {

    take:
    ch_samples // channel: [ map ] one per sample, from the samplesheet

    main:
    //
    // 1. Per-sample metrics
    //
    def ch_metric_input = channel.empty()
    def ch_fragment_hist = channel.empty()
    def ch_dedup_stats = channel.empty()
    def ch_tss_enrich = channel.empty()

    if (params.merge_runs) {
        // Merge the metrics of the runs listed in the resultDir column of samples.csv
        // [ sample, threshold, [ cellInfo ], [ cell_stats ], [ tss_enrich ] ]
        def ch_cell_infos = ch_samples
            .map { row ->
                def dir = "${row.resultDir}/metrics_for_reporting"
                [
                    [id: row.sample],
                    toIntOr0(row.threshold),
                    file("${dir}/${row.sample}.cellInfo.csv", checkIfExists: true),
                    file("${dir}/${row.sample}.cell_stats.csv", checkIfExists: true),
                    file("${dir}/${row.sample}.tss_enrich.csv"),
                ]
            }
            .groupTuple()
            .map { sample, thresholds, cellInfos, cellStats, tssEnrich -> [sample, thresholds[0], cellInfos, cellStats, tssEnrich] }
        COMBINE_BARCODE_CSVS(ch_cell_infos)

        // [ sample, threshold, [ dedup_stats ], [ fragment_hist ] ]
        def ch_all_dedup_stats = ch_samples
            .map { row ->
                def dir = "${row.resultDir}/metrics_for_reporting"
                [
                    [id: row.sample],
                    toIntOr0(row.threshold),
                    file("${dir}/${row.sample}.dedup_stats.csv", checkIfExists: true),
                    file("${dir}/${row.sample}.fragment_hist.csv", checkIfExists: true),
                ]
            }
            .groupTuple()
            .map { sample, thresholds, dedupStats, fragHists -> [sample, thresholds[0], dedupStats, fragHists] }
        COMBINE_SUMMARY_CSVS(ch_all_dedup_stats)

        ch_metric_input = COMBINE_BARCODE_CSVS.out.csvs.map { sample, threshold, cellInfo, cellStats, _tss -> [sample, cellStats, cellInfo, threshold] }
        ch_fragment_hist = COMBINE_SUMMARY_CSVS.out.csvs.map { sample, _threshold, _dedup, fragHist -> [sample, fragHist] }
        ch_dedup_stats = COMBINE_SUMMARY_CSVS.out.csvs.map { sample, _threshold, dedup, _fragHist -> [sample, dedup] }
        ch_tss_enrich = COMBINE_BARCODE_CSVS.out.csvs.map { sample, _threshold, _cellInfo, _cellStats, tss -> [sample, tss] }
    } else {
        // Use the metrics of the previous output directory (or of the current one)
        def dir = "${params.previous_outdir ?: params.outdir}/metrics_for_reporting"
        ch_metric_input = ch_samples.map { row ->
            [[id: row.sample], file("${dir}/${row.sample}.cell_stats.csv"), file("${dir}/${row.sample}.cellInfo.csv"), toIntOr0(row.threshold)]
        }
        ch_fragment_hist = ch_samples.map { row -> [[id: row.sample], file("${dir}/${row.sample}.fragment_hist.csv")] }
        ch_dedup_stats = ch_samples.map { row -> [[id: row.sample], file("${dir}/${row.sample}.dedup_stats.csv")] }
        ch_tss_enrich = ch_samples.map { row -> [[id: row.sample], file("${dir}/${row.sample}.tss_enrich.csv")] }
    }

    // The original run may have been run with --skip_tss_enrich
    ch_tss_enrich = ch_tss_enrich.map { meta, tss -> [meta, tss.exists() ? tss : []] }

    // bc_parser metrics may be missing from the previous output directory (e.g. when starting from BAM files):
    // they are not used, see the original report for the barcode metrics
    def ch_demux_metrics = ch_samples.map { row -> [[id: row.libName], []] }.unique()

    //
    // 2. Restart after methylation extraction: load the cell metadata and the methylation calls
    //
    def ch_all_cells = channel.empty()
    def ch_met_cg = channel.empty()
    def ch_met_ch = channel.empty()
    if (params.start_post_extraction) {
        // [ sample, result directory ]
        def ch_result_dirs = params.previous_outdir
            ? ch_samples.map { row -> [row.sample, params.previous_outdir] }
            : ch_samples.map { row -> [row.sample, row.resultDir] }
        // With --previous_outdir CH calls are not loaded with --skip_ch_context
        def contexts = (params.previous_outdir && params.skip_ch_context) ? ['CG'] : ['CG', 'CH']

        // [ meta, [ allCells.csv ] ]
        ch_all_cells = ch_result_dirs
            .map { sample, dir -> [[id: sample], file("${dir}/samples/${sample}.allCells.csv", checkIfExists: true)] }
            .groupTuple()

        // [ well meta, [ parquet files ], context ]
        def ch_met = ch_result_dirs
            .flatMap { sample, dir ->
                def wells = file("${dir}/samples/${sample}.allCells.csv", checkIfExists: true)
                    .splitCsv(header: true, strip: true)
                    .collect { cell -> cell.tgmt_well }
                    .unique()
                wells.collect { well -> [[id: "${sample}.${well}".toString(), sample: sample, well: well], "${dir}/matrix_generation/${sample}.${well}.met_"] }
            }
            .combine(channel.fromList(contexts))
            .map { meta, prefix, context -> [meta, file("${prefix}${context}.parquet"), context] }
            .filter { _id, parquet, _context -> parquet.exists() }
            .groupTuple(by: [0, 2])
            .branch { _id, _parquets, context ->
                cg: context == 'CG'
                ch: context == 'CH'
            }
        ch_met_cg = ch_met.cg.map { meta, parquets, _context -> [meta, parquets] }
        ch_met_ch = ch_met.ch.map { meta, parquets, _context -> [meta, parquets] }
    }

    emit:
    metric_input  = ch_metric_input  // channel: [ meta, cell_stats.csv, cellInfo.csv, threshold ] per sample
    fragment_hist = ch_fragment_hist // channel: [ meta, fragment_hist.csv ]
    dedup_stats   = ch_dedup_stats   // channel: [ meta, dedup_stats.csv ]
    tss_enrich    = ch_tss_enrich    // channel: [ meta, tss_enrich.csv or [] ]
    demux_metrics = ch_demux_metrics // channel: [ [ id: libName ], [] ]
    all_cells     = ch_all_cells     // channel: [ meta, [ allCells.csv ] ]
    met_cg        = ch_met_cg        // channel: [ well meta, [ met_CG.parquet ] ]
    met_ch        = ch_met_ch        // channel: [ well meta, [ met_CH.parquet ] ]
}

//
// Integer value of a samples.csv column; 0 for missing or non-integer values
//
def toIntOr0(str) {
    return (str != null && str.isInteger()) ? (str as int) : 0
}
