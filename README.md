# Watershed pipeline for SNVs (WDL implementation)
## Description of inputs:
* __`File cadd_anno_header`__: File containing VCF header lines describing the annotations.
  * See the [VCF 4.2 specification](https://samtools.github.io/hts-specs/VCFv4.2.pdf) for full details.
  * For example, one line could be: `##INFO=<ID=SIFTval,Number=1,Type=String,Description="SIFT score">`
  * It is best to set `Type=String` to be robust to missing values which are coded in unpredictable formats.
* __`File cadd_cache`__: CADD annotations in tabular format.
  * For example, [this file of CADD v1.6 annotations](https://krishna.gs.washington.edu/download/CADD/v1.6/GRCh38/whole_genome_SNVs_inclAnno.tsv.gz) which can be downloaded from [https://cadd.gs.washington.edu](https://cadd.gs.washington.edu/download).
* __`File cadd_cache_idx`__: Tabix index (`.tbi`) file for `cadd_cache`.
* __`File cadd_cols2keep`__: File indicating which columns of the . See [`bcftools annotate -C` documentation](https://samtools.github.io/bcftools/bcftools.html#annotate) for full details, but briefly:
  * Columns must be listed in order they appear in `cadd_cache`.
  * Columns representing chromosome, position, reference and alternate alleles must be labelled `CHROM`,`POS`,`REF`,`ALT`.
  * Columns to drop are listed as `-`. Columns to keep are given a name.
* __`File chr_rename_file`__: A file with two columns of chromosome codes: one of the chromosome names in your `vcfs`, and the other with chromosomes named as `1`,`2`,...`22`,`X`.
  * This is used to make `vcfs` which have the chromosome naming scheme `chr1`,chr2`... etc. compatible with the `cadd_cache`.
* __`File chr_unrename_file`__: Similar to `chr_rename_file`, but maps the chromosome codes back to how they were before.
* __`File gerp_bw`__: BigWig (`.bw`) file of GERP scores downloadable [here](https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/gerp_conservation_scores.homo_sapiens.GRCh38.bw) (used by VEP's [loftee plugin](https://github.com/konradjk/loftee/tree/grch38)).
* __`File human_ancestor_seq`__: Human ancestor sequence file downloadable [here](https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/human_ancestor.fa.gz) (used by VEP's [loftee plugin](https://github.com/konradjk/loftee/tree/grch38)).
* __`File phylocsf_db`__: SQL database of PhyloCSF metrics downloadable [here](https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/loftee.sql.gz) (used by VEP's [loftee plugin](https://github.com/konradjk/loftee/tree/grch38)).
* __`File phylop100_bw`__: BigWig (`.bw`) file of phyloP100way scores, downloadable from UCSC [here]().
  * These scores represent the degree to which variants are conserved in a collection of 100 non-human vertebrate species. For more information, see [this page](https://genome.ucsc.edu/cgi-bin/hgc?db=hg38&c=chr9&l=113221543&r=113264492&o=113221543&t=113264492&g=phyloP100way&i=phyloP100way) of the UCSC Genome Browser site.
* __`Array[File] vcfs`__: VCF (or BCF) file(s) to be annotated.
  * The files must contain INFO/AC and INFO/AN fields at minimum.
* __`File vep_cache`__: v115 of the cache file for Ensembl's Variant Effect Predictor (VEP), (downloadable [here](https://ftp.ensembl.org/pub/release-115/variation/indexed_vep_cache/homo_sapiens_vep_115_GRCh38.tar.gz)).
* (Optional) __`File filter_regions`__: File of regions to filter the `vcfs` by, one region per line.
  * See [`bcftools` documentation](https://samtools.github.io/bcftools/bcftools.html) about the `-R` option for full details.
* (Optional) __`File filter_samples`__: File of sample ids to filter the `vcfs` by, one id per line.
  * See [`bcftools` documentation](https://samtools.github.io/bcftools/bcftools.html) about the `-S` option for full details.
* (Optional) __`Int n_cpu`__: Number of cores to allocate. More cores will make the workflow finish more quickly, but also cost slightly more.
  * For example, a run that took 3hr:45min and $1.75 on 8 cores, took 1hr:30min and $2.73 on 32 cores.
