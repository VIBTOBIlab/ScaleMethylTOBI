//
// Generate the binned methylation matrices and the per-cell methylation coverage files
// (ALLCools .allc, Bismark .cov and Amethyst .h5) for all passing cells
//

include { CREATE_MTX as CREATE_MTX_CG } from '../../../modules/local/create_mtx'
include { CREATE_MTX as CREATE_MTX_CH } from '../../../modules/local/create_mtx'
include { MERGE_MTX as MERGE_MTX_CG   } from '../../../modules/local/merge_mtx'
include { MERGE_MTX as MERGE_MTX_CH   } from '../../../modules/local/merge_mtx'
include { CREATE_ALLC                 } from '../../../modules/local/create_allc'
include { CREATE_BISMARK              } from '../../../modules/local/create_bismark'
include { CREATE_AMETHYST             } from '../../../modules/local/create_amethyst'

workflow MATRIX_GENERATION {

    take:
    ch_all_cells // channel: [ sample, [ allCells.csv ] ] cell metadata
    ch_met_cg    // channel: [ sample.well, met_CG.parquet(s) ] CG methylation calls per Tn5 well
    ch_met_ch    // channel: [ sample.well, met_CH.parquet(s) ] CH methylation calls per Tn5 well
    ch_tiles_cg  // channel: path(bed) genome bins for the CG matrix
    ch_tiles_ch  // channel: path(bed) genome bins for the CH matrix

    main:
    // [ sample, sample.well, allCells, met_CG ]
    def ch_cg_pass = ch_all_cells
        .combine(
            ch_met_cg.map { id, met -> [id.tokenize('.')[0], id, met] },
            by: 0
        )
        .map { sample, allCells, id, met -> [sample, id, allCells, met] }

    def ch_cg_mtx = channel.empty()
    def ch_cg_mtx_barcodes = channel.empty()
    if (params.window_matrix_out) {
        CREATE_MTX_CG(ch_tiles_cg, ch_cg_pass)
        // Combine the per-well matrices per sample, with barcodes in the same order as the cell metadata
        def ch_cg_mtx_per_sample = CREATE_MTX_CG.out.mtx
            .map { id, mtx, barcodes, features -> [id.tokenize('.')[0], mtx, barcodes, features] }
            .groupTuple()
            .map { sample, mtx, barcodes, features -> [sample, mtx.flatten(), barcodes.flatten(), features.flatten()] }
            .join(ch_all_cells)
        MERGE_MTX_CG(ch_cg_mtx_per_sample)
        ch_cg_mtx = MERGE_MTX_CG.out.mtx
        ch_cg_mtx_barcodes = MERGE_MTX_CG.out.barcodes
    }

    def ch_ch_pass = channel.empty()
    if (params.calculate_ch) {
        // [ sample, sample.well, allCells, met_CH ]
        ch_ch_pass = ch_all_cells
            .combine(
                ch_met_ch.map { id, met -> [id.tokenize('.')[0], id, met] },
                by: 0
            )
            .map { sample, allCells, id, met -> [sample, id, allCells, met] }

        if (params.window_matrix_out) {
            CREATE_MTX_CH(ch_tiles_ch, ch_ch_pass)
            def ch_ch_mtx_per_sample = CREATE_MTX_CH.out.mtx
                .map { id, mtx, barcodes, features -> [id.tokenize('.')[0], mtx, barcodes, features] }
                .groupTuple()
                .map { sample, mtx, barcodes, features -> [sample, mtx.flatten(), barcodes.flatten(), features.flatten()] }
                .join(ch_all_cells)
            MERGE_MTX_CH(ch_ch_mtx_per_sample)
        }
    }

    //
    // Per-cell methylation coverage files
    //
    // [ sample, sample.well, allCells, met, context ]
    def ch_met_context = ch_cg_pass
        .map { sample, id, allCells, met -> [sample, id, allCells, met, 'CG'] }
        .concat(ch_ch_pass.map { sample, id, allCells, met -> [sample, id, allCells, met, 'CH'] })

    if (params.allc_out) {
        CREATE_ALLC(ch_met_context)
    }
    if (params.cov_out) {
        CREATE_BISMARK(ch_met_context)
    }
    if (params.amethyst_out) {
        // [ sample, sample.well, allCells, met_CG, met_CH or [] ]
        def ch_amethyst_input = params.calculate_ch
            ? ch_cg_pass.join(ch_ch_pass, by: [0, 1, 2], failOnDuplicate: true, failOnMismatch: true)
            : ch_cg_pass.map { sample, id, allCells, met -> [sample, id, allCells, met, []] }
        CREATE_AMETHYST(ch_amethyst_input)
    }

    emit:
    cg_mtx          = ch_cg_mtx          // channel: [ sample, CG.score.mtx.gz ]
    cg_mtx_barcodes = ch_cg_mtx_barcodes // channel: [ sample, barcodes.tsv ]
}
