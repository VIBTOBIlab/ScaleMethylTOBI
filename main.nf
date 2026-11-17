#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VIBTOBIlab/scalemethyltobi
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ScaleBio single-cell DNA methylation analysis workflow
    Github : https://github.com/VIBTOBIlab/ScaleMethylTOBI
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SCALEMETHYLTOBI         } from './workflows/scalemethyltobi'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_scalemethyltobi_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_scalemethyltobi_pipeline'
include { libStructurePath        } from './subworkflows/local/utils_nfcore_scalemethyltobi_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARAMETER TYPES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Defaults are in nextflow.config. Declaring the types makes Nextflow convert values given
    on the command line (e.g. `--split_fastq false`), which would otherwise be strings.
*/

params {
    // Booleans
    split_fastq: Boolean
    fastqc: Boolean
    calculate_ch: Boolean
    run_tss_enrich: Boolean
    window_matrix_out: Boolean
    cov_out: Boolean
    allc_out: Boolean
    amethyst_out: Boolean
    parquet_out: Boolean
    fastq_out: Boolean
    trim_out: Boolean
    bam_out: Boolean
    bam_dedup_out: Boolean
    bam_merge_out: Boolean
    merged: Boolean
    start_post_extraction: Boolean
    reporting_only: Boolean
    skip_multiqc: Boolean
    plaintext_email: Boolean
    monochrome_logs: Boolean
    validate_params: Boolean
    // Integers
    min_mapq: Integer
    min_uniq_count: Integer
    window_tile_size_cg: Integer
    window_tile_size_ch: Integer
    minimum_window_size: Integer
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline
//
workflow VIBTOBILAB_SCALEMETHYLTOBI {

    take:
    samples_csv // path: samplesheet
    genome_name // string: name of a pre-built genome (--genome) or null
    genome_json // path: genome.json (--genome_json) or null
    lib_json    // path: library structure definition (.json)

    main:

    //
    // WORKFLOW: Run pipeline
    //
    SCALEMETHYLTOBI (
        samples_csv,
        genome_name,
        genome_json,
        lib_json,
        params.outdir,
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    VIBTOBILAB_SCALEMETHYLTOBI (
        file(params.input, checkIfExists: true),
        params.genome,
        params.genome_json ? file(params.genome_json, checkIfExists: true) : null,
        libStructurePath(params.lib_structure)
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
