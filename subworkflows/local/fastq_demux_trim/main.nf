//
// Run FastQC, demultiplex the reads of each fastq set (library and sequencing run) by sample
// and Tn5 well with barcode error correction (bc_parser), combine the sequencing runs and
// trim adapters (cutadapt)
//

include { FASTQC      } from '../../../modules/local/fastqc'
include { BC_PARSER   } from '../../../modules/local/bc_parser'
include { MERGE_DEMUX } from '../../../modules/local/merge_demux'
include { CUTADAPT    } from '../../../modules/local/cutadapt'

workflow FASTQ_DEMUX_TRIM {

    take:
    ch_fastq_sets  // channel: [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] one per library and sequencing run
    ch_samples     // channel: [ map ] one row of the regularized samples.csv
    ch_samples_csv // channel: path(samples.csv) regularized samples.csv
    lib_json       // path: library structure definition (.json)

    main:
    //
    // FastQC of every input fastq file
    //
    def ch_fastqc_zip = channel.empty()
    if (params.fastqc) {
        def adapters = params.adapters ?: "${projectDir}/references/SciMETv2_Adapters.tsv"
        def ch_fastqc_input = ch_fastq_sets.flatMap { meta, fastq_1, fastq_2, index_1, index_2 ->
            // Same order as the fastq files in the samplesheet: fastq_1, fastq_2, index_1, index_2
            [fastq_1, fastq_2, index_1, index_2]
                .withIndex()
                .findAll { fq, _idx -> fq }
                .collect { fq, idx -> [[id: meta.fastqc_ids[idx]], fq] }
        }
        FASTQC(ch_fastqc_input, file(adapters, checkIfExists: true))
        ch_fastqc_zip = FASTQC.out.zip
    }

    //
    // Demultiplex reads by sample (and Tn5 well) with barcode error correction
    //
    BC_PARSER(ch_samples_csv, lib_json.getParent(), lib_json.getName(), ch_fastq_sets)

    // [ sample.well (or sample) meta, [ R1 fastq files of all sequencing runs ] ]
    def ch_read1 = BC_PARSER.out.read1_fastq
        .transpose()
        .map { _meta, fq -> [demuxMeta(fq, params.split_fastq), fq] }
        .groupTuple()
    def ch_read2 = BC_PARSER.out.read2_fastq
        .transpose()
        .map { _meta, fq -> [demuxMeta(fq, params.split_fastq), fq] }
        .groupTuple()

    // Warn about samples without passing reads after bc_parser
    ch_samples
        .map { row -> [row.sample, row.libName] }
        .join(ch_read1.map { meta, _fqs -> [meta.sample, true] }.unique(), remainder: true)
        .map { sample, libName, demuxed ->
            if (libName && !demuxed) {
                log.warn("Sample ${sample} does not have passing R1 and R2 files from bcParser.")
            }
            sample
        }

    // Merge the bc_parser metrics of all fastq sets of a library
    MERGE_DEMUX(
        BC_PARSER.out.metrics.map { meta, metrics -> [[id: meta.lib], metrics] }.groupTuple(),
        lib_json.getParent(),
        lib_json.getName()
    )

    //
    // Trim adapters; the reads of all sequencing runs are combined here
    //
    CUTADAPT(ch_read1.join(ch_read2))

    emit:
    trim_fastq    = CUTADAPT.out.fastq              // channel: [ meta, [ R1, R2 ] ]
    trim_stats    = CUTADAPT.out.stats              // channel: [ meta, trim_stats.json ]
    trim_log      = CUTADAPT.out.log                // channel: [ meta, trim_log ]
    demux_metrics = MERGE_DEMUX.out.barcode_metrics // channel: [ [ id: libName ], metrics.json ]
    fastqc_zip    = ch_fastqc_zip                   // channel: [ meta, fastqc.zip ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Meta map of a demultiplexed fastq file: <sample>_<well>_S<n>_R<1|2>_<fastq num>.fastq.gz
// With --split_fastq: [ id: sample.well, sample, well ]; otherwise [ id: sample, sample ]
//
def demuxMeta(fq, splitFastq) {
    def tok = fq.name.tokenize('_')
    def sample = tok[0]
    return splitFastq
        ? [id: "${sample}.${tok[1]}".toString(), sample: sample, well: tok[1]]
        : [id: sample, sample: sample]
}
