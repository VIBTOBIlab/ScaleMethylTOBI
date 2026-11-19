// Combine per-cell metrics of the same sample from multiple previous runs (--merge_runs)
process COMBINE_BARCODE_CSVS {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), val(threshold), path(cell_info_files, stageAs: 'cellInfo?'), path(cell_stat_files, stageAs: 'cellStat?'), path(tss_enrich_files, stageAs: 'tssEnrich?')

    output:
    tuple val(meta), val(threshold), path("${meta.id}.cellInfo.csv"), path("${meta.id}.cell_stats.csv"), path("${meta.id}.tss_enrich.csv"), emit: csvs
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    combine_barcode_csv.py --inFiles cellInfo* --outFile ${meta.id}.cellInfo.csv
    combine_barcode_csv.py --inFiles cellStat* --outFile ${meta.id}.cell_stats.csv --header
    combine_barcode_csv.py --inFiles tssEnrich* --outFile ${meta.id}.tss_enrich.csv --header
    """
}
