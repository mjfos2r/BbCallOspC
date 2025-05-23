version 1.0
import "Structs.wdl"

workflow BbCallOspC {

    meta { description: "Simple workflow to classify ospC allele type in Borrelia burgdorferi draft assemblies." }
    parameter_meta {
        sample_id: "sample_id for the assembly we're classifying"
        input_fa: "draft assembly.fasta to be classified"
    }
    input {
        String sample_id
        File input_fa
    }
    call CallOspC {
        input:
            sample_id = sample_id,
            input_fa = input_fa
    }
    output {
        File ospC_all_hits_tsv = CallOspC.ospC_all_hits_tsv
        File ospC_best_hits_tsv = CallOspC.ospC_best_hits_tsv
        File ospC_contam_hits_tsv = CallOspC.ospC_contam_hits_tsv
        File ospC_raw_hits_xml = CallOspC.ospC_raw_hits_xml
        String ospC_type = CallOspC.ospC_type
    }
}

task CallOspC {
    input {
        String sample_id
        File input_fa
        RuntimeAttr? runtime_attr_override
    }
    parameter_meta {
        sample_id: "sample_id for the assembly we're classifying"
        input_fa: "draft assembly.fasta to be classified"
    }
    Int disk_size = 50 + 10 * ceil(size(input_fa, "GB"))
    command <<<
        ospc_caller \
            -i "~{input_fa}" \
            -o "results" \
            -t 8
        mv results/*.fasta results/"~{sample_id}_renamed.fasta"
        tar -C results -czvf results/ospC_hits_xml.tar.gz ospC_v5/
    >>>

    output {
        File ospC_all_hits_tsv = "results/ospC_all.tsv"
        File ospC_best_hits_tsv = "results/ospC_best.tsv"
        File ospC_contam_hits_tsv = "results/ospC_contam.tsv"
        File ospC_raw_hits_xml = "results/ospC_hits_xml.tar.gz"
        String ospC_type = read_string("results/ospC_type.txt")
    }
    #########################
    RuntimeAttr default_attr = object {
        cpu_cores:          8,
        mem_gb:             32,
        disk_gb:            disk_size,
        boot_disk_gb:       25,
        preemptible_tries:  0,
        max_retries:        0,
        docker:             "mjfos2r/ospc_caller:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}
