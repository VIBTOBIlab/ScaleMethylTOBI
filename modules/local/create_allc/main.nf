// Write per-cell .allc files (ALLCools format) and their tabix indices
process CREATE_ALLC {
    tag "${sample_well}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), val(sample_well), path(all_cells, stageAs: 'allCells?'), path(met_calls, stageAs: 'met?'), val(context)

    output:
    tuple val(sample), path("{CG,CH}/*.allc.tsv.gz"), emit: allc, optional: true
    tuple val(sample), path("{CG,CH}/*.tbi")        , emit: tbi , optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('tabix'), eval("tabix --version | head -1 | sed 's/tabix (htslib) //'"), emit: versions_tabix, topic: versions

    script:
    """
    write_allc.py --met_calls met* --all_cells allCells* --sample ${sample_well} --context ${context}
    for file in {CG,CH}/*.tsv.gz; do
        if [[ -f "\${file}" ]]; then
            tabix -@ ${task.cpus} -b2 -e2 -s1 \${file};
        fi
    done
    """
}
