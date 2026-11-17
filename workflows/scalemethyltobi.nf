/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VIBTOBIlab/scalemethyltobi: main workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    1. Reference genome         PREPARE_GENOME
    2. Alignments               FASTQ_DEMUX_TRIM_ALIGN (from fastq files)
                                or BAM_MERGE_RUNS (from the BAM files of two runs)
    3. Methylation calls        BAM_DEDUP_EXTRACT
       (2-3 are replaced by LOAD_PREVIOUS_RESULTS with --reporting_only / --start_post_extraction)
    4. Cells and metrics        CELL_METRICS
    5. Matrices and coverage    MATRIX_GENERATION (not with --reporting_only)
    6. QC reports               REPORTING, MultiQC
    7. Software versions
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/local/multiqc'

include { PREPARE_GENOME         } from '../subworkflows/local/prepare_genome'
include { FASTQ_DEMUX_TRIM_ALIGN } from '../subworkflows/local/fastq_demux_trim_align'
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
    ch_samples     // channel: [ map ] one per sample (sample, libName, barcodes, threshold, resultDir)
    ch_fastq_sets  // channel: [ meta, fastq_1, fastq_2, index_1, index_2 or [] ] one per library and sequencing run
    samples_csv    // channel: CSV text of the samples (bc_parser input, published as samples.csv)
    genome_name    // string: name of a pre-built genome (--genome) or null
    genome_json    // path: genome.json (--genome_json) or null
    lib_json       // path: library structure definition (--lib_structure)
    outdir         // string: output directory

    main:
    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()
    def from_previous_run = params.start_post_extraction || params.reporting_only
    def from_bam_files = params.bam1_dir && params.bam2_dir
    // Trimming and alignment statistics only exist when starting from fastq files
    def trimming_and_mapping = !from_previous_run && !from_bam_files

    // The samples as used by the run
    samples_csv.collectFile(name: 'samples.csv', storeDir: outdir)

    //
    // 1. Reference genome: bwa-meth index, annotation and genome bins
    //
    PREPARE_GENOME(genome_name, genome_json)

    //
    // 2-3. Alignments and methylation calls, or the outputs of previous runs
    //
    // Inputs of CELL_METRICS (per sample) and MATRIX_GENERATION (per sample and Tn5 well)
    def ch_metrics_input = channel.empty()   // [ meta, cell_stats.csv, cellInfo.csv, threshold ]
    def ch_fragment_hist = channel.empty()   // [ meta, fragment_hist.csv ]
    def ch_dedup_stats = channel.empty()     // [ meta, dedup_stats.csv ]
    def ch_demux_metrics = channel.empty()   // [ [ id: libName ], metrics.json or [] ]
    def ch_trim_map_stats = channel.empty()  // [ meta, mapping_stats.csv, trimming_stats.csv ]
    def ch_tss_enrich = channel.empty()      // [ meta, tss_enrich.csv or [] ] (previous runs only)
    def ch_dedup_bam = channel.empty()       // [ meta, dedup.bam ] per Tn5 well (for the TSS enrichment)
    def ch_all_cells = channel.empty()       // [ meta, [ allCells.csv ] ] (previous runs only; otherwise from CELL_METRICS)
    def ch_met_cg = channel.empty()          // [ meta, [ met_CG.parquet ] ] per Tn5 well
    def ch_met_ch = channel.empty()          // [ meta, [ met_CH.parquet ] ] per Tn5 well

    if (from_previous_run) {
        // Restart from the outputs of previous runs (--reporting_only / --start_post_extraction)
        LOAD_PREVIOUS_RESULTS(ch_samples)
        ch_metrics_input = LOAD_PREVIOUS_RESULTS.out.metric_input
        ch_fragment_hist = LOAD_PREVIOUS_RESULTS.out.fragment_hist
        ch_dedup_stats = LOAD_PREVIOUS_RESULTS.out.dedup_stats
        ch_demux_metrics = LOAD_PREVIOUS_RESULTS.out.demux_metrics
        ch_tss_enrich = LOAD_PREVIOUS_RESULTS.out.tss_enrich
        ch_all_cells = LOAD_PREVIOUS_RESULTS.out.all_cells
        ch_met_cg = LOAD_PREVIOUS_RESULTS.out.met_cg
        ch_met_ch = LOAD_PREVIOUS_RESULTS.out.met_ch
    } else {
        // 2. Alignments per sample and Tn5 well
        def ch_bam = channel.empty()
        def ch_align_logs = channel.empty()
        def ch_trim_stats = channel.empty()
        if (from_bam_files) {
            BAM_MERGE_RUNS(params.bam1_dir, params.bam2_dir)
            ch_bam = BAM_MERGE_RUNS.out.bam
            // No bc_parser metrics when starting from BAM files
            ch_demux_metrics = ch_samples.map { row -> [[id: row.libName], []] }.unique()
        } else {
            FASTQ_DEMUX_TRIM_ALIGN(ch_fastq_sets, ch_samples, samples_csv, lib_json, PREPARE_GENOME.out.ref)
            ch_bam = FASTQ_DEMUX_TRIM_ALIGN.out.bam
            ch_align_logs = FASTQ_DEMUX_TRIM_ALIGN.out.align_log
            ch_trim_stats = FASTQ_DEMUX_TRIM_ALIGN.out.trim_stats
            ch_demux_metrics = FASTQ_DEMUX_TRIM_ALIGN.out.demux_metrics
            ch_multiqc_files = ch_multiqc_files
                .mix(FASTQ_DEMUX_TRIM_ALIGN.out.fastqc_zip.map { _meta, zip -> zip })
                .mix(FASTQ_DEMUX_TRIM_ALIGN.out.trim_log.map { _meta, log -> log })
                .mix(FASTQ_DEMUX_TRIM_ALIGN.out.flagstat.map { _meta, flagstat -> flagstat })
        }

        // 3. Deduplication, methylation calls and per-sample statistics
        BAM_DEDUP_EXTRACT(ch_bam, PREPARE_GENOME.out.ref, PREPARE_GENOME.out.filter_chrs, ch_align_logs, ch_trim_stats, trimming_and_mapping)
        ch_metrics_input = BAM_DEDUP_EXTRACT.out.merged_stats
            .join(ch_samples.map { row -> [[id: row.sample], toIntOr0(row.threshold)] })
        ch_fragment_hist = BAM_DEDUP_EXTRACT.out.fragment_hist
        ch_dedup_stats = BAM_DEDUP_EXTRACT.out.dedup_stats
        ch_trim_map_stats = BAM_DEDUP_EXTRACT.out.trimming_and_mapping_stats
        ch_dedup_bam = BAM_DEDUP_EXTRACT.out.dedup_bam
        ch_met_cg = BAM_DEDUP_EXTRACT.out.met_cg
        ch_met_ch = BAM_DEDUP_EXTRACT.out.met_ch
    }

    //
    // 4. Cell calling, per-cell metrics (incl. TSS enrichment) and library metrics
    //
    CELL_METRICS(
        ch_metrics_input,
        ch_fragment_hist,
        ch_dedup_stats,
        ch_demux_metrics,
        ch_trim_map_stats,
        ch_tss_enrich,
        ch_dedup_bam,
        ch_samples,
        lib_json,
        PREPARE_GENOME.out.tss_bed,
        PREPARE_GENOME.out.background_bed,
        trimming_and_mapping,
        from_previous_run
    )
    if (!from_previous_run) {
        ch_all_cells = CELL_METRICS.out.all_cells.groupTuple()
    }

    //
    // 5. Binned methylation matrices and per-cell methylation coverage files
    //
    def ch_cg_mtx = channel.empty()
    def ch_cg_mtx_barcodes = channel.empty()
    if (!params.reporting_only) {
        MATRIX_GENERATION(ch_all_cells, ch_met_cg, ch_met_ch, PREPARE_GENOME.out.tiles_cg, PREPARE_GENOME.out.tiles_ch)
        ch_cg_mtx = MATRIX_GENERATION.out.cg_mtx
        ch_cg_mtx_barcodes = MATRIX_GENERATION.out.cg_mtx_barcodes
    }

    //
    // 6. QC reports: per sample and per library, and MultiQC (read QC, trimming, alignment)
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
        !params.reporting_only && !params.skip_window_matrix
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
    // 7. Collate and save software versions (the `versions` topic of all modules)
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
