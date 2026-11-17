// Coordinate-sort and deduplicate aligned reads per cell barcode with sc_dedup
process SC_DEDUP {
    tag "${meta.id}"
    label 'process_medium'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(bam)
    path chroms // Chromosomes to keep

    output:
    tuple val(meta), path("${meta.id}.dedup.bam")        , emit: bam
    tuple val(meta), path("${meta.id}.cell_stats.tsv")   , emit: cell_stats
    tuple val(meta), path("${meta.id}.dedup_stats.tsv")  , emit: dedup_stats
    tuple val(meta), path("${meta.id}.fragment_hist.tsv"), emit: fragment_hist
    tuple val(meta), env('TOTAL_READS')                  , emit: total_reads
    tuple val("${task.process}"), val('sc_dedup'), eval("sc_dedup --version | sed 's/scDedup //'"), emit: versions_sc_dedup, topic: versions
    tuple val("${task.process}"), val('samtools'), eval("samtools --version | head -1 | sed 's/samtools //'"), emit: versions_samtools, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    samtools sort --threads ${task.cpus} ${bam} -O bam -o ${meta.id}.coodsort.bam
    sc_dedup ${meta.id}.coodsort.bam ${args} --barcode-input Qname --out-prefix ${meta.id} --write-threads ${task.cpus} --genome ${chroms}
    # count number of passing reads
    TOTAL_READS=\$(cat ${meta.id}.cell_stats.tsv | awk 'BEGIN { total_reads = 0 } NR > 1 { total_reads += \$3 } END { print total_reads }')
    """
}
