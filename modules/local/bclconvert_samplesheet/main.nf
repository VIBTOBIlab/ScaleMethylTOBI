// Create a bcl-convert samplesheet for the libraries in samples.csv
process BCLCONVERT_SAMPLESHEET {
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path samples_csv
    path lib_struct_dir // Directory containing the library structure definition (barcode lists are loaded from here)
    val lib_struct_name // Filename of the library structure definition .json
    path runinfo        // RunInfo.xml from the sequencer run folder (read lengths etc.)

    output:
    path "samplesheet.csv", emit: samplesheet
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    bcl_convert_sheet.py ${samples_csv} ${lib_struct_dir}/${lib_struct_name} ${runinfo} ${args} > samplesheet.csv
    """
}
