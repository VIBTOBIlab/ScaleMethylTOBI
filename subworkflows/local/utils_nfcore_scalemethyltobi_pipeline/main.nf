//
// Subworkflow with functionality specific to the VIBTOBIlab/scalemethyltobi pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samples.csv
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //

    def before_text = ""
    def after_text = ""
    if (monochrome_logs) {
        before_text = before_text.replaceAll(/\033\[[0-9;]*m/, '')
    }

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samples.csv --genome genome.json --fastq_dir <FASTQ_DIR> --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters(input)

    emit:
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                []
            )
        }

        completionSummary(monochrome_logs)

        writeWorkflowInfo(outdir)
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Check combinations of input parameters that the schema cannot express
//
def validateInputParameters(input) {
    if (!input) {
        error("Must specify --input (samples.csv)")
    }
    if (!params.genome) {
        error("Must specify --genome (genome.json)")
    }
    if (params.fastq_dir && params.run_folder) {
        error("One input type must be specified at a time: --run_folder or --fastq_dir")
    }
    def startsFromReads = !(params.reporting_only || params.start_post_extraction || (params.bam1_dir && params.bam2_dir))
    if (startsFromReads && !params.fastq_dir && !params.run_folder) {
        error("Must specify either --run_folder or --fastq_dir")
    }
    if ((params.reporting_only || params.start_post_extraction) && !(params.previous_outdir || params.merged)) {
        error("Must specify --previous_outdir or --merged when --reporting_only or --start_post_extraction is enabled")
    }
    if (params.reporting_only && params.start_post_extraction) {
        error("Cannot specify both --reporting_only and --start_post_extraction")
    }
    if (params.merged && params.previous_outdir) {
        error("Cannot specify both --previous_outdir and --merged")
    }
    if ((params.bam1_dir && !params.bam2_dir) || (!params.bam1_dir && params.bam2_dir)) {
        error("--bam1_dir and --bam2_dir must be specified together")
    }
}

//
// Library structure definition (--lib_structure): absolute path or relative to ${projectDir}/references/
//
def libStructurePath(lib_structure) {
    return file("${projectDir}/references/").resolve(lib_structure)
}

//
// Write workflow_info.json with information about the pipeline execution to the output directory
//
def writeWorkflowInfo(outdir) {
    def data = [
        "Workflow Information": [
            "Execution status": "${workflow.success ? 'OK' : 'failed'}",
            "Pipeline completion timestamp": "${workflow.complete}",
            "Git repo URL": "${workflow.repository}",
            "Configuration files": "${workflow.configFiles}",
            "Container": "${workflow.container}",
            "Command line executed": "${workflow.commandLine}",
            "Configuration profile": "${workflow.profile}",
            "Start timestamp": "${workflow.start}",
            "Stop timestamp": "${workflow.complete}",
            "Run name": "${workflow.runName}",
            "Revision": "${workflow.revision}",
            "Commit ID": "${workflow.commitId}",
            "Duration": "${workflow.duration}",
            "Exit status": "${workflow.exitStatus}",
            "Error message": "${workflow.errorMessage}",
        ]
    ]
    def paramsData = ["Parameters": params.collectEntries { k, v -> [k.toString(), v.toString()] }]
    def genomeJson = params.genome ? file(params.genome) : null
    def referenceData = ["Reference Genome": (genomeJson && genomeJson.exists()) ? new groovy.json.JsonSlurper().parse(genomeJson) : [:]]
    def manifestData = ["Manifest": ["name": workflow.manifest.name, "version": workflow.manifest.version]]
    def jsonStr = groovy.json.JsonOutput.toJson(data + paramsData + referenceData + manifestData)
    file("${outdir}/workflow_info.json").text = groovy.json.JsonOutput.prettyPrint(jsonStr)
}
