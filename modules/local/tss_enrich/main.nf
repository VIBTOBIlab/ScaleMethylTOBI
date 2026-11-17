// Compute per-cell TSS enrichment for one sample and Tn5 well
process TSS_ENRICH {
    tag "${sample_well}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(sample), path(all_cells), path(bam), val(sample_well)
    path tss_bed
    path background_bed

    output:
    tuple val(sample), path("${sample_well}.tss_enrich.csv"), emit: enrich
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    tss_enrich.py --tss_bed ${tss_bed} --bg_bed ${background_bed} --id ${sample_well} --cells ${all_cells} --bam ${bam}
    """
}
