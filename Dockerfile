FROM ensemblorg/ensembl-vep

USER root
RUN apt update \
 && apt install -y parallel
USER vep
WORKDIR /opt/vep

RUN curl -LOC- https://github.com/konradjk/loftee/archive/refs/tags/v1.0.4_GRCh38.tar.gz \
 && tar zxf v1.0.4_GRCh38.tar.gz \
 && mv loftee-1.0.4_GRCh38/* /plugins

RUN curl -LOC- https://github.com/samtools/samtools/releases/download/1.23/samtools-1.23.tar.bz2 \
 && bunzip2 samtools-1.23.tar.bz2 \
 && tar xf  samtools-1.23.tar     \
 && cd      samtools-1.23         \
 && ./configure --without-curses  \
 && make -j \
 && mv samtools /opt/vep/src/ensembl-vep/

RUN curl -LOC- https://github.com/samtools/bcftools/releases/download/1.23/bcftools-1.23.tar.bz2 \
 && bunzip2 bcftools-1.23.tar.bz2 \
 && tar xf  bcftools-1.23.tar     \
 && cd      bcftools-1.23         \
 && ./configure \
 && make -j \
 && mv bcftools /opt/vep/src/ensembl-vep/ \
 && mv plugins/ /plugins/bcftools

RUN rm *.tar *.tar.gz

ENV BCFTOOLS_PLUGINS /plugins/bcftools

USER root
WORKDIR /data
