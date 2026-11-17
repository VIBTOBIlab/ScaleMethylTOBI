// Concatenate the per-well (Tn5) statistics of a sample and format them for reporting
process MERGE_STATS {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(cell_stats), path(frags), path(cell_info_stats), path(dedup_stats), path(mapping_stats), path(trimming_stats)

    output:
    tuple val(meta), path("metrics_for_reporting/${meta.id}.cell_stats.csv"), path("metrics_for_reporting/${meta.id}.cellInfo.csv"), emit: merged_stats
    tuple val(meta), path("metrics_for_reporting/${meta.id}.fragment_hist.csv")                                                , emit: fragment_hist
    tuple val(meta), path("metrics_for_reporting/${meta.id}.dedup_stats.csv")                                                  , emit: dedup_stats
    tuple val(meta), path("metrics_for_reporting/${meta.id}.mapping_stats.csv"), path("metrics_for_reporting/${meta.id}.trimming_stats.csv"), emit: trimming_and_mapping_stats, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    merge_stats.py --sampleName ${meta.id} --outDir metrics_for_reporting
    """
}
