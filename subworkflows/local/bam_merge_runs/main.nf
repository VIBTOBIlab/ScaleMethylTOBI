//
// Merge the per-well BAM files of two previous alignment runs (--bam1_dir / --bam2_dir)
//

include { MERGE_BAM } from '../../../modules/local/merge_bam'

workflow BAM_MERGE_RUNS {

    take:
    bam1_dir // string: bwameth/alignments directory of the first run
    bam2_dir // string: bwameth/alignments directory of the second run

    main:
    // The BAM files of a previous run (--save_bam): <dir>/<sample>.<well>.bam in bwameth/alignments,
    // or <dir>/<sample>.<well>/<sample>.<well>.bam in alignments/bam before version 1.5.0
    // [ meta, bam ]
    def ch_bam1 = channel.fromList(previousBams(bam1_dir)).map { bam -> [bamMeta(bam), bam] }
    def ch_bam2 = channel.fromList(previousBams(bam2_dir)).map { bam -> [bamMeta(bam), bam] }

    MERGE_BAM(ch_bam1.join(ch_bam2, failOnDuplicate: true))

    emit:
    bam = MERGE_BAM.out.bam // channel: [ meta, bam ]
}

//
// BAM files of a previous run: <dir>/*.bam, or <dir>/*/*.bam (layout before version 1.5.0)
//
def previousBams(dir) {
    def bams = files("${dir}/*.bam")
    if (!bams) {
        bams = files("${dir}/*/*.bam")
    }
    if (!bams) {
        error("No BAM files in ${dir}")
    }
    return bams
}

//
// Meta map of <sample>.<well>.bam: [ id: sample.well, sample, well ]
//
def bamMeta(bam) {
    def ns = bam.getBaseName().tokenize('.')
    return [id: "${ns[0]}.${ns[1]}".toString(), sample: ns[0], well: ns[1]]
}
