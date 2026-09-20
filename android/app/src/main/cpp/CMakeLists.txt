cmake_minimum_required(VERSION 3.22.1)
project("edgerag" C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_options(-O3 -fPIC)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
)

set(EDGERAG_SOURCES
    rag_engine.cpp
    tokenizer.cpp
    embedding_engine.cpp
    vector_store.cpp
    knowledge_pack.cpp
    llama_engine.cpp
    sqlite3.c
)

add_library(edgerag SHARED ${EDGERAG_SOURCES})

target_compile_definitions(edgerag PRIVATE
    SQLITE_ENABLE_RTREE=1
    SQLITE_ENABLE_FTS5=1
    SQLITE_ENABLE_JSON1=1
    SQLITE_THREADSAFE=1
)

find_library(log-lib log)

target_link_libraries(edgerag
    ${log-lib}
    ${CMAKE_DL_LIBS}
)

