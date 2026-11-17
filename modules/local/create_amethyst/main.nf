// Write per-cell methylation coverage in the Amethyst hdf5 format
process CREATE_AMETHYST {
    tag "${meta.id}"
    label 'process_medium_memory'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(all_cells, stageAs: 'allCells?'), path(met_cg, stageAs: 'metCG?'), path(met_ch, stageAs: 'metCH?')

    output:
    tuple val(meta), path("*_cov.h5"), emit: h5, optional: true // test datasets may have no passing cells for one well
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    // met_ch is empty when CH methylation is not calculated (--calculate_ch false)
    def met_opts = met_ch ? "--met_cg metCG* --met_ch metCH*" : "--met_cg metCG*"
    """
    write_amethyst.py ${met_opts} --all_cells allCells* --sample ${meta.id}
    """
}
