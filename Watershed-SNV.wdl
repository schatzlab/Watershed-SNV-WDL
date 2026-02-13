version 1.0
workflow Watershed_SNV {
  call annotate
  output {
          File annotated_bcf = annotate.annotated_bcf
          File        joblog = annotate.joblog
    Array[File]    chunkdefs = annotate.chunkdefs
  }

  parameter_meta {
    vep_cache: "Indexed VEP cache downloaded from https://ftp.ensembl.org/pub/release-115/variation/indexed_vep_cache/"
    cadd_cache: "CADD file (including all annotations) downloaded from https://cadd.gs.washington.edu/download"
    n_cpu: "Number of requested cores."
    memory_gb: "GB of memory to allocate. Recommended: at least 4GB per core."
    disk_gb: "Requested disk space (in GB)."
  }
}

task annotate {
  input {
    Array[File] vcfs
    File? filter_regions
    File? filter_samples

    # VEP and loftee-related files
    File vep_cache
    File phylop100_bw
    File gerp_bw
    File phylocsf_db
    File human_ancestor_seq

    # CADD annotation-related files
    File cadd_cache
    File cadd_cache_idx
    File cadd_cols2keep
    File cadd_anno_header
    File chr_rename_file
    File chr_unrename_file

    Int n_cpu = 16
  }

  Int memory_gb = floor(n_cpu*6.5)
  Int   disk_gb = floor(size(vcfs,'G')*8 + size([vep_cache,phylop100_bw,gerp_bw,cadd_cache],'G') + 50)

  command <<<
    export ncpu=~{n_cpu}

    # Given a VCF/BCF file, splits it into chunks and prints the chunks' filenames in order.
    chunkify() {
      export local vcf="$1"
      #bcftools index -s "$vcf" | while read chr unused n_records; do
      bcftools index -s "$vcf" | parallel -j $ncpu -k -a- --colsep '\t' '
        chr={1} n_records={3}
        poss_fnm=$(mktemp ./poss.XXXXX) # will have $n_records lines
        bcftools query -r $chr -f "%CHROM\t%POS\n" "$vcf" > $poss_fnm

        beg=1 end=$(($beg+$chunksz-1))
        while [ $beg -le $n_records ]; do
          if [ $end -gt $n_records ]; then end=$n_records; fi
          pos_beg=$(sed -n "${beg}p" $poss_fnm | cut -f2)
          pos_end=$(sed -n "${end}p" $poss_fnm | cut -f2)
          beg=$(($end+1))
          end=$(($beg+$chunksz-1))

          bcf_subset=$(mktemp chunk.bcf.gz.XXXXXXXX)
          echo -e "$chr:$pos_beg-$pos_end\t$vcf\t$bcf_subset"
        done
        rm $poss_fnm
       ' | parallel --joblog $(basename "$vcf".chunk_definitions.log) -j $ncpu -k -a- --colsep '\t' '
        bcftools view -r {1} "{2}" -Ob > {3}
        echo {3}
       '
    }; export -f chunkify

    # Main
    echo "Indexing human ancestor sequence..."
    samtools faidx ~{human_ancestor_seq}

    echo "Unzipping VEP cache..."
    mkdir /root/.vep
    tar -xzf "~{vep_cache}" -C /root/.vep

    echo "Indexing VCF/BCF files..."
    time parallel bcftools index {} ::: ~{sep=' ' vcfs}

    total_n_records=$(parallel bcftools index -s {} ::: ~{sep=' ' vcfs} |         cut -f3       | awk '{s+=$1} END {print s}')
    total_n_contigs=$(parallel bcftools index -s {} ::: ~{sep=' ' vcfs} | wc -l | cut -f1 -d' ' | awk '{s+=$1} END {print s}')
    export chunksz=$(($total_n_records/$total_n_contigs/$ncpu/20)) # More chunks is generally good: work spread more evenly across cores, and VEP leaks memory so running on one file too long would cause high RAM usage.
    echo 'Chunk size: '$chunksz
    echo 'Chunking files...' '(#variants:'$total_n_records', #cores:'$ncpu')'
    time parallel -j $ncpu -k 'chunkify {}' ::: ~{sep=' ' vcfs} > chunk_list.txt 
    echo 'Number of chunks: ' $(wc -l chunk_list.txt)
    
    echo "Filtering, and annotating with CADD & VEP..."
    time parallel --progress --joblog joblog.txt -j $ncpu -k -a chunk_list.txt '
      bcftools index {}
        bcftools view {}    -Ou -v snps ~{"-R " + filter_regions} ~{"--force-samples -S " + filter_samples} \
      | bcftools +fill-tags -Ou -i"AC>0 && AC<AN" -- -t MAF \
      | bcftools view       -Ou -i"MAF<0.01" \
      | bcftools annotate   -Ou --rename-chr "~{chr_rename_file}" \
      | bcftools annotate   -Ov --rename-chr "~{chr_unrename_file}" \
          -a "~{cadd_cache}" -C "~{cadd_cols2keep}" -h "~{cadd_anno_header}" \
      | vep -i STDIN --format vcf \
          --buffer_size 20000 --offline --no_stats \
          --custom file=~{phylop100_bw},short_name=phyloP100way,format=bigwig \
          --plugin LoF,loftee_path:/plugins,human_ancestor_fa:~{human_ancestor_seq},conservation_file=~{phylocsf_db},gerp_bigwig:~{gerp_bw} \
          --fields "Allele,Consequence,SYMBOL,Gene,LoF,phyloP100way" \
          -o annotated_{} --vcf --compress_output bgzip
      echo annotated_{}
    ' > annotated_chunk_list.txt

    ls -lh

    echo "Concatenating files..."
    bcftools concat -f annotated_chunk_list.txt -Ob -o annotated.bcf.gz

    echo "Indexing final concatenated BCF..."
    bcftools index annotated.bcf.gz

    echo "Done."
  >>>

  runtime {
    docker: "manninglab/loftee:0becd11"
    disks: "local-disk ~{disk_gb} SSD"
    memory: "~{memory_gb} GB"
    cpu: "~{n_cpu}"
  }

  output {
          File  annotated_bcf = "annotated.bcf.gz"
          File         joblog = "joblog.txt"
    Array[File]     chunkdefs = glob("*.chunk_definitions.log")
  }
}
