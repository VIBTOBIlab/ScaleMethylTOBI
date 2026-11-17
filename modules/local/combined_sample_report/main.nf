// Generate the html QC report of a library (all samples)
process COMBINED_SAMPLE_REPORT {
    tag "${lib_name}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(lib_name), path(all_cells), path(passing_cell_stats), path("demuxMetrics.json"), path(combined_csv_folder)
    path lib_struct_dir     // Directory containing the library structure definition
    val lib_struct_name     // Filename of the library structure definition .json
    val workflow_version

    output:
    tuple val(lib_name), path("${lib_name}/${lib_name}.report.html"), emit: report
    tuple val(lib_name), path("${lib_name}/png")                     , emit: png
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    export DATAPANE_CDN_BASE="https://d3j2ibc7el7s1k.cloudfront.net/v0.17.0"
    export TMPDIR=\$(mktemp -p \$(pwd) -d)
    combined_sample_report.py --library_name ${lib_name} --out_dir ${lib_name} --all_cells ${all_cells} \
        --passing_cell_stats ${passing_cell_stats} --library_structure_json ${lib_struct_dir}/${lib_struct_name} --workflow_version ${workflow_version} \
        --csv_folder ${combined_csv_folder}
    """
}
