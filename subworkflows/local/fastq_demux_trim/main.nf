//
// Generate fastq files (bcl-convert, optional), run FastQC, demultiplex reads by sample and
// Tn5 well with barcode error correction (bc_parser) and trim adapters (cutadapt)
//

include { BCLCONVERT_SAMPLESHEET } from '../../../modules/local/bclconvert_samplesheet'
include { BCLCONVERT             } from '../../../modules/local/bclconvert'
include { FASTQC                 } from '../../../modules/local/fastqc'
include { BC_PARSER              } from '../../../modules/local/bc_parser'
include { MERGE_DEMUX            } from '../../../modules/local/merge_demux'
include { CUTADAPT               } from '../../../modules/local/cutadapt'

workflow FASTQ_DEMUX_TRIM {

    take:
    ch_samples     // channel: [ map ] one row of the regularized samples.csv
    ch_samples_csv // channel: path(samples.csv) regularized samples.csv
    lib_json       // path: library structure definition (.json)
    fastq_dir      // string: directory with fastq files (or null)
    run_folder     // string: sequencer run folder (or null)

    main:
    // [ libName, sample ]
    def ch_lib_samples = ch_samples.map { row -> [row.libName, row.sample] }

    //
    // Input fastq files: from the run folder (bcl-convert) or from a fastq directory
    //
    def ch_fastqs = channel.empty()
    if (run_folder) {
        def ch_bcl_samplesheet = channel.empty()
        if (params.fastq_samplesheet) {
            ch_bcl_samplesheet = channel.value(file(params.fastq_samplesheet, checkIfExists: true))
        } else {
            BCLCONVERT_SAMPLESHEET(
                ch_samples_csv,
                lib_json.getParent(),
                lib_json.getName(),
                file("${run_folder}/RunInfo.xml", checkIfExists: true)
            )
            ch_bcl_samplesheet = BCLCONVERT_SAMPLESHEET.out.samplesheet
        }
        BCLCONVERT(file(run_folder, checkIfExists: true), ch_bcl_samplesheet)
        ch_fastqs = BCLCONVERT.out.fastq.flatten().filter { fq -> !fq.name.contains("Undetermined") }
    } else if (fastq_dir) {
        ch_fastqs = channel.fromPath("${fastq_dir}/*fastq.gz", checkIfExists: true).filter { fq -> !fq.name.contains("Undetermined") }
    } else {
        error("Must specify either --run_folder or --fastq_dir")
    }

    if (params.fastqc) {
        def adapters = params.adapters ?: "${projectDir}/references/SciMETv2_Adapters.tsv"
        FASTQC(ch_fastqs, file(adapters, checkIfExists: true))
    }

    //
    // Group the fastq files (R1, R2, I1, I2) of each library (and fastq set with --split_fastq)
    //
    // [ libName, matchingKey, [ fastq files ] ]
    def ch_fastq_sets = ch_fastqs
        .map { fq ->
            def libName = fq.name.tokenize('_')[0]
            // Key to join the read and index files of the same fastq set
            def matchingKey = params.split_fastq ? fastqMatchingKey(fq.name) : libName
            [libName, matchingKey, fq]
        }
        .groupTuple(by: [0, 1])

    // Keep only the fastq sets of libraries in samples.csv and number them;
    // the number is used by bc_parser for output file naming
    // [ libName, matchingKey, [ fastq files ], fastqNum ]
    def ch_lib_fastqs = ch_fastq_sets
        .combine(ch_samples.map { row -> row.libName }.unique(), by: 0)
        .toSortedList { a, b -> a[1] <=> b[1] }
        .flatMap { sets -> sets.withIndex().collect { set, idx -> set + [idx] } }

    //
    // Check that each library in samples.csv has a complete set of fastq files
    //
    ch_lib_samples
        .unique { row -> row[0] }
        .join(ch_lib_fastqs, remainder: true)
        .map { row ->
            def libName = row[0]
            def fastqs = row[3]
            if (fastqs == null) {
                error("Library ${libName} does not have matching fastq files. None of the provided fastq filenames start with \"${libName}_\"")
            }
            ['R1', 'R2', 'I1'].each { read ->
                if (!fastqs.any { fq -> fq.name.contains("_${read}_") || fq.name.contains("_${read}.") }) {
                    def type = read == 'R1' ? 'read1' : read == 'R2' ? 'read2' : 'index'
                    error("Library ${libName} does not have ${type} fastq file")
                }
            }
            row
        }

    //
    // Demultiplex reads by sample (and Tn5 well) with barcode error correction
    //
    BC_PARSER(ch_samples_csv, lib_json.getParent(), lib_json.getName(), ch_lib_fastqs)

    // Check that each library has demultiplexed R1 and R2 fastq files for every sample
    ch_lib_samples
        .groupTuple()
        .join(BC_PARSER.out.read1_fastq.groupTuple().join(BC_PARSER.out.read2_fastq.groupTuple(), remainder: true), remainder: true)
        .map { row ->
            def libName = row[0]
            if (row[2] == null) {
                error("Library ${libName} does not have any passing R1 and R2 fastq files after bcParser")
            }
            def demuxFastqs = row[2].flatten() + row[3].flatten()
            row[1].each { sample ->
                def sampleName = sample.tokenize('.')[0]
                if (!demuxFastqs.any { fq -> fq.name.contains(sampleName) }) {
                    log.warn("Sample ${sampleName} does not have passing R1 and R2 files from bcParser.")
                }
            }
            row
        }

    // [ libName, sample, subsample, [ read1 fastq files ] ]
    def ch_read1 = BC_PARSER.out.read1_fastq
        .transpose()
        .map { libName, fq -> demuxSampleName(libName, fq, params.split_fastq) }
        .groupTuple(by: [0, 1, 2])
    // [ libName, sample, subsample, [ read2 fastq files ] ]
    def ch_read2 = BC_PARSER.out.read2_fastq
        .transpose()
        .map { libName, fq -> demuxSampleName(libName, fq, params.split_fastq) }
        .groupTuple(by: [0, 1, 2])

    // with --split_fastq: [ sample.well, [ R1 fastq files ], [ R2 fastq files ] ]
    // otherwise:          [ sample, [ R1 fastq files ], [ R2 fastq files ] ]
    def ch_demux_fastqs = ch_read1
        .join(ch_read2, by: [0, 1, 2])
        .map { _libName, _sample, subsample, read1, read2 -> [subsample, read1, read2] }

    // Merge the bc_parser metrics of all bc_parser jobs of a library
    MERGE_DEMUX(BC_PARSER.out.metrics.groupTuple(), lib_json.getParent(), lib_json.getName())

    //
    // Trim adapters
    //
    CUTADAPT(ch_demux_fastqs)

    emit:
    trim_fastq    = CUTADAPT.out.fastq                // channel: [ sample, [ R1, R2 ] ]
    trim_stats    = CUTADAPT.out.stats                // channel: [ sample, trim_stats.json ]
    demux_metrics = MERGE_DEMUX.out.barcode_metrics   // channel: [ libName, metrics.json ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Key shared by the read and index fastq files of the same fastq set
//
def fastqMatchingKey(fname) {
    return fname.replaceAll(/_[RI][12][_\.]/, "")
}

//
// Sample name (and subsample: sample.well with --split_fastq) of a demultiplexed fastq file
//
def demuxSampleName(libName, fq, splitFastq) {
    def tok = fq.name.tokenize('_')
    def sampleName = tok[0]
    // With --split_fastq the Tn5 well follows the sample name: <sample>_<well>_S<n>_R<1|2>_<num>.fastq.gz
    def subsampleName = splitFastq ? "${sampleName}.${tok[1]}".toString() : sampleName
    return [libName, sampleName, subsampleName, fq]
}
