// Extract per-cell methylation calls from deduplicated BAM files into parquet files
process MET_EXTRACT {
    tag "${sample}"

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(bam), val(total_reads)
    path index      // bwa-meth index directory (contains the reference fasta)
    val fasta_name  // Name of the reference fasta inside the index directory

    output:
    tuple val(sample), path("${sample}.met_CG.parquet"), emit: met_cg
    tuple val(sample), path("${sample}.met_CH.parquet"), emit: met_ch, optional: true
    tuple val(sample), path("${sample}.cellInfo.txt")  , emit: cell_info
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def args = task.ext.args ?: ''
    def nprocs = Math.max(task.cpus - 1, 1)
    """
    met_extract.py ${bam} --sample ${sample} ${args} --subprocesses ${nprocs} --ref ${index}/${fasta_name}
    """
}
