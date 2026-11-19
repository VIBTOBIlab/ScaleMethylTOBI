//
// Subworkflows and functions specific to the VIBTOBIlab/scalemethyltobi pipeline:
//   PIPELINE_INITIALISATION  validate the parameters and read the samplesheet
//   PIPELINE_COMPLETION      completion summary, email and workflow_info.json
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
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
    input             //  string: Path to the samplesheet
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
    // Validate parameters (incl. the samplesheet, assets/schema_input.json) and print the summary
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
    // Checks of parameter combinations that the schema cannot express
    //
    validateInputParameters(input)

    //
    // Read the samplesheet: samples, fastq sets and the sample table for bc_parser
    //
    def samplesheet = readSamplesheet(file(input, checkIfExists: true), libStructurePath(params.lib_structure))

    emit:
    samples     = channel.fromList(samplesheet.samples)    // channel: [ map ] one per sample: sample, libName, barcodes, threshold, split
    fastq_sets  = channel.fromList(samplesheet.fastq_sets) // channel: [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] one per library and sequencing run
    samples_csv = channel.value(samplesheet.csv)           // channel: CSV text of the samples (bc_parser input, published as samples.csv)
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
    // Completion email, summary and workflow_info.json
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
    FUNCTIONS: PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Check combinations of input parameters that the schema cannot express
//
def validateInputParameters(input) {
    if (!input) {
        error("Must specify --input (samples.csv)")
    }
    // Reference genome: exactly one of --genome and --genome_json
    if (params.genome && params.genome_json) {
        error("Give either --genome (a pre-built genome) or --genome_json, not both")
    }
    if (!params.genome && !params.genome_json) {
        error("Must specify the reference genome: --genome (${params.genomes.keySet().join(', ')}) or --genome_json")
    }
    if (params.genome && !params.genomes.containsKey(params.genome)) {
        error("Unknown genome '${params.genome}'. Pre-built genomes: ${params.genomes.keySet().join(', ')}; use --genome_json for other genomes")
    }
}

//
// Library structure definition (--lib_structure): absolute path or relative to ${projectDir}/references/
//
def libStructurePath(lib_structure) {
    return file("${projectDir}/references/").resolve(lib_structure)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS: SAMPLESHEET
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Read the samplesheet, validated against assets/schema_input.json.
// A row is a sample with (optionally) the fastq files of one sequencing run of its library.
// Returns:
//   samples:    one map per sample (sample, libName, barcodes, threshold, split);
//               rows repeating a sample (one per sequencing run) are combined
//   fastq_sets: one entry per library and sequencing run, see samplesheetFastqSets()
//   csv:        the samples as CSV text, read by bc_parser and published as samples.csv
//
def readSamplesheet(samplesheet, lib_json) {
    def rows = samplesheetToList(samplesheet, "${projectDir}/assets/schema_input.json")
    def defaultBarcodes = sampleBarcodeRange(lib_json)

    def samples = [:]          // sample name -> sample map
    def defaulted = [:]        // libName -> number of samples using all Tn5 wells
    rows.each { meta, _fastq_1, _fastq_2, _index_1, _index_2 ->
        // Empty cells are [] in samplesheetToList
        def sample = [
            sample   : meta.id,
            libName  : meta.lib,
            barcodes : meta.barcodes ?: defaultBarcodes,
            threshold: meta.threshold != [] ? meta.threshold.toString() : '',
            // true / false for every sample (empty cells take --split_fastq): bc_parser needs a value
            split    : (meta.split instanceof Boolean ? meta.split : params.split_fastq) ? 'true' : 'false',
        ]
        // Everything after the samplesheet is named and grouped by sample name, so a sample name
        // must be unique across libraries
        def key = meta.id
        if (samples.containsKey(key)) {
            if (samples[key].libName != sample.libName) {
                error("Sample ${key} is listed in libraries ${samples[key].libName} and ${sample.libName} in ${samplesheet}: sample names must be unique across libraries")
            }
            // The same sample listed for another sequencing run: the other columns must match
            if (samples[key] != sample) {
                error("Sample ${key} is listed more than once in ${samplesheet} with different settings (barcodes, threshold or split)")
            }
            return
        }
        samples[key] = sample
        if (!meta.barcodes) {
            defaulted[meta.lib] = (defaulted[meta.lib] ?: 0) + 1
        }
    }
    // Samples without barcodes use all Tn5 wells: only one sample per library can do so
    defaulted.each { lib, n ->
        if (n > 1) {
            error("The barcodes range mentioned for each sample overlap amongst individual samples: ${n} samples of library ${lib} have no barcodes (all wells)")
        }
    }

    // Every library needs at least one fastq set
    def fastqSets = samplesheetFastqSets(rows, samplesheet)
    def missing = samples.values().collect { s -> s.libName }.toSet() - fastqSets.collect { set -> set[0].lib }.toSet()
    if (missing) {
        error("No fastq files (fastq_1, fastq_2, index_1, index_2 columns) in ${samplesheet} for library: ${missing.join(', ')}")
    }

    return [samples: samples.values().toList(), fastq_sets: fastqSets, csv: samplesCsv(samples.values().toList(), samplesheet)]
}

//
// The samples as CSV text: the sample columns of the samplesheet in their order, then
// `barcodes` and `split` (if not given)
//
def samplesCsv(samples, samplesheet) {
    def known = ['sample', 'barcodes', 'libName', 'threshold', 'split']
    def header = samplesheet.withReader { reader -> reader.readLine() }.split(',').collect { col -> col.trim() }
    def columns = header.findAll { col -> col in known }
    if (!('barcodes' in columns)) {
        columns << 'barcodes'
    }
    if (!('split' in columns)) {
        columns << 'split'
    }
    def lines = [columns.join(',')] + samples.collect { s -> columns.collect { col -> s[col] }.join(',') }
    return lines.join('\n') + '\n'
}

//
// All Tn5 wells of the library structure: "<first well>-<last well>" of the sample barcode list
//
def sampleBarcodeRange(lib_json) {
    def lib = new groovy.json.JsonSlurper().parse(lib_json)
    def entry = lib.barcodes.find { bc -> bc.name == lib.sample_barcode }
    if (!entry) {
        error("sample_barcode not found in the library structure ${lib_json}")
    }
    def wells = lib_json.getParent().resolve(entry.sequences).readLines()
        .findAll { line -> line.trim() }
        .collect { line -> line.trim().split('\t')[1] }
    return "${wells.first()}-${wells.last()}".toString()
}

//
// Fastq sets of the samplesheet: one per library and sequencing run (unique combination of
// libName and fastq files). Relative paths are resolved relative to the samplesheet.
// Returns [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] with
// meta = [ id: <libName>.<n>, lib: <libName>, fastq_num: <n>, fastqc_ids: [ unique FastQC name of each file ] ]
//
def samplesheetFastqSets(rows, samplesheet) {
    def sets = []
    rows.each { meta, fastq_1, fastq_2, index_1, index_2 ->
        if (fastq_1) {
            def files = [fastq_1, fastq_2, index_1, index_2].collect { f -> f ? samplesheetPath(f, samplesheet) : null }
            def key = [meta.lib] + files.collect { f -> f?.toUriString() }
            if (!sets.any { set -> set.key == key }) {
                sets << [key: key, lib: meta.lib, files: files]
            }
        }
    }
    // FastQC reports are named after the fastq files: make the names unique across fastq sets
    def names = sets.collectMany { set -> set.files.findAll { f -> f }.collect { f -> f.name } }
    def duplicated = names.findAll { name -> names.count(name) > 1 }.toSet()
    return sets.withIndex().collect { set, idx ->
        def id = "${set.lib}.${idx}".toString()
        def fastqcIds = set.files.collect { f -> f ? (f.name in duplicated ? "${id}_${f.name}".toString() : f.name) : null }
        def setMeta = [id: id, lib: set.lib, fastq_num: idx, fastqc_ids: fastqcIds]
        [setMeta, set.files[0], set.files[1], set.files[2], set.files[3] ?: []]
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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS: COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

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
