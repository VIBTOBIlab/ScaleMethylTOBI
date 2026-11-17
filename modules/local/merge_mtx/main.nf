// Merge the per-well binned matrices of a sample into one matrix with all cells
process MERGE_MTX {
    tag "${sample}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(mtx), path(barcodes), path(features), path(all_cells, stageAs: 'allCells?')

    output:
    tuple val(sample), path("${sample}.*.mtx.gz")     , emit: mtx
    tuple val(sample), path("${sample}.barcodes.tsv") , emit: barcodes
    tuple val(sample), path("${sample}.*.features.tsv"), emit: features
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    merge_mtx.py --sample ${sample} --barcodes ${barcodes} --features ${features[0]} --mtx ${mtx} --all_cells allCells*
    """
}
