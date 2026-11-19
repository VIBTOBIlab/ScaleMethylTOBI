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
    skip_fastqc: Boolean
    skip_ch_context: Boolean
    skip_tss_enrich: Boolean
    skip_window_matrix: Boolean
    skip_cov: Boolean
    skip_allc: Boolean
    skip_amethyst: Boolean
    skip_cell_prefix: Boolean
    save_parquet: Boolean
    save_demux_fastq: Boolean
    save_trimmed: Boolean
    save_bam: Boolean
    save_dedup_bam: Boolean
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
    ch_samples    // channel: [ map ] one per sample, from the samplesheet
    ch_fastq_sets // channel: [ meta, fastq_1, fastq_2, index_1, index_2 ] one per library and sequencing run
    samples_csv   // channel: CSV text of the samples
    genome_name   // string: name of a pre-built genome (--genome) or null
    genome_json   // path: genome.json (--genome_json) or null
    lib_json      // path: library structure definition (.json)

    main:

    //
    // WORKFLOW: Run pipeline
    //
    SCALEMETHYLTOBI (
        ch_samples,
        ch_fastq_sets,
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
        PIPELINE_INITIALISATION.out.samples,
        PIPELINE_INITIALISATION.out.fastq_sets,
        PIPELINE_INITIALISATION.out.samples_csv,
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
