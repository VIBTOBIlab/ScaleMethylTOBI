// Run FastQC on an input fastq file
process FASTQC {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(fastq, stageAs: 'input/*')
    path adapters

    output:
    tuple val(meta), path("fastqc/*.html"), emit: html
    tuple val(meta), path("fastqc/*.zip") , emit: zip
    tuple val("${task.process}"), val('fastqc'), eval("fastqc --version | sed 's/FastQC v//'"), emit: versions_fastqc, topic: versions

    script:
    // The report is named after meta.id (the fastq file name, made unique if needed)
    """
    ln -s ${fastq} ${meta.id}
    mkdir -p fastqc
    fastqc --adapters ${adapters} -o fastqc ${meta.id} --threads ${task.cpus} -f fastq
    """
}
