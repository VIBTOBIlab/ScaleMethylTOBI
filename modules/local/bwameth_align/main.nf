// Align trimmed read pairs with bwa-meth and collect alignment statistics with samtools flagstat
process BWAMETH_ALIGN {
    tag "${sample}"

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(reads)
    path index      // bwa-meth index directory
    val fasta_name  // Name of the reference fasta inside the index directory

    output:
    tuple val(sample), path("${sample}.bam")  , emit: bam
    tuple val(sample), path("${sample}.*.log"), emit: log
    tuple val("${task.process}"), val('bwameth'), eval("bwameth.py --version 2>&1 | sed 's/bwa-meth.py //'"), emit: versions_bwameth, topic: versions
    tuple val("${task.process}"), val('samtools'), eval("samtools --version | head -1 | sed 's/samtools //'"), emit: versions_samtools, topic: versions

    script:
    def align_threads = task.cpus - 2
    def other_threads = 2
    """
    # Touch the index files to update the timestamp for bwa-meth
    touch -d "\$(date -R -r ${index}/${fasta_name}.bwameth.c2t) - 2 hours" -m ${index}/${fasta_name}.bwameth.c2t || true
    bwameth.py --threads ${align_threads} --reference ${index}/${fasta_name} ${reads[1]} ${reads[0]} 2>> ${sample}.bwa_meth.runtime | samtools view -@ ${other_threads} -bS - -o ${sample}.bam
    samtools flagstat -O tsv -@ ${task.cpus} ${sample}.bam > ${sample}.bwa_meth.log
    """
}
