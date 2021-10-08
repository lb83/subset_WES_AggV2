# Nextflow Template

## How to run:

```bash
git clone https://github.com/lifebit-ai/subset_WES_AggV2
cd subset_WES_AggV2
nextflow run main.nf  \
--input_folder_location 's3://eu-west-1-example-data/subset-vcf/' \
--number_of_files_to_process -1 \
--region_file_location 's3://eu-west-1-example-data/subset-vcf/1snp_chr1_16377_16378.vcf.bed' \
--file_suffix 'vcf.bgz' \
--index_suffix 'vcf.bgz.csi' \
--file_pattern "3snps"
```

