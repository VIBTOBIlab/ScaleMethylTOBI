// Summarise the read QC, trimming and alignment statistics of all samples with MultiQC
process MULTIQC {
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path multiqc_files, stageAs: "?/*"
    path multiqc_config

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data"       , emit: data
    tuple val("${task.process}"), val('multiqc'), eval("multiqc --version 2>/dev/null | sed 's/multiqc, version //'"), emit: versions_multiqc, topic: versions

    script:
    def args = task.ext.args ?: ''
    """
    multiqc --force ${args} --config ${multiqc_config} .
    """
}
