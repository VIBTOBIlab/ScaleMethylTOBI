// Compute per-cell TSS enrichment for one sample and Tn5 well
process TSS_ENRICH {
    tag "${meta.id}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path(all_cells), path(bam)
    path tss_bed
    path background_bed

    output:
    tuple val(meta), path("*.tss_enrich.csv"), emit: enrich
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    // Without --split_fastq there is one BAM file per sample: keep its name apart from the sample-level file
    def prefix = meta.well ? meta.id : "${meta.id}.dedup"
    """
    tss_enrich.py --tss_bed ${tss_bed} --bg_bed ${background_bed} --id ${prefix} --cells ${all_cells} --bam ${bam}
    """
}
