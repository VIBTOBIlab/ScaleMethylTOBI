/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VIBTOBIlab/scalemethyltobi: main workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    1. Reference genome         PREPARE_GENOME
    2. Alignments               FASTQ_DEMUX_TRIM_ALIGN
    3. Methylation calls        BAM_DEDUP_EXTRACT
    4. Cells and metrics        CELL_METRICS
    5. Matrices and coverage    MATRIX_GENERATION
    6. Cell names for Amethyst  PREFIX_CELL_NAMES (not with --skip_cell_prefix)
    7. QC reports               REPORTING, MultiQC
    8. Software versions
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/local/multiqc'
include { PREFIX_CELL_NAMES      } from '../modules/local/prefix_cell_names'

include { PREPARE_GENOME         } from '../subworkflows/local/prepare_genome'
include { FASTQ_DEMUX_TRIM_ALIGN } from '../subworkflows/local/fastq_demux_trim_align'
include { BAM_DEDUP_EXTRACT      } from '../subworkflows/local/bam_dedup_extract'
include { CELL_METRICS           } from '../subworkflows/local/cell_metrics'
include { MATRIX_GENERATION      } from '../subworkflows/local/matrix_generation'
include { REPORTING              } from '../subworkflows/local/reporting'

include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SCALEMETHYLTOBI {

    take:
    ch_samples     // channel: [ map ] one per sample (sample, libName, barcodes, threshold, split)
    ch_fastq_sets  // channel: [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] one per library and sequencing run
    samples_csv    // channel: CSV text of the samples (bc_parser input, published as samples.csv)
    genome_name    // string: name of a pre-built genome (--genome) or null
    genome_json    // path: genome.json (--genome_json) or null
    lib_json       // path: library structure definition (--lib_structure)
    outdir         // string: output directory

    main:
    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    // The samples as used by the run
    samples_csv.collectFile(name: 'samples.csv', storeDir: outdir)

    //
    // 1. Reference genome: bwa-meth index, annotation and genome bins
    //
    PREPARE_GENOME(genome_name, genome_json)

    //
    // 2. Alignments per sample and Tn5 well
    //
    FASTQ_DEMUX_TRIM_ALIGN(ch_fastq_sets, ch_samples, samples_csv, lib_json, PREPARE_GENOME.out.ref)
    ch_multiqc_files = ch_multiqc_files
        .mix(FASTQ_DEMUX_TRIM_ALIGN.out.fastqc_zip.map { _meta, zip -> zip })
        .mix(FASTQ_DEMUX_TRIM_ALIGN.out.trim_log.map { _meta, log -> log })
        .mix(FASTQ_DEMUX_TRIM_ALIGN.out.flagstat.map { _meta, flagstat -> flagstat })

    //
    // 3. Deduplication, methylation calls and per-sample statistics
    //
    BAM_DEDUP_EXTRACT(
        FASTQ_DEMUX_TRIM_ALIGN.out.bam,
        PREPARE_GENOME.out.ref,
        PREPARE_GENOME.out.filter_chrs,
        FASTQ_DEMUX_TRIM_ALIGN.out.align_log,
        FASTQ_DEMUX_TRIM_ALIGN.out.trim_stats
    )

    //
    // 4. Cell calling, per-cell metrics (incl. TSS enrichment) and library metrics
    //
    CELL_METRICS(
        BAM_DEDUP_EXTRACT.out.merged_stats.join(ch_samples.map { row -> [[id: row.sample], toIntOr0(row.threshold)] }),
        BAM_DEDUP_EXTRACT.out.fragment_hist,
        BAM_DEDUP_EXTRACT.out.dedup_stats,
        FASTQ_DEMUX_TRIM_ALIGN.out.demux_metrics,
        BAM_DEDUP_EXTRACT.out.trimming_and_mapping_stats,
        BAM_DEDUP_EXTRACT.out.dedup_bam,
        ch_samples,
        lib_json,
        PREPARE_GENOME.out.tss_bed,
        PREPARE_GENOME.out.background_bed
    )

    //
    // 5. Binned methylation matrices and per-cell methylation coverage files
    //
    MATRIX_GENERATION(
        CELL_METRICS.out.all_cells.map { meta, allCells -> [meta, [allCells]] },
        BAM_DEDUP_EXTRACT.out.met_cg,
        BAM_DEDUP_EXTRACT.out.met_ch,
        PREPARE_GENOME.out.tiles_cg,
        PREPARE_GENOME.out.tiles_ch
    )
    def ch_cg_mtx = MATRIX_GENERATION.out.cg_mtx
    def ch_cg_mtx_barcodes = MATRIX_GENERATION.out.cg_mtx_barcodes

    //
    // 6. Cell names <sample>_<barcode> in the files of samples/ (the Amethyst .h5 files are written
    //    with these names by MATRIX_GENERATION), so that all samples and libraries can be loaded
    //    together in Amethyst. The pipeline itself uses the barcodes.
    //
    if (!params.skip_cell_prefix) {
        PREFIX_CELL_NAMES(
            CELL_METRICS.out.all_cells
                .join(ch_cg_mtx_barcodes, remainder: true)
                .map { meta, all_cells, barcodes -> [meta, all_cells, barcodes ?: []] }
        )
    }

    //
    // 7. QC reports: per sample and per library, and MultiQC (read QC, trimming, alignment)
    //
    REPORTING(
        CELL_METRICS.out.report_input,
        CELL_METRICS.out.passing_cell_stats,
        CELL_METRICS.out.csv_folder,
        CELL_METRICS.out.combined_csv,
        CELL_METRICS.out.library_stats,
        ch_cg_mtx,
        ch_cg_mtx_barcodes,
        lib_json,
        !params.skip_window_matrix
    )

    def ch_multiqc_report = channel.empty()
    if (!params.skip_multiqc) {
        MULTIQC(
            ch_multiqc_files.collect(),
            file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true)
        )
        ch_multiqc_report = MULTIQC.out.report
    }

    //
    // 8. Collate and save software versions (the `versions` topic of all modules)
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'scalemethyltobi_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    emit:
    multiqc_report = ch_multiqc_report // channel: path(multiqc_report.html)
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Integer value of a samples.csv column; 0 for missing or non-integer values
//
def toIntOr0(str) {
    return (str != null && str.isInteger()) ? (str as int) : 0
}
