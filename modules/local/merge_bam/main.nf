// Merge the BAM files of the same sample and Tn5 well from two previous alignment runs
process MERGE_BAM {
    tag "${meta.id}"

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(bam1, stageAs: 'bam1/*'), path(bam2, stageAs: 'bam2/*')

    output:
    tuple val(meta), path("${meta.id}.bam"), emit: bam
    tuple val("${task.process}"), val('samtools'), eval("samtools --version | head -1 | sed 's/samtools //'"), emit: versions_samtools, topic: versions

    script:
    """
    samtools addreplacerg -r ID:bam1 -r LB:bam1 ${bam1} | samtools sort -@ ${task.cpus} -o bam1.bam -
    samtools addreplacerg -r ID:bam2 -r LB:bam2 ${bam2} | samtools sort -@ ${task.cpus} -o bam2.bam -
    samtools merge --threads ${task.cpus} -o ${meta.id}.bam bam1.bam bam2.bam
    """
}
