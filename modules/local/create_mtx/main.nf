// Create the binned methylation matrix (genome windows x cells) for one sample and Tn5 well
// CG: per-bin methylation score matrix; CH: per-bin matrix (ext.args '--CH')
process CREATE_MTX {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path tiles // Non-overlapping genome bins
    tuple val(meta), path(all_cells, stageAs: 'allCells?'), path(met_calls, stageAs: 'met?')

    output:
    tuple val(meta), path("*.mtx"), path("*.barcodes.tsv"), path("*.features.tsv"), emit: mtx, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    // Without --split_fastq there is one matrix per sample: rename it apart from the merged matrix
    // (the sample name is also used to select the cells, so it is renamed afterwards)
    def rename = meta.well ? '' : """
    for f in ${meta.id}.*; do
        if [[ -e "\${f}" ]]; then mv "\${f}" "${meta.id}.all\${f#${meta.id}}"; fi
    done"""
    """
    create_mtx.py --bedfile ${tiles} --met_calls met* --all_cells allCells* --sample ${meta.id} ${args}${rename}
    """
}
