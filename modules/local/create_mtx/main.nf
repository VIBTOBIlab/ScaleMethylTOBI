// Create the binned methylation matrix (genome windows x cells) for one sample and Tn5 well
// CG: per-bin methylation score matrix; CH: per-bin matrix (ext.args '--CH')
process CREATE_MTX {
    tag "${sample_well}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path tiles // Non-overlapping genome bins
    tuple val(sample), val(sample_well), path(all_cells, stageAs: 'allCells?'), path(met_calls, stageAs: 'met?')

    output:
    tuple val(sample_well), path("${sample_well}.*.mtx"), path("${sample_well}.barcodes.tsv"), path("${sample_well}.*.features.tsv"), emit: mtx, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    create_mtx.py --bedfile ${tiles} --met_calls met* --all_cells allCells* --sample ${sample_well} ${args}
    """
}
