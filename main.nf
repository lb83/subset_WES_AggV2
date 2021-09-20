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
Channel
    .fromPath(params.input)
    .ifEmpty { exit 1, "Cannot find input file : ${params.input}" }
    .splitCsv(skip:1)
    .map {vcf_WGS, vcf_WGS_idx -> [ vcf_WGS, vcf_WGS_idx ] }
    .set { ch_input }

// Define Channels from input
Channel
    .fromPath(params.input)
    .ifEmpty { exit 1, "Cannot find input file : ${params.input}" }
    .set { ch_region_file }

// Define Process
process subset_vcfs {
    tag "$sample_name"
    label 'low_memory'
    publishDir "${params.outdir}", mode: 'copy' // in results by default

    input:
    set file(vcf_WGS), file(vcf_WGS_idx) from ch_input
    each file(region_file) from ch_region_file // file is going to be lost after firts iteration.
    
    output:
    file "*_exons_plus1K" into ch_out

    script:
    """
    tabix -R $region_file $vcf_WGS | bgzip > ${vcf_WGS.baseName}_exons_plus1k.vcf.gz
    """
  }
