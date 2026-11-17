// Write per-cell .allc files (ALLCools format) and their tabix indices
process CREATE_ALLC {
    tag "${meta.id}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(all_cells, stageAs: 'allCells?'), path(met_calls, stageAs: 'met?'), val(context)

    output:
    tuple val(meta), path("{CG,CH}/*.allc.tsv.gz"), emit: allc, optional: true
    tuple val(meta), path("{CG,CH}/*.tbi")        , emit: tbi , optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('tabix'), eval("tabix --version | head -1 | sed 's/tabix (htslib) //'"), emit: versions_tabix, topic: versions

    script:
    """
    write_allc.py --met_calls met* --all_cells allCells* --sample ${meta.id} --context ${context}
    for file in {CG,CH}/*.tsv.gz; do
        if [[ -f "\${file}" ]]; then
            tabix -@ ${task.cpus} -b2 -e2 -s1 \${file};
        fi
    done
    """
}
