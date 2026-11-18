// Generate per-cell metrics used for reporting and call cells (thresholding)
process GENERATE_METRICS {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(cell_stats), path(cell_info_stats), val(threshold), path(mapping_stats), path(trimming_stats)
    path lib_struct_dir         // Directory containing the library structure definition
    val lib_struct_name         // Filename of the library structure definition .json
    val trimming_and_mapping    // Whether trimming and mapping statistics are available

    output:
    tuple val(meta), path("${meta.id}.allCells.csv")                               , emit: all_cells
    tuple val(meta), path("${meta.id}/csv/${meta.id}.passingCellSummaryStats.csv"), emit: passing_cell_stats
    tuple val(meta), path("${meta.id}.tss_enrich.csv")                            , emit: tss_enrich, optional: true
    tuple val(meta), path("${meta.id}/csv")                                        , emit: csv_folder
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    def stats_opts = trimming_and_mapping ? "--trimming_stats ${trimming_stats} --mapping_stats ${mapping_stats}" : ''
    """
    generate_metrics.py --sample_name ${meta.id} --threshold ${threshold} --cell_info ${cell_info_stats} --cell_stats ${cell_stats} \
        --library_structure_json ${lib_struct_dir}/${lib_struct_name} ${args} ${stats_opts}
    """
}
