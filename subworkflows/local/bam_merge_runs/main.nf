//
// Merge the per-well BAM files of two previous alignment runs (--bam1_dir / --bam2_dir)
//

include { MERGE_BAM } from '../../../modules/local/merge_bam'

workflow BAM_MERGE_RUNS {

    take:
    bam1_dir // string: alignments/bam directory of the first run
    bam2_dir // string: alignments/bam directory of the second run

    main:
    // The directory structure is expected to match the alignments/bam output of this workflow:
    // <dir>/<sample>.<well>/<sample>.<well>.bam
    // [ sample, well, [ bam ] ]
    def ch_bam1 = channel.fromPath("${bam1_dir}/*/*bam", checkIfExists: true)
        .map { bam -> bamSampleWell(bam) }
        .groupTuple(by: [0, 1])
    def ch_bam2 = channel.fromPath("${bam2_dir}/*/*bam", checkIfExists: true)
        .map { bam -> bamSampleWell(bam) }
        .groupTuple(by: [0, 1])

    MERGE_BAM(ch_bam1.join(ch_bam2, by: [0, 1], failOnDuplicate: true))

    emit:
    bam = MERGE_BAM.out.bam // channel: [ sample.well, bam ]
}

//
// [ sample, well, bam ] from <sample>.<well>.bam
//
def bamSampleWell(bam) {
    def ns = bam.getBaseName().tokenize('.')
    return [ns[0], ns[1], bam]
}
