#!/usr/bin/env nextflow

def helpMessage() {
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run main.nf --bams sample.bam [Options]
    
    Inputs Options:
    --input         Input file

    Resource Options:
    --max_cpus      Maximum number of CPUs (int)
                    (default: $params.max_cpus)  
    --max_memory    Maximum memory (memory unit)
                    (default: $params.max_memory)
    --max_time      Maximum time (time unit)
                    (default: $params.max_time)
    See here for more info: https://github.com/lifebit-ai/hla/blob/master/docs/usage.md
    """.stripIndent()
}

// Show help message
if (params.help) {
  helpMessage()
  exit 0
}

// Define channels from repository files
projectDir = workflow.projectDir
ch_run_sh_script = Channel.fromPath("${projectDir}/bin/run.sh")

// Define Channels from input

if (!params.table_vcf_location && !params.input_folder_location) {
    exit 1, "Please provide input either via a csv with --table_vcf_location or a path to a folder with --input_folder_location"
}

if (params.table_vcf_location) {
Channel
    .fromPath(params.table_vcf_location)
    .ifEmpty { exit 1, "Cannot find input file : ${params.table_vcf_location}" }
    .splitCsv(skip:1)
    .map {file_name, vcf_WGS, vcf_WGS_idx -> [ file_name, file(vcf_WGS), file(vcf_WGS_idx) ] }
    .set { ch_input }
}

if (params.input_folder_location) {
Channel.fromPath("${params.input_folder_location}/**.{${params.file_suffix},${params.index_suffix}}")
       .map { it -> [ file(it).simpleName.minus(".${params.index_suffix}").minus(".${params.file_suffix}"), "s3:/"+it] }
       .groupTuple(by:0)
       .map { name, files_pair -> [ name, files_pair[0], files_pair[1] ] }
       .map { name, base_file, index -> [ name, file(base_file), file(index) ] }
       .take( params.number_of_files_to_process )
       .set { ch_input }
}

// Define Channels from input
Channel
    .fromPath(params.region_file_location)
    .ifEmpty { exit 1, "Cannot find input file : ${params.region_file_location}" }
    .set { ch_region_file }

// Define Process
process subset_vcfs {
    tag "$sample_name"
    label 'low_memory'
    publishDir "${params.outdir}", mode: 'copy' // in results by default

    input:
    set val(file_name), file(vcf_WGS), file(vcf_WGS_idx) from ch_input
    each file(region_file) from ch_region_file // file is going to be lost after firts iteration.
    
    output:
    file "*_exons_plus1k*" into ch_out
    
    script:
    if (params.generate_vcf_index == true)
    """
    tabix -R $region_file $vcf_WGS | bgzip > ${vcf_WGS.baseName}_exons_plus1k.vcf.gz
    gunzip  ${vcf_WGS.baseName}_exons_plus1k.vcf.gz
    (grep ^# ${vcf_WGS.baseName}_exons_plus1k.vcf ; grep -v ^# ${vcf_WGS.baseName}_exons_plus1k.vcf | sort -k1,1 -k2,2n) | bgzip > ${vcf_WGS.baseName}_exons_plus1k_sorted.vcf.bgz
    tabix -C -f ${vcf_WGS.baseName}_exons_plus1k_sorted.vcf.bgz
    rm $vcf_WGS $vcf_WGS_idx ${vcf_WGS.baseName}_exons_plus1k.vcf
    """
    else
    """
    tabix -R $region_file $vcf_WGS | bgzip > ${vcf_WGS.baseName}_exons_plus1k.vcf.bgz
    rm $vcf_WGS $vcf_WGS_idx
    """
  }
