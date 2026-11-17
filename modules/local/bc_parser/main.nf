// Demultiplex fastq files by sample (and Tn5 well) with barcode error correction
process BC_PARSER {
    tag "${lib_name}"
    label 'process_medium'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path samples_csv
    path lib_struct_dir // Directory containing the library structure definition (barcode lists are loaded from here)
    val lib_struct_name // Filename of the library structure definition .json
    tuple val(lib_name), val(matching_key), path(fastqs), val(fastq_num)

    output:
    tuple val(lib_name), path("*.demux/*_S[1-9]*_R1*.fastq.gz"), emit: read1_fastq
    tuple val(lib_name), path("*.demux/*_S[1-9]*_R2*.fastq.gz"), emit: read2_fastq
    path "*.demux/*_S0_*.fastq.gz"                             , emit: unknown, optional: true
    path "*.demux/*.tsv"                                       , emit: barcode_counts
    tuple val(lib_name), path("*.demux/metrics.json")          , emit: metrics
    tuple val("${task.process}"), val('bc_parser'), eval("bc_parser --version | sed 's/bcParser //'"), emit: versions_bc_parser, topic: versions

    script:
    // With --split_fastq each bc_parser job gets a unique fastq number (ext.prefix in conf/modules.config)
    def prefix = task.ext.prefix ?: "${lib_name}.demux"
    """
    bc_parser -v --write-fastq --demux ${samples_csv} --lib-name ${lib_name} --reads ${fastqs.join(" ")} --lib-struct ${lib_struct_dir}/${lib_struct_name} --out ${prefix} --fastq-num ${fastq_num} --write_barcode_sequence
    """
}
