FROM jenkins/inbound-agent:3309.v27b_9314fd1a_4-4-jdk17
# install base lib
apt update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libabsl-dev \
    libboost-all-dev \
    libbz2-dev \
    libdouble-conversion-dev \
    libevent-dev \
    libfmt-dev \
    libgflags-dev \
    libgoogle-glog-dev \
    libgtest-dev \
    libjemalloc-dev \
    libjsoncpp-dev \
    liblz4-dev \
    libre2-dev \
    libsnappy-dev \
    libssl-dev \
    libthrift-dev \
    libunwind-dev \
    libxxhash-dev \
    libzstd-dev \
    zlib1g-dev \
    llvm-19 \
    llvm-19-dev \
    clang-19 \
    ninja-build \
    openjdk-17-jdk \
    rapidjson-dev \
    git
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# folly
# 1. install fast_float
git clone https://github.com/fastfloat/fast_float.git && cd fast_float && git checkout v8.0.2
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF && cmake --install build # lands in /usr/local/include/fast_float
# 2. install folly, build libfolly.so
git clone https://github.com/facebook/folly.git
cd folly
git checkout v2025.05.26.00

mkdir _build && cd _build
cmake .. -DCMAKE_BUILD_TYPE=Release -DFOLLY_USE_JEMALLOC=ON -DBUILD_SHARED_LIBS=ON
make -j$(nproc)

# 3. install folly
make install                # installs into /usr/local by default
ldconfig

# clickhouse-cpp
git clone https://github.com/ClickHouse/clickhouse-cpp.git && cd clickhouse-cpp
git checkout v2.5.1
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON .
cmake --build build -j$(nproc)
cmake --install build

# cityhash
git clone https://github.com/google/cityhash.git && cd cityhash
./configure && make -j$(nproc) && make install

# duckdb
git clone https://github.com/duckdb/duckdb.git && cd duckdb && git checkout v1.3.0
mkdir build && cd build && cmake .. -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release && make -j $(nproc) && make install