// Adapter-trim the demultiplexed fastq files of one sample (or sample and Tn5 well)
// The files of all sequencing runs of the library are combined here
process CUTADAPT {
    tag "${meta.id}"

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(read1_fastqs), path(read2_fastqs)

    output:
    tuple val(meta), path("${meta.id}_{R1,R2}.fq.gz"), emit: fastq
    tuple val(meta), path("*.trim_stats.json")       , emit: stats
    tuple val(meta), path("*.trim_log")              , emit: log
    tuple val("${task.process}"), val('cutadapt'), eval('cutadapt --version'), emit: versions_cutadapt, topic: versions

    script:
    def args = task.ext.args ?: ''
    def threads = Math.max(task.cpus - 2, 1)
    """
    cutadapt -j ${threads} ${args} -o ${meta.id}_R1.fq.gz -p ${meta.id}_R2.fq.gz <(zcat ${read1_fastqs}) <(zcat ${read2_fastqs}) --json ${meta.id}.trim_stats.json | tee ${meta.id}.trim_log
    """
}
