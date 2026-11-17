// Generate the html QC report of a sample
process GENERATE_SAMPLE_REPORT {
    tag "${meta.id}"
    label 'process_medium'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(meta), path("allCells.csv"), path(fragment_hist), path(dedup_stats), path(mapping_stats), path(trimming_stats), path(tss_enrich), val(library_name), val(sample_barcodes), path(passing_cell_stats), path(csv_folder), path(cg_mtx), path(cg_mtx_barcodes)
    path lib_struct_dir         // Directory containing the library structure definition
    val lib_struct_name         // Filename of the library structure definition .json
    val trimming_and_mapping    // Whether trimming and mapping statistics are available
    val reporting_only          // Whether the workflow only regenerates reports (--reporting_only)
    val workflow_version

    output:
    tuple val(meta), path("${meta.id}/${meta.id}.report.html")             , emit: report
    tuple val(meta), path("${meta.id}/png")                                 , emit: png
    tuple val(meta), path("${meta.id}/csv/${meta.id}.report_clusters.tsv"), emit: clusters  , optional: true
    tuple val(meta), path("${meta.id}.tss_enrich.csv")                     , emit: tss_enrich, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    def opts = trimming_and_mapping ? "--trimming_stats ${trimming_stats} --mapping_stats ${mapping_stats} " : ''
    if (reporting_only) {
        opts = opts + "--reporting_only"
    }
    def mtx_opts = cg_mtx ? "--mtxFile ${cg_mtx} --mtxBarcodes ${cg_mtx_barcodes}" : ""
    """
    export DATAPANE_CDN_BASE="https://d3j2ibc7el7s1k.cloudfront.net/v0.17.0"
    export TMPDIR=\$(mktemp -p \$(pwd) -d)
    generate_sample_report.py --sample_name ${meta.id} --out_dir ${meta.id} --all_cells allCells.csv --library_structure_json ${lib_struct_dir}/${lib_struct_name} \
        --fragment_hist ${fragment_hist} --tss_enrich ${tss_enrich} --dedup_stats ${dedup_stats} ${opts} --library_name ${library_name} --sample_barcodes "${sample_barcodes}" --workflow_version ${workflow_version} \
        --passing_cell_stats ${passing_cell_stats} --csv_folder ${csv_folder} ${mtx_opts}
    """
}
