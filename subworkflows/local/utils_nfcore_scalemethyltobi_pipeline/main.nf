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

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samples.csv --genome <hg38/mm39> --outdir <OUTDIR>"

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
    if (params.genome && params.genome_json) {
        error("Give either --genome (a pre-built genome) or --genome_json, not both")
    }
    if (!params.genome && !params.genome_json) {
        error("Must specify the reference genome: --genome (${params.genomes.keySet().join(', ')}) or --genome_json")
    }
    if (params.genome && !params.genomes.containsKey(params.genome)) {
        error("Unknown genome '${params.genome}'. Pre-built genomes: ${params.genomes.keySet().join(', ')}; use --genome_json for other genomes")
    }
    def startsFromReads = !(params.reporting_only || params.start_post_extraction || (params.bam1_dir && params.bam2_dir))
    if (startsFromReads) {
        // Every library needs at least one fastq set (fastq_1, fastq_2, index_1 columns)
        def rows = file(input, checkIfExists: true).splitCsv(header: true, strip: true)
        def librariesWithFastqs = rows.findAll { row -> row.fastq_1 }.collect { row -> row.libName }.toSet()
        def missing = rows.collect { row -> row.libName }.toSet() - librariesWithFastqs
        if (missing) {
            error("No fastq files (fastq_1, fastq_2, index_1, index_2 columns) in ${input} for library: ${missing.join(', ')}")
        }
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
// Fastq sets of the samplesheet: one per library and sequencing run (unique combination of
// libName and fastq files). Relative paths are resolved relative to the samplesheet.
// Returns [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] with
// meta = [ id: <libName>.<n>, lib: <libName>, fastq_num: <n>, fastqc_ids: [ unique FastQC name of each file ] ]
//
def samplesheetFastqSets(samplesheet) {
    def columns = ['fastq_1', 'fastq_2', 'index_1', 'index_2']
    def sets = []
    samplesheet.splitCsv(header: true, strip: true).each { row ->
        if (row.fastq_1) {
            def files = columns.collect { col -> row[col] ? samplesheetPath(row[col], samplesheet) : null }
            def key = [row.libName] + files.collect { f -> f?.toUriString() }
            if (!sets.any { set -> set.key == key }) {
                sets << [key: key, lib: row.libName, files: files]
            }
        }
    }
    // FastQC reports are named after the fastq files: make the names unique across fastq sets
    def names = sets.collectMany { set -> set.files.findAll { f -> f }.collect { f -> f.name } }
    def duplicated = names.findAll { name -> names.count(name) > 1 }.toSet()
    return sets.withIndex().collect { set, idx ->
        def id = "${set.lib}.${idx}".toString()
        def fastqcIds = set.files.collect { f -> f ? (f.name in duplicated ? "${id}_${f.name}".toString() : f.name) : null }
        def meta = [id: id, lib: set.lib, fastq_num: idx, fastqc_ids: fastqcIds]
        [meta, set.files[0], set.files[1], set.files[2], set.files[3] ?: []]
    }
}

//
// Path of a file listed in the samplesheet: URLs and absolute paths as given,
// relative paths relative to the directory of the samplesheet
//
def samplesheetPath(path, samplesheet) {
    def resolved = (path =~ /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//) || path.startsWith('/')
        ? file(path)
        : samplesheet.getParent().resolve(path)
    if (!resolved.exists()) {
        error("File in the samplesheet ${samplesheet} not found: ${path}")
    }
    return resolved
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
    def genomeJson = params.genome_json ? file(params.genome_json) : null
    def referenceData = ["Reference Genome": (genomeJson && genomeJson.exists())
        ? new groovy.json.JsonSlurper().parse(genomeJson)
        : (params.genome ? ["name": params.genome, "archive": params.genomes[params.genome]?.archive] : [:])]
    def manifestData = ["Manifest": ["name": workflow.manifest.name, "version": workflow.manifest.version]]
    def jsonStr = groovy.json.JsonOutput.toJson(data + paramsData + referenceData + manifestData)
    file("${outdir}/workflow_info.json").text = groovy.json.JsonOutput.prettyPrint(jsonStr)
}
