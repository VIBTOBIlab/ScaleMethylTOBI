//
// From fastq files to alignments per sample and Tn5 well:
//   1. FastQC of every input fastq file
//   2. Demultiplexing of each fastq set (library and sequencing run) by sample and Tn5 well,
//      with barcode error correction (bc_parser); the bc_parser metrics are merged per library
//   3. Adapter trimming (cutadapt); the sequencing runs of a library are combined here
//   4. Alignment with bwa-meth
//

include { FASTQC        } from '../../../modules/local/fastqc'
include { BC_PARSER     } from '../../../modules/local/bc_parser'
include { MERGE_DEMUX   } from '../../../modules/local/merge_demux'
include { CUTADAPT      } from '../../../modules/local/cutadapt'
include { BWAMETH_ALIGN } from '../../../modules/local/bwameth_align'

workflow FASTQ_DEMUX_TRIM_ALIGN {

    take:
    ch_fastq_sets  // channel: [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] one per library and sequencing run
    ch_samples     // channel: [ map ] one per sample (from the samplesheet)
    samples_csv    // channel: CSV text of the samples, read by bc_parser
    lib_json       // path: library structure definition (.json)
    ch_ref         // channel: [ bwa-meth index directory, reference fasta name ]

    main:
    //
    // 1. FastQC of every input fastq file
    //
    def ch_fastqc_zip = channel.empty()
    if (!params.skip_fastqc) {
        def adapters = params.adapters ?: "${projectDir}/references/SciMETv2_Adapters.tsv"
        // [ [ id: unique report name ], fastq ] in the order fastq_1, fastq_2, index_1, index_2
        def ch_fastqc_input = ch_fastq_sets.flatMap { meta, fastq_1, fastq_2, index_1, index_2 ->
            [fastq_1, fastq_2, index_1, index_2]
                .withIndex()
                .findAll { fq, _idx -> fq }
                .collect { fq, idx -> [[id: meta.fastqc_ids[idx]], fq] }
        }
        FASTQC(ch_fastqc_input, file(adapters, checkIfExists: true))
        ch_fastqc_zip = FASTQC.out.zip
    }

    //
    // 2. Demultiplex each fastq set by sample (and Tn5 well) with barcode error correction
    //
    // bc_parser does not use the threshold column: leaving it out means that a new threshold
    // re-runs only cell calling and what follows it with -resume
    BC_PARSER(samples_csv.map { csv -> dropCsvColumn(csv, 'threshold') }, lib_json.getParent(), lib_json.getName(), ch_fastq_sets)

    // Whether bc_parser splits the reads of each sample by Tn5 well (`split` column of the samples,
    // which defaults to --split_fastq): [ sample: true/false ]
    def ch_split = ch_samples
        .map { row -> [row.sample, row.split == 'true'] }
        .collect(flat: false)
        .map { pairs -> pairs.collectEntries() }

    // Demultiplexed reads of all fastq sets (sequencing runs), grouped per sample and Tn5 well:
    // [ [ id: sample.well, sample, well ], [ R1 fastq files ] ] and the same for R2.
    // The files are sorted by name, so that R1 and R2 stay in step and the order (part of the
    // task hash) does not depend on which bc_parser task finished first (-resume)
    def ch_read1 = BC_PARSER.out.read1_fastq
        .transpose()
        .combine(ch_split)
        .map { _meta, fq, split -> [demuxMeta(fq, split), fq] }
        .groupTuple(sort: { a, b -> a.name <=> b.name })
    def ch_read2 = BC_PARSER.out.read2_fastq
        .transpose()
        .combine(ch_split)
        .map { _meta, fq, split -> [demuxMeta(fq, split), fq] }
        .groupTuple(sort: { a, b -> a.name <=> b.name })

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

    // Merge the bc_parser metrics of all fastq sets of a library, in fastq set order
    MERGE_DEMUX(
        BC_PARSER.out.metrics
            .map { meta, metrics -> [[id: meta.lib], meta.fastq_num, metrics] }
            .groupTuple()
            .map { lib, nums, metrics -> [lib, [nums, metrics].transpose().sort { pair -> pair[0] }.collect { pair -> pair[1] }] },
        lib_json.getParent(),
        lib_json.getName()
    )

    //
    // 3. Trim adapters; the reads of all sequencing runs are combined here
    //
    CUTADAPT(ch_read1.join(ch_read2))

    //
    // 4. Align with bwa-meth
    //
    BWAMETH_ALIGN(CUTADAPT.out.fastq, ch_ref)

    emit:
    bam           = BWAMETH_ALIGN.out.bam           // channel: [ meta, bam ] per sample and Tn5 well
    align_log     = BWAMETH_ALIGN.out.log           // channel: [ meta, bwa_meth.log ] (samtools flagstat, tsv)
    flagstat      = BWAMETH_ALIGN.out.flagstat      // channel: [ meta, flagstat.txt ] (for MultiQC)
    trim_stats    = CUTADAPT.out.stats              // channel: [ meta, trim_stats.json ]
    trim_log      = CUTADAPT.out.log                // channel: [ meta, trim_log ] (for MultiQC)
    demux_metrics = MERGE_DEMUX.out.barcode_metrics // channel: [ [ id: libName ], metrics.json ]
    fastqc_zip    = ch_fastqc_zip                   // channel: [ meta, fastqc.zip ] (for MultiQC)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// CSV text without one of its columns (the values contain no commas or quotes)
//
def dropCsvColumn(csv, column) {
    def lines = csv.readLines().findAll { line -> line.trim() }
    def idx = lines[0].split(',', -1).toList().indexOf(column)
    if (idx < 0) {
        return csv
    }
    return lines.collect { line ->
        def fields = line.split(',', -1).toList()
        fields.removeAt(idx)
        fields.join(',')
    }.join('\n') + '\n'
}

//
// Meta map of a demultiplexed fastq file:
//   split by Tn5 well: <sample>_<well>_S<n>_R<1|2>_<fastq num>.fastq.gz -> [ id: sample.well, sample, well ]
//   not split:         <sample>_S<n>_R<1|2>_<fastq num>.fastq.gz        -> [ id: sample, sample ]
// split: [ sample: whether bc_parser splits its reads by Tn5 well ]
//
def demuxMeta(fq, split) {
    def tok = fq.name.tokenize('_')
    def sample = tok[0]
    return split[sample]
        ? [id: "${sample}.${tok[1]}".toString(), sample: sample, well: tok[1]]
        : [id: sample, sample: sample]
}
