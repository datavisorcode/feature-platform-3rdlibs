cmake_minimum_required(VERSION 3.10)

project(DataTransferNative)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_VERBOSE_MAKEFILE ON)


include(ExternalProject)

# Set up a cache directory with subfolders for Arrow and DuckDB
set(EXTERNAL_INSTALL_LOCATION ${CMAKE_BINARY_DIR}/external)
set(ARROW_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/arrow)
set(DUCKDB_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/duckdb)
set(ADBC_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/adbc)
set(FAST_FLOAT_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/fast_float)
set(FOLLY_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/folly)
set(CLICKHOUSE_CPP_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/clickhouse-cpp)
set(CITYHASH_INSTALL_DIR ${EXTERNAL_INSTALL_LOCATION}/cityhash)

# CPU core count
cmake_host_system_information(RESULT NUMBER_OF_PROCESSORS QUERY NUMBER_OF_LOGICAL_CORES)
message(STATUS "Number of processors: ${NUMBER_OF_PROCESSORS}")

# Download and build fast_float (dependency for folly)
ExternalProject_Add(fast_float_project
    PREFIX ${CMAKE_BINARY_DIR}/fast_float
    GIT_REPOSITORY https://github.com/fastfloat/fast_float.git
    GIT_TAG v8.0.2
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    CMAKE_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_TESTING=OFF
        -DCMAKE_INSTALL_PREFIX=${FAST_FLOAT_INSTALL_DIR}
    INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR>
    BUILD_ALWAYS OFF
)

# Download and build Arrow
ExternalProject_Add(arrow_project
    PREFIX ${CMAKE_BINARY_DIR}/arrow
    GIT_REPOSITORY https://github.com/apache/arrow.git
    GIT_TAG apache-arrow-19.0.0
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    SOURCE_SUBDIR cpp
    CMAKE_ARGS
            -DCMAKE_INSTALL_PREFIX=${ARROW_INSTALL_DIR}
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_CXX_FLAGS_RELEASE=${CMAKE_CXX_FLAGS_RELEASE}
            -DCMAKE_C_FLAGS_RELEASE=${CMAKE_CXX_FLAGS_RELEASE}
            -DARROW_BUILD_SHARED=ON
            -DARROW_PARQUET=ON
            -DARROW_DATASET=ON
            -DARROW_CSV=ON
            -DARROW_WITH_THRIFT=ON
            -DARROW_WITH_RE2=ON
            -DARROW_JSON=ON
            -DARROW_WITH_BROTLI=OFF
            -DARROW_WITH_ZSTD=ON
            -DARROW_WITH_LZ4=ON
            -DARROW_WITH_SNAPPY=ON
            -DARROW_WITH_ZLIB=ON
            -DARROW_CGLIB=OFF
            -DARROW_BUILD_STATIC=OFF
            -DARROW_BUILD_TESTS=OFF
            -DARROW_BUILD_EXAMPLES=OFF
            -DARROW_FLIGHT=OFF
            -DARROW_FILESYSTEM=ON
            -DARROW_S3=ON
            -DARROW_PYTHON=OFF
            -DARROW_CUDA=OFF
            -DARROW_JEMALLOC=ON
            -DARROW_GANDIVA=ON
            -DLLVM_ROOT=${LLVM_ROOT}
            -DCMAKE_INSTALL_PREFIX=${ARROW_INSTALL_DIR}
            # --- Add RPATH settings for Arrow build ---
            -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE
            -DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE
            -DCMAKE_INSTALL_RPATH=\$ORIGIN;\$ORIGIN/../lib;@executable_path/../lib;${HOMEBREW_PREFIX}/lib;${ARROW_INSTALL_DIR}/lib # Reverted to single-escaped $ORIGIN
            # --- End RPATH settings ---
            # --- Use bundled dependencies to avoid conflicts ---
            -DARROW_DEPENDENCY_SOURCE=AUTO
            # --- End bundled dependencies ---
        BUILD_ALWAYS OFF
        INSTALL_DIR ${ARROW_INSTALL_DIR}
)

# Download and build DuckDB
ExternalProject_Add(duckdb_project
    PREFIX ${CMAKE_BINARY_DIR}/duckdb
    GIT_REPOSITORY https://github.com/duckdb/duckdb.git
    GIT_TAG v1.3.0
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    CMAKE_ARGS
        -DBUILD_SHARED_LIBS=ON
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX=${DUCKDB_INSTALL_DIR}
        -DBUILD_JSON_EXTENSION=ON
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release -j ${NUMBER_OF_PROCESSORS}
    INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR> --config Release
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        <SOURCE_DIR>/src/include
        ${DUCKDB_INSTALL_DIR}/include
    BUILD_ALWAYS OFF
)

# Add ADBC project (without install step)
ExternalProject_Add(adbc_project
    PREFIX ${CMAKE_BINARY_DIR}/adbc
    GIT_REPOSITORY https://github.com/apache/arrow-adbc.git
    GIT_TAG maint-0.7.0
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    SOURCE_SUBDIR c
    CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/adbc/src/adbc_project-build
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --target all -- -j ${NUMBER_OF_PROCESSORS}
    BUILD_BYPRODUCTS ${CMAKE_BINARY_DIR}/adbc/src/adbc_project-build/driver/common/libadbc_driver_common.a
    INSTALL_COMMAND ""
    BUILD_ALWAYS OFF
)

# Download and build folly (depends on fast_float)
ExternalProject_Add(folly_project
    PREFIX ${CMAKE_BINARY_DIR}/folly
    GIT_REPOSITORY https://github.com/facebook/folly.git
    GIT_TAG v2025.05.26.00
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    CMAKE_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DFOLLY_USE_JEMALLOC=ON
        -DBUILD_SHARED_LIBS=ON
        -DCMAKE_INSTALL_PREFIX=${FOLLY_INSTALL_DIR}
        -DCMAKE_PREFIX_PATH=${FAST_FLOAT_INSTALL_DIR}
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> -- -j ${NUMBER_OF_PROCESSORS}
    INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR>
    BUILD_ALWAYS OFF
    DEPENDS fast_float_project
)

# Download and build clickhouse-cpp
ExternalProject_Add(clickhouse_cpp_project
    PREFIX ${CMAKE_BINARY_DIR}/clickhouse-cpp
    GIT_REPOSITORY https://github.com/ClickHouse/clickhouse-cpp.git
    GIT_TAG v2.5.1
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    CMAKE_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_SHARED_LIBS=ON
        -DCMAKE_INSTALL_PREFIX=${CLICKHOUSE_CPP_INSTALL_DIR}
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> -j ${NUMBER_OF_PROCESSORS}
    INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR>
    BUILD_ALWAYS OFF
)

# Download and build cityhash
ExternalProject_Add(cityhash_project
    PREFIX ${CMAKE_BINARY_DIR}/cityhash
    GIT_REPOSITORY https://github.com/google/cityhash.git
    GIT_TAG master
    GIT_SHALLOW 1
    GIT_PROGRESS 1
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${CITYHASH_INSTALL_DIR}
    BUILD_COMMAND make -j ${NUMBER_OF_PROCESSORS}
    INSTALL_COMMAND make install
    BUILD_IN_SOURCE 1
    BUILD_ALWAYS OFF
)

# Set up include and library directories
set(ARROW_INCLUDE_DIR ${ARROW_INSTALL_DIR}/include)
set(ARROW_LIBRARY_DIR ${ARROW_INSTALL_DIR}/lib)
set(DUCKDB_INCLUDE_DIR ${DUCKDB_INSTALL_DIR}/include)
set(DUCKDB_LIBRARY_DIR ${DUCKDB_INSTALL_DIR}/lib)
set(ADBC_INCLUDE_DIR ${CMAKE_BINARY_DIR}/adbc/src/adbc_project)
set(ADBC_LIBRARY_DIR ${CMAKE_BINARY_DIR}/adbc/src/adbc_project-build/driver/common)
set(FAST_FLOAT_INCLUDE_DIR ${FAST_FLOAT_INSTALL_DIR}/include)
set(FOLLY_INCLUDE_DIR ${FOLLY_INSTALL_DIR}/include)
set(FOLLY_LIBRARY_DIR ${FOLLY_INSTALL_DIR}/lib)
set(CLICKHOUSE_CPP_INCLUDE_DIR ${CLICKHOUSE_CPP_INSTALL_DIR}/include)
set(CLICKHOUSE_CPP_LIBRARY_DIR ${CLICKHOUSE_CPP_INSTALL_DIR}/lib)
set(CITYHASH_INCLUDE_DIR ${CITYHASH_INSTALL_DIR}/include)
set(CITYHASH_LIBRARY_DIR ${CITYHASH_INSTALL_DIR}/lib)

# 创建一个自定义目标来复制库文件
add_custom_target(copy_libraries ALL
    # 放置到对应的系统目录下
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/arrow/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/arrow/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/duckdb/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/duckdb/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/adbc/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/adbc/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/fast_float/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/folly/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/folly/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/clickhouse-cpp/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/clickhouse-cpp/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/cityhash/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/cityhash/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARROW_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/arrow/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${DUCKDB_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/duckdb/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARROW_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/arrow/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${DUCKDB_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/duckdb/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ADBC_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/adbc/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ADBC_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/adbc/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${FAST_FLOAT_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/fast_float/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${FOLLY_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/folly/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${FOLLY_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/folly/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CLICKHOUSE_CPP_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/clickhouse-cpp/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CLICKHOUSE_CPP_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/clickhouse-cpp/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CITYHASH_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/cityhash/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CITYHASH_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/${CMAKE_SYSTEM_NAME}/cityhash/lib
)

# 添加依赖关系，确保库先被编译
add_dependencies(copy_libraries arrow_project duckdb_project adbc_project fast_float_project folly_project clickhouse_cpp_project cityhash_project)

# 添加清理目标
add_custom_target(clean_all
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/arrow
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/duckdb
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/adbc
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/external
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/arrow_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/duckdb_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/adbc_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/fast_float
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/folly
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/clickhouse-cpp
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/cityhash
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/fast_float_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/folly_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/clickhouse_cpp_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/cityhash_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/prebuild
    COMMENT "Cleaning all built libraries and copied files..."
)
