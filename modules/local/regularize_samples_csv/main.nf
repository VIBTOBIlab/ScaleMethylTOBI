// Prepare samples.csv with defaults, rename legacy columns and validate barcode ranges
process REGULARIZE_SAMPLES_CSV {
    label 'process_single'
    cache 'deep'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path samples_csv, stageAs: 'samples.in.csv'
    val lib_struct_name // Filename of the library structure definition .json
    path lib_struct_dir // Directory containing the library structure definition (barcode lists are loaded from here)

    output:
    path "samples.csv"                                                                       , emit: csv
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    regularize_samples_csv.py samples.in.csv --libraryStruct ${lib_struct_dir}/${lib_struct_name} ${args} > samples.csv
    """
}
