// Extract per-cell methylation calls from deduplicated BAM files into parquet files
process MET_EXTRACT {
    tag "${meta.id}"

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(bam), val(total_reads)
    tuple path(index), val(fasta_name) // bwa-meth index directory and the name of the reference fasta in it

    output:
    tuple val(meta), path("${meta.id}.met_CG.parquet"), emit: met_cg
    tuple val(meta), path("${meta.id}.met_CH.parquet"), emit: met_ch, optional: true
    tuple val(meta), path("${meta.id}.cellInfo.txt")  , emit: cell_info
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    def nprocs = Math.max(task.cpus - 1, 1)
    """
    met_extract.py ${bam} --sample ${meta.id} ${args} --subprocesses ${nprocs} --ref ${index}/${fasta_name}
    """
}
