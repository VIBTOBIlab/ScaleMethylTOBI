//
// Prepare the reference genome:
//   1. The genome: a pre-built genome selected by name (--genome; the archive is downloaded and
//      unpacked, see conf/genomes.config) or your own genome.json (--genome_json)
//   2. chrom.sizes, from genome.json or created from the reference fasta (only to make bins)
//   3. Genome bins for the CG and CH matrices, from genome.json or made from chrom.sizes with
//      --window_tile_size_cg / --window_tile_size_ch
//

include { UNTAR_GENOME                               } from '../../../modules/local/untar_genome'
include { CREATE_CHROM_SIZES                         } from '../../../modules/local/create_chrom_sizes'
include { CREATE_WINDOWS_BED as CREATE_WINDOWS_BED_CG } from '../../../modules/local/create_windows_bed'
include { CREATE_WINDOWS_BED as CREATE_WINDOWS_BED_CH } from '../../../modules/local/create_windows_bed'

workflow PREPARE_GENOME {

    take:
    genome_name // string: name of a pre-built genome (--genome) or null
    genome_json // path: genome.json (--genome_json) or null

    main:
    //
    // 1. The reference genome as a map with the paths of genome.json
    //
    def ch_genome = channel.empty()
    if (genome_json) {
        ch_genome = channel.value(loadGenome(genome_json))
    } else {
        def archive = params.genomes[genome_name].archive.toString()
        def remote = archive =~ /^(https?|ftp):\/\//
        UNTAR_GENOME(channel.of([genome_name, remote ? archive : '', remote ? [] : file(archive, checkIfExists: true)]))
        ch_genome = UNTAR_GENOME.out.genome
            .map { _name, dir -> loadGenome(dir.resolve('genome.json')) }
            .first()
    }

    def ch_ref = ch_genome.map { genome -> [genome.bwa_index, genome.ref_fasta] }

    //
    // 2-3. Genome bins for the CG and CH matrices: from the genome, or made from the chromosome sizes.
    //      The genome is only known at run time (pre-built archives), so the choice is made with
    //      filter: a process only runs when its input channel is not empty.
    //
    def ch_make_cg = ch_genome.filter { genome -> !genome.genomeTiles }
    def ch_make_ch = ch_genome.filter { genome -> !genome.genomeTilesCH && !params.skip_ch_context }

    // chrom.sizes: from the genome, or created from the reference fasta when bins must be made
    def ch_needs_sizes = ch_make_cg.mix(ch_make_ch).first()
    CREATE_CHROM_SIZES(
        ch_needs_sizes
            .filter { genome -> !genome.chromSizes }
            .map { genome -> genome.bwa_index.resolve(genome.ref_fasta) }
    )
    def ch_chrom_sizes = ch_needs_sizes
        .filter { genome -> genome.chromSizes }
        .map { genome -> genome.chromSizes }
        .mix(CREATE_CHROM_SIZES.out.chrom_sizes)
        .first()

    CREATE_WINDOWS_BED_CG(
        ch_make_cg.combine(ch_chrom_sizes).map { _genome, sizes -> sizes },
        ch_genome.map { genome -> genome.genomeWindowBlackList ?: [] },
        params.window_tile_size_cg,
        params.minimum_window_size,
        'CG'
    )
    CREATE_WINDOWS_BED_CH(
        ch_make_ch.combine(ch_chrom_sizes).map { _genome, sizes -> sizes },
        ch_genome.map { genome -> genome.genomeWindowBlackList ?: [] },
        params.window_tile_size_ch,
        params.minimum_window_size,
        'CH'
    )

    def ch_tiles_cg = ch_genome
        .filter { genome -> genome.genomeTiles }
        .map { genome -> genome.genomeTiles }
        .mix(CREATE_WINDOWS_BED_CG.out.bed)
        .first()
    def ch_tiles_ch = ch_genome
        .filter { genome -> genome.genomeTilesCH }
        .map { genome -> genome.genomeTilesCH }
        .mix(CREATE_WINDOWS_BED_CH.out.bed)
        .first()

    emit:
    genome         = ch_genome                                                // channel: map of the reference genome
    ref            = ch_ref                                                   // channel: [ bwa-meth index directory, reference fasta name ]
    filter_chrs    = ch_genome.map { genome -> genome.filter_chrs }           // channel: path(chromosome labels for sc_dedup)
    tss_bed        = ch_genome.map { genome -> genome.tssWin ?: [] }          // channel: path(TSS windows)
    background_bed = ch_genome.map { genome -> genome.backgroundWin ?: [] }   // channel: path(background windows)
    tiles_cg       = ch_tiles_cg                                              // channel: path(bed) genome bins for the CG matrix
    tiles_ch       = ch_tiles_ch                                              // channel: path(bed) genome bins for the CH matrix
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
// Load genome.json, resolve its paths and check its entries
//
def loadGenome(json) {
    def baseDir = json.getParent()
    def genome = new groovy.json.JsonSlurper().parse(json)
    ['bwa_index', 'filter_chrs', 'genomeTileBlackList', 'genomeWindowBlackList', 'genomeTiles',
     'genomeTilesCH', 'chromSizes', 'tssWin', 'backgroundWin'].each { key ->
        genome[key] = expandPath(genome[key], baseDir)
    }

    if (!genome.bwa_index || !genome.ref_fasta) {
        error("${json} must define 'bwa_index' and 'ref_fasta' (bwa-meth index)")
    }
    if (!genome.filter_chrs) {
        error("${json} must define 'filter_chrs' (chromosome labels for deduplication)")
    }
    if (!params.skip_tss_enrich && !(genome.tssWin && genome.backgroundWin)) {
        error("TSS enrichment needs 'tssWin' and 'backgroundWin' in ${json}; use --skip_tss_enrich to skip it")
    }
    if (genome.genomeTiles && params.window_tile_size_cg) {
        log.warn("genomeTiles and --window_tile_size_cg are both set. Ignoring --window_tile_size_cg.")
    }
    if (!genome.genomeTiles && !params.window_tile_size_cg) {
        error("No genome bins for the CG matrix: set genomeTiles in ${json} or --window_tile_size_cg")
    }
    if (genome.genomeTilesCH && params.window_tile_size_ch) {
        log.warn("genomeTilesCH and --window_tile_size_ch are both set. Ignoring --window_tile_size_ch.")
    }
    if (!genome.genomeTilesCH && !params.window_tile_size_ch) {
        error("No genome bins for the CH matrix: set genomeTilesCH in ${json} or --window_tile_size_ch")
    }
    return genome
}
