// Write per-cell methylation coverage files in Bismark .cov format
process CREATE_BISMARK {
    tag "${meta.id}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(all_cells, stageAs: 'allCells?'), path(met_calls, stageAs: 'met?'), val(context)

    output:
    tuple val(meta), path("{CG,CH}/*.cov.gz"), emit: cov, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    write_bismark.py --met_calls met* --all_cells allCells* --sample ${meta.id} --context ${context}
    """
}
