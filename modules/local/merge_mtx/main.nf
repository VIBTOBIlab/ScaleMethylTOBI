// Merge the per-well binned matrices of a sample into one matrix with all cells
process MERGE_MTX {
    tag "${meta.id}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(mtx), path(barcodes), path(features), path(all_cells, stageAs: 'allCells?')

    output:
    tuple val(meta), path("${meta.id}.*.mtx.gz")     , emit: mtx
    tuple val(meta), path("${meta.id}.barcodes.tsv") , emit: barcodes
    tuple val(meta), path("${meta.id}.*.features.tsv"), emit: features
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    merge_mtx.py --sample ${meta.id} --barcodes ${barcodes} --features ${features[0]} --mtx ${mtx} --all_cells allCells*
    """
}
