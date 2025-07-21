# WRF + WPS Docker Container
# Based on Ubuntu 22.04 LTS
FROM ubuntu:22.04

# Build arguments
ARG COMPILE_THREADS=4
ARG http_proxy
ARG https_proxy

# Set environment variables
ENV WRF_VERSION=4.7.1
ENV WPS_VERSION=4.6.0
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /wrf

# Update and install basic dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates

# 替换 APT 源为华为源
RUN sed -i 's|http://.*.ubuntu.com|https://repo.huaweicloud.com|g' /etc/apt/sources.list && \
    apt-get update

# Install only essential system packages
RUN apt-get update && apt-get install -y \
    build-essential \
    gfortran \
    gcc \
    g++ \
    make \
    m4 \
    cmake \
    csh \
    wget \
    tar \
    curl \
    vim \
    git \
    file \
    libxml2-dev \
    curl
    # && rm -rf /var/lib/apt/lists/*

# Create wrf_dependencies directory
RUN mkdir -p /wrf/wrf_dependencies

# Set environment variables for dependency compilation
ENV DIR=/wrf/wrf_dependencies
ENV NETCDF=$DIR/netcdf
ENV LD_LIBRARY_PATH=$NETCDF/lib:$DIR/grib2/lib
ENV PATH=$NETCDF/bin:$DIR/mpich/bin:${PATH}
ENV JASPERLIB=$DIR/grib2/lib
ENV JASPERINC=$DIR/grib2/include

# Set compilation environment variables for dependencies only
ENV CC=gcc
ENV CXX=g++
ENV FC=gfortran
ENV FCFLAGS="-m64 -fallow-argument-mismatch"
ENV F77=gfortran
ENV FFLAGS="-m64 -fallow-argument-mismatch"
ENV LDFLAGS="-L$NETCDF/lib -L$DIR/grib2/lib"
ENV CPPFLAGS="-I$NETCDF/include -I$DIR/grib2/include -fcommon"

WORKDIR $DIR

# Install zlib
RUN wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz && \
    tar xzf zlib-1.2.11.tar.gz && \
    cd zlib-1.2.11 && \
    ./configure --prefix=$DIR/grib2 && \
    make -j ${COMPILE_THREADS} && \
    make install && \
    cd .. && \
    rm -rf zlib*

# Install HDF5
RUN wget https://github.com/HDFGroup/hdf5/archive/hdf5-1_10_5.tar.gz && \
    tar xzf hdf5-1_10_5.tar.gz && \
    cd hdf5-hdf5-1_10_5 && \
    ./configure --prefix=$DIR/netcdf --with-zlib=$DIR/grib2 --enable-fortran --enable-shared && \
    make -j ${COMPILE_THREADS} && \
    make install && \
    cd .. && \
    rm -rf hdf5*

# Install NetCDF-c
RUN wget https://github.com/Unidata/netcdf-c/archive/v4.9.3.tar.gz && \
    tar xzf v4.9.3.tar.gz && \
    cd netcdf-c-4.9.3 && \
    ./configure --prefix=$DIR/netcdf --disable-dap --enable-netcdf4 --enable-hdf5 --enable-shared && \
    make -j ${COMPILE_THREADS} && \
    make install && \
    cd .. && \
    rm -rf v4.9.3.tar.gz netcdf-c*

# Install netcdf-fortran
RUN export LIBS="-lnetcdf -lz" && \
    wget https://github.com/Unidata/netcdf-fortran/archive/v4.6.2.tar.gz && \
    tar xzf v4.6.2.tar.gz && \
    cd netcdf-fortran-4.6.2 && \
    ./configure --prefix=$DIR/netcdf --disable-hdf5 --enable-shared && \
    make -j ${COMPILE_THREADS} && \
    make install && \
    cd .. && \
    rm -rf netcdf-fortran* v4.6.2.tar.gz

# Install mpich
RUN wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz && \
    tar xzf mpich-3.0.4.tar.gz && \
    cd mpich-3.0.4 && \
    ./configure --prefix=$DIR/mpich && \
    make -j ${COMPILE_THREADS} 2>&1 && \
    make install && \
    cd .. && \
    rm -rf mpich*

# Install libpng
RUN wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz && \
    tar xzf libpng-1.2.50.tar.gz && \
    cd libpng-1.2.50 && \
    ./configure --prefix=$DIR/grib2 && \
    make -j ${COMPILE_THREADS} && \
    make install && \
    cd .. && \
    rm -rf libpng*

# Install jasper
RUN wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz && \
    tar xzf jasper-1.900.1.tar.gz && \
    cd jasper-1.900.1 && \
    ./configure --prefix=$DIR/grib2 && \
    make -j ${COMPILE_THREADS} && \
    make install && \
    cd .. && \
    rm -rf jasper*

# Unset build-specific environment variables
ENV CC=
ENV CXX=
ENV FC=
ENV FCFLAGS=
ENV F77=
ENV FFLAGS=
ENV LDFLAGS=
ENV CPPFLAGS=

# Set runtime environment variables
ENV NETCDF=$DIR/netcdf
ENV LD_LIBRARY_PATH=$NETCDF/lib:$DIR/grib2/lib
ENV PATH=$NETCDF/bin:$DIR/mpich/bin:${PATH}
ENV JASPERLIB=$DIR/grib2/lib
ENV JASPERINC=$DIR/grib2/include

# Change to working directory for WRF/WPS
WORKDIR /wrf

# Create directory structure
RUN mkdir -p /wrf/WPS_GEOG /wrf/wrfdata /wrf/scripts

# Download wrf
RUN cd /wrf && \
    wget https://github.com/wrf-model/WRF/releases/download/v${WRF_VERSION}/v${WRF_VERSION}.tar.gz && \
    tar -xzf v${WRF_VERSION}.tar.gz && \
    mv WRFV${WRF_VERSION} WRF && \
    rm v${WRF_VERSION}.tar.gz

RUN apt-get install -y openmpi-bin libopenmpi-dev

# Configure and compile WRF
RUN cd /wrf/WRF && \
    echo "34" | ./configure && \
    ./compile -j ${COMPILE_THREADS} em_real 2>&1 | tee compile_wrf.log

ENV WRF_DIR=/wrf/WRF

# Download and compile WPS
RUN cd /wrf && \
    wget https://github.com/wrf-model/WPS/archive/v${WPS_VERSION}.tar.gz && \
    tar -xzf v${WPS_VERSION}.tar.gz && \
    mv WPS-${WPS_VERSION} WPS && \
    rm v${WPS_VERSION}.tar.gz

# Configure and compile WPS
RUN cd /wrf/WPS && \
    echo "3" | ./configure && \
    ./compile 2>&1 | tee compile_wps.log

# Copy scripts (if they exist)
COPY scripts/wrf_info.sh /wrf/scripts/ 
COPY scripts/run.sh /wrf/scripts/ 
RUN chmod +x /wrf/scripts/*.sh 

# Add scripts to PATH
RUN echo "export PATH=\$PATH:/wrf/scripts" >> /etc/bash.bashrc

# Create data directories
RUN mkdir -p /wrf/wrfdata/input /wrf/wrfdata/output

# Set working directory
WORKDIR /wrf

# Default command - check installation and start bash
CMD ["/bin/bash", "-c", "echo 'WRF and WPS compilation completed'; ls -la /wrf/WRF/main/; ls -la /wrf/WPS/; /bin/bash"]