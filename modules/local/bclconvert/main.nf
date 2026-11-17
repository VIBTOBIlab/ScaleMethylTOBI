// Run bcl-convert, used when starting from a sequencing run folder
process BCLCONVERT {
    label 'process_high'

    container "docker.io/nfcore/bclconvert:3.9.3"

    input:
    path run
    path samplesheet

    output:
    path "fastq/*fastq.gz", emit: fastq
    path "fastq/Reports/*", emit: stats
    tuple val("${task.process}"), val('bcl-convert'), eval("bcl-convert -V 2>&1 | head -n 1 | sed 's/^.*Version //'"), emit: versions_bclconvert, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    bcl-convert --sample-sheet ${samplesheet} --bcl-input-directory ${run} \\
        --bcl-num-conversion-threads 4 --bcl-num-compression-threads 4 --bcl-num-decompression-threads 4 \\
        ${args} --output-directory fastq
    """
}
