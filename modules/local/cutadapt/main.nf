// Adapter-trim the demultiplexed fastq files of one sample (or sample/Tn5 well)
process CUTADAPT {
    tag "${sample}"

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(read1_fastqs), path(read2_fastqs)

    output:
    tuple val(sample), path("${sample}_{R1,R2}.fq.gz"), emit: fastq
    tuple val(sample), path("*.trim_stats.json")     , emit: stats
    path "*.trim_log"                                 , emit: log
    tuple val("${task.process}"), val('cutadapt'), eval('cutadapt --version'), emit: versions_cutadapt, topic: versions

    script:
    def args = task.ext.args ?: ''
    def threads = Math.max(task.cpus - 2, 1)
    """
    cutadapt -j ${threads} ${args} -o ${sample}_R1.fq.gz -p ${sample}_R2.fq.gz <(zcat ${read1_fastqs}) <(zcat ${read2_fastqs}) --json ${sample}.trim_stats.json | tee ${sample}.trim_log
    """
}
