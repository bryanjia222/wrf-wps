# WRF + WPS Docker Container
FROM ubuntu:24.04

# Build arguments
ARG COMPILE_THREADS=4
ARG http_proxy
ARG https_proxy

# Set environment variables
ENV WRF_VERSION=4.7.1 \
    WPS_VERSION=4.6.0 \
    DEBIAN_FRONTEND=noninteractive \
    DIR=/wrf/wrf_dependencies

# Set working directory
WORKDIR /wrf

# Update sources and install all dependencies in one layer
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    sed -i "s@http://.*.ubuntu.com@http://mirrors.huaweicloud.com@g" /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y \
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
        openmpi-bin \
        libopenmpi-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /wrf/wrf_dependencies /wrf/WPS_GEOG /wrf/wrfdata/input /wrf/wrfdata/output /wrf/scripts

# Set environment variables for dependency compilation
ENV NETCDF=$DIR/netcdf \
    LD_LIBRARY_PATH=$DIR/netcdf/lib:$DIR/grib2/lib \
    PATH=$DIR/netcdf/bin:$DIR/mpich/bin:${PATH} \
    JASPERLIB=$DIR/grib2/lib \
    JASPERINC=$DIR/grib2/include

# Set compilation environment variables
ENV CC=gcc \
    CXX=g++ \
    FC=gfortran \
    FCFLAGS="-m64 -fallow-argument-mismatch" \
    F77=gfortran \
    FFLAGS="-m64 -fallow-argument-mismatch" \
    LDFLAGS="-L$DIR/netcdf/lib -L$DIR/grib2/lib" \
    CPPFLAGS="-I$DIR/netcdf/include -I$DIR/grib2/include -fcommon"

WORKDIR $DIR

# Download all source files first (better cache utilization)
RUN wget -q https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz \
             https://github.com/HDFGroup/hdf5/archive/hdf5-1_10_5.tar.gz \
             https://github.com/Unidata/netcdf-c/archive/v4.9.3.tar.gz \
             https://github.com/Unidata/netcdf-fortran/archive/v4.6.2.tar.gz \
             https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz \
             https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz \
             https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz

# Install all dependencies in one RUN command
RUN set -ex && \
    # Install zlib
    tar xzf zlib-1.2.11.tar.gz && \
    cd zlib-1.2.11 && \
    ./configure --prefix=$DIR/grib2 && \
    make -j ${COMPILE_THREADS} && make install && \
    cd .. && rm -rf zlib* && \
    # Install HDF5
    tar xzf hdf5-1_10_5.tar.gz && \
    cd hdf5-hdf5-1_10_5 && \
    ./configure --prefix=$DIR/netcdf --with-zlib=$DIR/grib2 --enable-fortran --enable-shared && \
    make -j ${COMPILE_THREADS} && make install && \
    cd .. && rm -rf hdf5* && \
    # Install NetCDF-c
    tar xzf v4.9.3.tar.gz && \
    cd netcdf-c-4.9.3 && \
    ./configure --prefix=$DIR/netcdf --disable-dap --enable-netcdf4 --enable-hdf5 --enable-shared && \
    make -j ${COMPILE_THREADS} && make install && \
    cd .. && rm -rf v4.9.3.tar.gz netcdf-c* && \
    # Install netcdf-fortran
    export LIBS="-lnetcdf -lz" && \
    tar xzf v4.6.2.tar.gz && \
    cd netcdf-fortran-4.6.2 && \
    ./configure --prefix=$DIR/netcdf --disable-hdf5 --enable-shared && \
    make -j ${COMPILE_THREADS} && make install && \
    cd .. && rm -rf netcdf-fortran* v4.6.2.tar.gz && \
    # Install mpich
    tar xzf mpich-3.0.4.tar.gz && \
    cd mpich-3.0.4 && \
    ./configure --prefix=$DIR/mpich && \
    make -j ${COMPILE_THREADS} 2>&1 && make install && \
    cd .. && rm -rf mpich* && \
    # Install libpng
    tar xzf libpng-1.2.50.tar.gz && \
    cd libpng-1.2.50 && \
    ./configure --prefix=$DIR/grib2 && \
    make -j ${COMPILE_THREADS} && make install && \
    cd .. && rm -rf libpng* && \
    # Install jasper
    tar xzf jasper-1.900.1.tar.gz && \
    cd jasper-1.900.1 && \
    ./configure --prefix=$DIR/grib2 && \
    make -j ${COMPILE_THREADS} && make install && \
    cd .. && rm -rf jasper*

# Unset build-specific environment variables
ENV CC= CXX= FC= FCFLAGS= F77= FFLAGS= LDFLAGS= CPPFLAGS=

# Set runtime environment variables
ENV WRF_DIR=/wrf/WRF
ENV WPS_DIR=/wrf/WPS

WORKDIR /wrf

# Download, configure and compile WRF & WPS in one layer
RUN set -ex && \
    # Download and compile WRF
    wget -q https://github.com/wrf-model/WRF/releases/download/v${WRF_VERSION}/v${WRF_VERSION}.tar.gz && \
    tar -xzf v${WRF_VERSION}.tar.gz && \
    mv WRFV${WRF_VERSION} WRF && \
    rm v${WRF_VERSION}.tar.gz && \
    cd WRF && \
    echo "34" | ./configure && \
    ./compile -j ${COMPILE_THREADS} em_real 2>&1 | tee compile_wrf.log && \
    cd .. && \
    # Download and compile WPS
    wget -q https://github.com/wrf-model/WPS/archive/v${WPS_VERSION}.tar.gz && \
    tar -xzf v${WPS_VERSION}.tar.gz && \
    mv WPS-${WPS_VERSION} WPS && \
    rm v${WPS_VERSION}.tar.gz && \
    cd WPS && \
    echo "3" | ./configure && \
    ./compile 2>&1 | tee compile_wps.log

# Copy scripts (if they exist)
COPY scripts/wrf_info.sh scripts/run.sh /wrf/scripts/
RUN chmod +x /wrf/scripts/*.sh && \
    echo "export PATH=\$PATH:/wrf/scripts" >> /etc/bash.bashrc

# Set working directory
WORKDIR /wrf

# Default command
CMD ["/bin/bash", "-c", "echo 'WRF and WPS compilation completed'; ls -la /wrf/WRF/main/; ls -la /wrf/WPS/; /bin/bash"]