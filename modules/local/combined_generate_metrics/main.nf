// Generate the combined metrics of all samples of a library
process COMBINED_GENERATE_METRICS {
    tag "${lib_name}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(lib_name), path(all_cells), path(passing_cell_stats), path("demuxMetrics.json")
    path lib_struct_dir     // Directory containing the library structure definition
    val lib_struct_name     // Filename of the library structure definition .json
    val workflow_version

    output:
    tuple val(lib_name), path("${lib_name}/${lib_name}.combinedPassingCellStats.csv"), emit: combined_passing_stats
    tuple val(lib_name), path("${lib_name}/csv")                                       , emit: csv_folder
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    generate_combined_metrics.py --library_name ${lib_name} --out_dir ${lib_name} --all_cells ${all_cells} \
        --passing_cell_stats ${passing_cell_stats} --library_structure_json ${lib_struct_dir}/${lib_struct_name} --workflow_version ${workflow_version}
    """
}
