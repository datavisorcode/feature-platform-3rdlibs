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

# CPU core count
cmake_host_system_information(RESULT NUMBER_OF_PROCESSORS QUERY NUMBER_OF_LOGICAL_CORES)
message(STATUS "Number of processors: ${NUMBER_OF_PROCESSORS}")

# Download and build Arrow
ExternalProject_Add(arrow_project
    PREFIX ${CMAKE_BINARY_DIR}/arrow
    GIT_REPOSITORY https://github.com/apache/arrow.git
    GIT_TAG apache-arrow-17.0.0
    SOURCE_SUBDIR cpp
    CMAKE_ARGS
        -DARROW_BUILD_SHARED=ON
        -DARROW_PARQUET=ON
        -DARROW_WITH_BROTLI=OFF
        -DARROW_WITH_ZSTD=OFF
        -DARROW_WITH_LZ4=OFF
        -DARROW_WITH_SNAPPY=OFF
        -DARROW_WITH_ZLIB=OFF
        -DARROW_CGLIB=OFF
        -DARROW_BUILD_STATIC=OFF
        -DARROW_BUILD_TESTS=OFF
        -DARROW_BUILD_EXAMPLES=OFF
        -DARROW_FLIGHT=OFF
        -DARROW_FILESYSTEM=OFF
        -DARROW_PYTHON=OFF
        -DARROW_CUDA=OFF
        -DARROW_JEMALLOC=OFF
        -DCMAKE_INSTALL_PREFIX=${ARROW_INSTALL_DIR}
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --target all -- -j ${NUMBER_OF_PROCESSORS}
    BUILD_ALWAYS OFF
    INSTALL_DIR ${ARROW_INSTALL_DIR}
)

# Download and build DuckDB
ExternalProject_Add(duckdb_project
    PREFIX ${CMAKE_BINARY_DIR}/duckdb
    GIT_REPOSITORY https://github.com/duckdb/duckdb.git
    GIT_TAG v1.1.1
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
    SOURCE_SUBDIR c
    CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/adbc/src/adbc_project-build
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --target all -- -j ${NUMBER_OF_PROCESSORS}
    BUILD_BYPRODUCTS ${CMAKE_BINARY_DIR}/adbc/src/adbc_project-build/driver/common/libadbc_driver_common.a
    INSTALL_COMMAND ""
    BUILD_ALWAYS OFF
)

# Set up include and library directories
set(ARROW_INCLUDE_DIR ${ARROW_INSTALL_DIR}/include)
set(ARROW_LIBRARY_DIR ${ARROW_INSTALL_DIR}/lib)
set(DUCKDB_INCLUDE_DIR ${DUCKDB_INSTALL_DIR}/include)
set(DUCKDB_LIBRARY_DIR ${DUCKDB_INSTALL_DIR}/lib)
set(ADBC_INCLUDE_DIR ${CMAKE_BINARY_DIR}/adbc/src/adbc_project)
set(ADBC_LIBRARY_DIR ${CMAKE_BINARY_DIR}/adbc/src/adbc_project-build/driver/common)


# Detect the operating system to handle linking for macOS (.dylib) and Linux (.so)
if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(ARROW_LIB ${ARROW_LIBRARY_DIR}/libarrow.dylib)
    set(DUCKDB_LIB ${DUCKDB_LIBRARY_DIR}/libduckdb.dylib)
else()
    set(ARROW_LIB ${ARROW_LIBRARY_DIR}/libarrow.so)
    set(DUCKDB_LIB ${DUCKDB_LIBRARY_DIR}/libduckdb.so)
endif()

# 创建一个自定义目标来复制库文件
add_custom_target(copy_libraries ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/arrow/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/duckdb/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/arrow/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/duckdb/lib
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/adbc/include
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/prebuild/adbc/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARROW_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/arrow/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${DUCKDB_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/duckdb/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARROW_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/arrow/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${DUCKDB_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/duckdb/lib
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ADBC_INCLUDE_DIR} ${CMAKE_BINARY_DIR}/prebuild/adbc/include
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${ADBC_LIBRARY_DIR} ${CMAKE_BINARY_DIR}/prebuild/adbc/lib
)

# 添加依赖关系，确保库先被编译
add_dependencies(copy_libraries arrow_project duckdb_project adbc_project)

# 添加清理目标
add_custom_target(clean_all
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/arrow
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/duckdb
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/adbc
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/external
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/arrow_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/duckdb_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/adbc_project
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/prebuild
    COMMENT "Cleaning all built libraries and copied files..."
)
