/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { REGULARIZE_SAMPLES_CSV } from '../modules/local/regularize_samples_csv'
include { BWAMETH_ALIGN          } from '../modules/local/bwameth_align'
include { MERGE_STATS            } from '../modules/local/merge_stats'

include { PREPARE_GENOME         } from '../subworkflows/local/prepare_genome'
include { loadGenome             } from '../subworkflows/local/prepare_genome'
include { FASTQ_DEMUX_TRIM       } from '../subworkflows/local/fastq_demux_trim'
include { BAM_MERGE_RUNS         } from '../subworkflows/local/bam_merge_runs'
include { BAM_DEDUP_EXTRACT      } from '../subworkflows/local/bam_dedup_extract'
include { LOAD_PREVIOUS_RESULTS  } from '../subworkflows/local/load_previous_results'
include { toIntOr0               } from '../subworkflows/local/load_previous_results'
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
    samples_csv // path: samples.csv (--input)
    genome_json // path: genome.json (--genome)
    lib_json    // path: library structure definition (--lib_structure)
    outdir      // string: output directory

    main:
    def ch_versions = channel.empty()

    //
    // Samples and reference genome
    //
    REGULARIZE_SAMPLES_CSV(samples_csv, lib_json.getName(), lib_json.getParent())
    def ch_samples_csv = REGULARIZE_SAMPLES_CSV.out.csv
    def ch_samples = ch_samples_csv.splitCsv(header: true, strip: true)

    def genome = loadGenome(genome_json)
    PREPARE_GENOME(genome)

    def ch_all_cells = channel.empty()
    def ch_met_cg = channel.empty()
    def ch_met_ch = channel.empty()
    def trimming_and_mapping = false
    def from_previous_run = params.start_post_extraction || params.reporting_only

    if (!from_previous_run) {
        //
        // Reads: demultiplex, trim and align (or merge the BAM files of two previous runs)
        //
        def ch_bam = channel.empty()
        def ch_align_logs = channel.empty()
        def ch_trim_stats = channel.empty()
        def ch_demux_metrics = channel.empty()
        if (params.bam1_dir && params.bam2_dir) {
            BAM_MERGE_RUNS(params.bam1_dir, params.bam2_dir)
            ch_bam = BAM_MERGE_RUNS.out.bam
            // Trimming and mapping stats do not exist when starting from BAM files
            ch_demux_metrics = ch_samples.map { row -> [row.libName, []] }.unique()
        } else {
            FASTQ_DEMUX_TRIM(ch_samples, ch_samples_csv, lib_json, params.fastq_dir, params.run_folder)
            BWAMETH_ALIGN(FASTQ_DEMUX_TRIM.out.trim_fastq, genome.bwa_index, genome.ref_fasta)
            ch_bam = BWAMETH_ALIGN.out.bam
            ch_align_logs = BWAMETH_ALIGN.out.log
            ch_trim_stats = FASTQ_DEMUX_TRIM.out.trim_stats
            ch_demux_metrics = FASTQ_DEMUX_TRIM.out.demux_metrics
            trimming_and_mapping = true
        }

        //
        // Deduplicate reads and extract methylation calls
        //
        BAM_DEDUP_EXTRACT(ch_bam, genome)

        //
        // Merge the per-well statistics of each sample
        //
        // [ sample, [ cell_stats ], [ fragment_hist ], [ cellInfo ], [ dedup_stats ] ]
        def ch_dedup_report_stats = BAM_DEDUP_EXTRACT.out.reads_frags
            .join(BAM_DEDUP_EXTRACT.out.cell_info)
            .join(BAM_DEDUP_EXTRACT.out.dedup_stats)
        // + [ [ aligner logs ], [ trimming stats ] ] (empty lists when starting from BAM files)
        def ch_report_stats = trimming_and_mapping
            ? ch_dedup_report_stats
                .join(ch_align_logs.map { _id, log -> [log.getName().tokenize('.')[0], log] }.groupTuple())
                .join(ch_trim_stats.map { _id, stats -> [stats.getName().tokenize('.')[0], stats] }.groupTuple())
            : ch_dedup_report_stats.map { row -> row + [[], []] }
        MERGE_STATS(ch_report_stats)

        //
        // Call cells and compute per-cell metrics
        //
        CELL_METRICS(
            MERGE_STATS.out.merged_stats.join(ch_samples.map { row -> [row.sample, toIntOr0(row.threshold)] }),
            MERGE_STATS.out.fragment_hist,
            MERGE_STATS.out.dedup_stats,
            ch_demux_metrics,
            MERGE_STATS.out.trimming_and_mapping_stats,
            channel.empty(),
            BAM_DEDUP_EXTRACT.out.dedup_bam,
            ch_samples,
            lib_json,
            genome,
            trimming_and_mapping,
            false
        )

        ch_all_cells = CELL_METRICS.out.all_cells.groupTuple()
        ch_met_cg = BAM_DEDUP_EXTRACT.out.met_cg.groupTuple()
        ch_met_ch = BAM_DEDUP_EXTRACT.out.met_ch.groupTuple()
    } else {
        //
        // Restart from the outputs of previous runs
        //
        LOAD_PREVIOUS_RESULTS(ch_samples)

        CELL_METRICS(
            LOAD_PREVIOUS_RESULTS.out.metric_input,
            LOAD_PREVIOUS_RESULTS.out.fragment_hist,
            LOAD_PREVIOUS_RESULTS.out.dedup_stats,
            LOAD_PREVIOUS_RESULTS.out.demux_metrics,
            channel.empty(),
            LOAD_PREVIOUS_RESULTS.out.tss_enrich,
            channel.empty(),
            ch_samples,
            lib_json,
            genome,
            false,
            true
        )

        ch_all_cells = LOAD_PREVIOUS_RESULTS.out.all_cells
        ch_met_cg = LOAD_PREVIOUS_RESULTS.out.met_cg
        ch_met_ch = LOAD_PREVIOUS_RESULTS.out.met_ch
    }

    //
    // Binned methylation matrices and per-cell methylation coverage files
    //
    def ch_cg_mtx = channel.empty()
    def ch_cg_mtx_barcodes = channel.empty()
    if (!params.reporting_only) {
        MATRIX_GENERATION(ch_all_cells, ch_met_cg, ch_met_ch, PREPARE_GENOME.out.tiles_cg, PREPARE_GENOME.out.tiles_ch)
        ch_cg_mtx = MATRIX_GENERATION.out.cg_mtx
        ch_cg_mtx_barcodes = MATRIX_GENERATION.out.cg_mtx_barcodes
    }

    //
    // QC reports
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
        trimming_and_mapping,
        params.reporting_only,
        !params.reporting_only && params.window_matrix_out
    )

    //
    // Collate and save software versions
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
    versions = ch_versions // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
