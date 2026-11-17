// Write per-cell methylation coverage files in Bismark .cov format
process CREATE_BISMARK {
    tag "${sample_well}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), val(sample_well), path(all_cells, stageAs: 'allCells?'), path(met_calls, stageAs: 'met?'), val(context)

    output:
    tuple val(sample), path("{CG,CH}/*.cov.gz"), emit: cov, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    write_bismark.py --met_calls met* --all_cells allCells* --sample ${sample_well} --context ${context}
    """
}
