// Coordinate-sort and deduplicate aligned reads per cell barcode with sc_dedup
process SC_DEDUP {
    tag "${sample}"
    label 'process_medium'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(bam)
    path chroms // Chromosomes to keep

    output:
    tuple val(sample), path("${sample}.dedup.bam")        , emit: bam
    tuple val(sample), path("${sample}.cell_stats.tsv")   , emit: cell_stats
    tuple val(sample), path("${sample}.dedup_stats.tsv")  , emit: dedup_stats
    tuple val(sample), path("${sample}.fragment_hist.tsv"), emit: fragment_hist
    tuple val(sample), env('TOTAL_READS')                  , emit: total_reads
    tuple val("${task.process}"), val('sc_dedup'), eval("sc_dedup --version | sed 's/scDedup //'"), emit: versions_sc_dedup, topic: versions
    tuple val("${task.process}"), val('samtools'), eval("samtools --version | head -1 | sed 's/samtools //'"), emit: versions_samtools, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    samtools sort --threads ${task.cpus} ${bam} -O bam -o ${sample}.coodsort.bam
    sc_dedup ${sample}.coodsort.bam ${args} --barcode-input Qname --out-prefix ${sample} --write-threads ${task.cpus} --genome ${chroms}
    # count number of passing reads
    TOTAL_READS=\$(cat ${sample}.cell_stats.tsv | awk 'BEGIN { total_reads = 0 } NR > 1 { total_reads += \$3 } END { print total_reads }')
    """
}
