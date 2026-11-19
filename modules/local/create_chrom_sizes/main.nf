// Create a chrom.sizes file from the reference fasta (used to tile the genome into bins)
process CREATE_CHROM_SIZES {
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path fasta

    output:
    path "chrom.sizes", emit: chrom_sizes
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    create_chrom_sizes.py --fastaFile ${fasta} --output chrom.sizes
    """
}
