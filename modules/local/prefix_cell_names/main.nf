// Prefix the cell names of a sample with the sample name (<sample>_<barcode>) in the files
// published in samples/, so that samples and libraries can be loaded together in Amethyst
process PREFIX_CELL_NAMES {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(all_cells, stageAs: 'input/*'), path(barcodes, stageAs: 'input/barcodes/*')

    output:
    tuple val(meta), path("prefixed/*.allCells.csv") , emit: all_cells
    tuple val(meta), path("prefixed/*.barcodes.tsv"), emit: barcodes, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def barcodes_opt = barcodes ? "--barcodes ${barcodes}" : ''
    """
    prefix_cell_names.py --prefix ${meta.id} --all_cells ${all_cells} ${barcodes_opt} --out_dir prefixed
    """
}
