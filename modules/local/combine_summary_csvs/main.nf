// Combine dedup stats and fragment histograms of the same sample from multiple previous runs (--merged)
process COMBINE_SUMMARY_CSVS {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), val(threshold), path(dedup_files, stageAs: 'dedupFile?'), path(frag_files, stageAs: 'fragFile?')

    output:
    tuple val(meta), val(threshold), path("${meta.id}.dedup_stats.csv"), path("${meta.id}.fragment_hist.csv"), emit: csvs
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    combine_summary_csv.py --inDedupFiles dedupFile* --outDedupFile ${meta.id}.dedup_stats.csv --inFragFiles fragFile* --outFragFile ${meta.id}.fragment_hist.csv
    """
}
