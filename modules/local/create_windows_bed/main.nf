// Tile the genome into fixed-size windows (optionally removing blacklisted regions)
process CREATE_WINDOWS_BED {
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    path chrom_sizes
    path blacklist           // Optional: [] when no blacklist is used
    val tile_size            // Window size in bp
    val minimum_window_size  // Minimum window size after blacklisted regions are removed
    val context              // CG or CH; used in the output file name

    output:
    path "genome_tiles_${context}.bed", emit: bed
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def blacklist_opt = blacklist ? " --blacklist ${blacklist}" : ''
    """
    create_windows_bed.py --genomeTiles ${tile_size} --chromSizes ${chrom_sizes} --output genome_tiles_${context}.bed --minimumWindowSize ${minimum_window_size}${blacklist_opt}
    """
}
