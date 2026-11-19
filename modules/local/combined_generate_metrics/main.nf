// Generate the combined metrics of all samples of a library
process COMBINED_GENERATE_METRICS {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(all_cells), path(passing_cell_stats), path("demuxMetrics.json"), path(tss_enrich)
    path lib_struct_dir     // Directory containing the library structure definition
    val lib_struct_name     // Filename of the library structure definition .json
    val workflow_version

    output:
    tuple val(meta), path("${meta.id}/${meta.id}.combinedPassingCellStats.csv"), emit: combined_passing_stats
    tuple val(meta), path("${meta.id}/csv")                                       , emit: csv_folder
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def tss_opt = tss_enrich ? "--tss_enrich ${tss_enrich}" : ''
    """
    generate_combined_metrics.py --library_name ${meta.id} --out_dir ${meta.id} --all_cells ${all_cells} \
        --passing_cell_stats ${passing_cell_stats} --library_structure_json ${lib_struct_dir}/${lib_struct_name} --workflow_version ${workflow_version} ${tss_opt}
    """
}
