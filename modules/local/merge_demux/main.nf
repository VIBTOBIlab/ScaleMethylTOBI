// Merge the bc_parser metrics of all bc_parser jobs of a library
process MERGE_DEMUX {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path("demux_metrics*.json")
    path lib_struct_dir // Directory containing the library structure definition (barcode lists are loaded from here)
    val lib_struct_name // Filename of the library structure definition .json

    output:
    tuple val(meta), path("${meta.id}.metrics.json"), emit: barcode_metrics
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    merge_bc_parser_output.py --bc_jsons demux_metrics* --lib_json ${lib_struct_dir}/${lib_struct_name} --libName ${meta.id}
    """
}
