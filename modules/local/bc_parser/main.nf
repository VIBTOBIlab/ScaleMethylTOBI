// Demultiplex the fastq files of one library and sequencing run by sample (and Tn5 well)
// with barcode error correction
process BC_PARSER {
    tag "${meta.id}"
    label 'process_medium'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    val samples_csv     // Sample table as CSV text (sample, barcodes, libName, split)
    path lib_struct_dir // Directory containing the library structure definition (barcode lists are loaded from here)
    val lib_struct_name // Filename of the library structure definition .json
    tuple val(meta), path(read1, stageAs: 'fastq/R1/*'), path(read2, stageAs: 'fastq/R2/*'), path(index1, stageAs: 'fastq/I1/*'), path(index2, stageAs: 'fastq/I2/*')

    output:
    tuple val(meta), path("*.demux/*_S[1-9]*_R1*.fastq.gz"), emit: read1_fastq
    tuple val(meta), path("*.demux/*_S[1-9]*_R2*.fastq.gz"), emit: read2_fastq
    tuple val(meta), path("*.demux/*_S0_*.fastq.gz")       , emit: unknown, optional: true
    tuple val(meta), path("*.demux/*.tsv")                 , emit: barcode_counts
    tuple val(meta), path("*.demux/metrics.json")          , emit: metrics
    tuple val("${task.process}"), val('bc_parser'), eval("bc_parser --version | sed 's/bcParser //'"), emit: versions_bc_parser, topic: versions

    script:
    // Directory named after the library and the fastq set number (ext.prefix in conf/modules.config)
    def prefix = task.ext.prefix ?: "${meta.lib}.${meta.fastq_num}.demux"
    // bc_parser recognises the reads by the _R1_/_R2_/_I1_/_I2_ part of the file names
    def name = "${meta.lib}_S1_L001"
    def reads = ["I1": index1, "I2": index2, "R1": read1, "R2": read2].findAll { _read, fq -> fq }
    def links = reads.collect { read, fq -> "ln -s ${fq} ${name}_${read}_001.fastq.gz" }.join("\n    ")
    def files = reads.collect { read, _fq -> "${name}_${read}_001.fastq.gz" }.join(" ")
    """
    cat <<'END_OF_SAMPLES' > samples.csv
${samples_csv.trim()}
END_OF_SAMPLES
    ${links}
    bc_parser -v --write-fastq --demux samples.csv --lib-name ${meta.lib} --reads ${files} --lib-struct ${lib_struct_dir}/${lib_struct_name} --out ${prefix} --fastq-num ${meta.fastq_num} --write_barcode_sequence
    """
}
