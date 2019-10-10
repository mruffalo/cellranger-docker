FROM ubuntu:18.04

## System packages
RUN apt update
RUN apt -y install \
    build-essential \
    clang-6.0 \
    curl \
    libatlas-base-dev \
    libbz2-dev \
    liblz4-tool \
    liblzma-dev \
    libncurses5-dev \
    libopenblas-dev \
    git \
    npm \
    pkg-config \
    python2.7 \
    python2.7-dev \
    python-numpy \
    python-pip \
    python-tables \
    wget \
    zlib1g-dev
RUN apt clean

## Martian 3.2.1 needs Go 1.11 or newer, but 1.10 is the newest in the Ubuntu 18.04 apt repos
ENV go_version 1.11

WORKDIR /opt
RUN curl -O https://dl.google.com/go/go${go_version}.linux-amd64.tar.gz \
 && tar -xf go${go_version}.linux-amd64.tar.gz \
 && rm go${go_version}.linux-amd64.tar.gz

## RUST start
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

## Set PATH for Rust and Go
ENV PATH $PATH:/opt/go/bin:/root/.cargo/bin

## RUST finish
RUN rustup install 1.34.1 && rustup default 1.34.1

## Python packages
COPY requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt
RUN rm -rf /root/.cache/pip

## CellRanger 3.0.2
WORKDIR /opt
RUN git clone https://github.com/10XGenomics/cellranger.git
WORKDIR /opt/cellranger
RUN git checkout 3.0.2
RUN make

## Martian
WORKDIR /opt
RUN git clone https://github.com/martian-lang/martian.git --recursive
WORKDIR /opt/martian
RUN git checkout v3.2.1
RUN git submodule update --recursive
RUN make all

WORKDIR /opt

## Set paths
ENV PATH $PATH:/opt/cellranger/bin:/opt/cellranger/lib/bin:/opt/cellranger/tenkit/bin:/opt/martian/bin
ENV PYTHONPATH $PYTHONPATH:/opt/cellranger/lib/python:/opt/cellranger/tenkit/lib/python:/root/martian/adapters/python
ENV MROPATH $MROPATH:/opt/cellranger/mro:/opt/cellranger/tenkit/mro
ENV RUST_SRC_PATH $RUST_SRC_PATH:/opt/cellranger/lib/rust
ENV _TENX_LD_LIBRARY_PATH tenx_path

# Install samtools
ENV samtools_version 1.9

RUN wget https://github.com/samtools/samtools/releases/download/${samtools_version}/samtools-${samtools_version}.tar.bz2 \
 && tar xjvf samtools-${samtools_version}.tar.bz2 \
 && rm samtools-${samtools_version}.tar.bz2 \
 && cd samtools-${samtools_version} \
 && ./configure --prefix=/usr \
 && make \
 && make install \
 && cd .. \
 && rm -rf samtools-${samtools_version}

# Install STAR aligner
ENV star_version 2.7.0f

RUN wget https://github.com/alexdobin/STAR/archive/${star_version}.tar.gz \
 && tar -xf ${star_version}.tar.gz \
 && rm ${star_version}.tar.gz \
 && cd STAR-${star_version}/source \
 && make \
 && mv STAR /usr/bin \
 && cd ../.. \
 && rm -rf STAR-${star_version}

# Install tsne python package. pip installing it doesn't work
RUN git clone https://github.com/danielfrg/tsne.git \
 && cd tsne \
 && make install \
 && cd .. \
 && rm -rf tsne

## Default command
CMD ["cellranger", "-h"]
