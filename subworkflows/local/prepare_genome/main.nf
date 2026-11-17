//
// Load the reference genome definition (genome.json) and create the genome bins
// used for the methylation matrices
//

include { CREATE_CHROM_SIZES                         } from '../../../modules/local/create_chrom_sizes'
include { CREATE_WINDOWS_BED as CREATE_WINDOWS_BED_CG } from '../../../modules/local/create_windows_bed'
include { CREATE_WINDOWS_BED as CREATE_WINDOWS_BED_CH } from '../../../modules/local/create_windows_bed'

workflow PREPARE_GENOME {

    take:
    genome // map: reference genome definition, see loadGenome()

    main:
    def tile_size_cg = genomeTileSizeCG(genome)
    def tile_size_ch = genomeTileSizeCH(genome)
    def blacklist = genome.genomeWindowBlackList ?: []

    def ch_tiles_cg = genome.genomeTiles ? channel.value(genome.genomeTiles) : channel.empty()
    def ch_tiles_ch = genome.genomeTilesCH ? channel.value(genome.genomeTilesCH) : channel.empty()

    // chrom.sizes only needs to be created if a window tile size is set
    if (tile_size_cg || tile_size_ch) {
        def ch_chrom_sizes = channel.empty()
        if (genome.chromSizes) {
            ch_chrom_sizes = channel.value(genome.chromSizes)
        } else {
            // Use the bwa-meth reference fasta to create the chrom.sizes file
            CREATE_CHROM_SIZES(genome.bwa_index.resolve(genome.ref_fasta))
            ch_chrom_sizes = CREATE_CHROM_SIZES.out.chrom_sizes
        }

        if (tile_size_cg) {
            CREATE_WINDOWS_BED_CG(ch_chrom_sizes, blacklist, tile_size_cg, params.minimum_window_size, 'CG')
            ch_tiles_cg = CREATE_WINDOWS_BED_CG.out.bed
        }
        if (tile_size_ch && params.calculate_ch) {
            CREATE_WINDOWS_BED_CH(ch_chrom_sizes, blacklist, tile_size_ch, params.minimum_window_size, 'CH')
            ch_tiles_ch = CREATE_WINDOWS_BED_CH.out.bed
        }
    }

    emit:
    tiles_cg = ch_tiles_cg // channel: path(bed) genome bins for the CG matrix
    tiles_ch = ch_tiles_ch // channel: path(bed) genome bins for the CH matrix
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Resolve a path from genome.json relative to the directory of genome.json
// Missing or empty entries ("") are not set
//
def expandPath(path, baseDir) {
    if (!path) {
        return null
    }
    if (path =~ /^s3/) {
        return file(path)
    }
    return baseDir.resolve(path)
}

//
// Load genome.json, resolve its paths and check that genome bins can be defined
//
def loadGenome(json) {
    def baseDir = json.getParent()
    def genome = new groovy.json.JsonSlurper().parse(json)
    genome.bwa_index = expandPath(genome.bwa_index, baseDir)
    genome.filter_chrs = expandPath(genome.filter_chrs, baseDir)
    genome.genomeTileBlackList = expandPath(genome.genomeTileBlackList, baseDir)
    genome.genomeWindowBlackList = expandPath(genome.genomeWindowBlackList, baseDir)
    genome.genomeTiles = expandPath(genome.genomeTiles, baseDir)
    genome.genomeTilesCH = expandPath(genome.genomeTilesCH, baseDir)
    genome.chromSizes = expandPath(genome.chromSizes, baseDir)
    genome.tssWin = expandPath(genome.tssWin, baseDir)
    genome.backgroundWin = expandPath(genome.backgroundWin, baseDir)

    if (!genome.bwa_index || !genome.ref_fasta) {
        error("genome.json must define 'bwa_index' and 'ref_fasta' (bwa-meth index)")
    }
    if (genome.genomeTiles && params.window_tile_size_cg) {
        log.warn("genomeTiles and --window_tile_size_cg are both set. Ignoring --window_tile_size_cg.")
    }
    if (!genome.genomeTiles && !params.window_tile_size_cg) {
        error("No genomeTiles in genome.json or --window_tile_size_cg set")
    }
    if (genome.genomeTilesCH && params.window_tile_size_ch) {
        log.warn("genomeTilesCH and --window_tile_size_ch are both set. Ignoring --window_tile_size_ch.")
    }
    if (!genome.genomeTilesCH && !params.window_tile_size_ch) {
        error("No genomeTilesCH in genome.json or --window_tile_size_ch set")
    }
    return genome
}

//
// Window size for the CG matrix; null when genome.json provides the bins
//
def genomeTileSizeCG(genome) {
    return genome.genomeTiles ? null : params.window_tile_size_cg
}

//
// Window size for the CH matrix; null when genome.json provides the bins
//
def genomeTileSizeCH(genome) {
    return genome.genomeTilesCH ? null : params.window_tile_size_ch
}
