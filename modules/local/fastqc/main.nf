// Run FastQC on the input (or bcl-convert generated) fastq files
process FASTQC {
    tag "${fastq.name}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path fastq
    path adapters

    output:
    path "fastqc/*.html", emit: html
    tuple val("${task.process}"), val('fastqc'), eval("fastqc --version | sed 's/FastQC v//'"), emit: versions_fastqc, topic: versions

    script:
    """
    mkdir -p fastqc
    fastqc --adapters ${adapters} -o fastqc ${fastq} --threads ${task.cpus} -f fastq
    """
}
