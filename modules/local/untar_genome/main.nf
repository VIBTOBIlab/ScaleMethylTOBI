// Download (or read) and unpack a pre-built reference genome archive (conf/genomes.config)
// The archive holds one directory with genome.json, the bwa-meth index and the annotation files
process UNTAR_GENOME {
    tag "${name}"
    label 'process_single'

    container "public.ecr.aws/o5l3p3e4/scale-methyl-tools:2025-06-16-213106"

    input:
    tuple val(name), val(url), path(archive) // genome name; URL of the .tgz archive, or the local archive (url empty)

    output:
    tuple val(name), path("${name}"), emit: genome
    tuple val("${task.process}"), val('tar'), eval("tar --version | head -1 | sed 's/^tar (GNU tar) //'"), emit: versions_tar, topic: versions

    script:
    // Remote archives are streamed: no copy of the (large) archive is kept
    def unpack = url ? "wget -q -O - ${url} | tar -xz -C ${name} --strip-components=1" : "tar -xzf ${archive} -C ${name} --strip-components=1"
    """
    mkdir ${name}
    ${unpack}
    if [[ ! -f ${name}/genome.json ]]; then
        echo "No genome.json at the top level of the ${name} genome archive" >&2
        exit 1
    fi
    """
}
