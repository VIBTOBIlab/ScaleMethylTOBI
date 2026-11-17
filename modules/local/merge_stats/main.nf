// Concatenate the per-well (Tn5) statistics of a sample and format them for reporting
process MERGE_STATS {
    tag "${sample}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(cell_stats), path(frags), path(cell_info_stats), path(dedup_stats), path(mapping_stats), path(trimming_stats)

    output:
    tuple val(sample), path("metrics_for_reporting/${sample}.cell_stats.csv"), path("metrics_for_reporting/${sample}.cellInfo.csv"), emit: merged_stats
    tuple val(sample), path("metrics_for_reporting/${sample}.fragment_hist.csv")                                                , emit: fragment_hist
    tuple val(sample), path("metrics_for_reporting/${sample}.dedup_stats.csv")                                                  , emit: dedup_stats
    tuple val(sample), path("metrics_for_reporting/${sample}.mapping_stats.csv"), path("metrics_for_reporting/${sample}.trimming_stats.csv"), emit: trimming_and_mapping_stats, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    merge_stats.py --sampleName ${sample} --outDir metrics_for_reporting
    """
}
