# To debug, compile with 
# $ cmake -DCMAKE_BUILD_TYPE=Debug ../

cmake_minimum_required(VERSION 3.19)
project(SST VERSION 1.0.0 LANGUAGES C)

# Check `openssl version -d` and copy the path to OPENSSL_ROOT_DIR
if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(OPENSSL_ROOT_DIR "/usr/local/lib64")
endif()

find_package(OpenSSL REQUIRED)
find_package(Threads REQUIRED)

add_library(SSTLIB SHARED      
  ${CMAKE_CURRENT_LIST_DIR}/c_api.c
  ${CMAKE_CURRENT_LIST_DIR}/c_common.c
  ${CMAKE_CURRENT_LIST_DIR}/c_crypto.c
  ${CMAKE_CURRENT_LIST_DIR}/c_secure_comm.c
  ${CMAKE_CURRENT_LIST_DIR}/load_config.c)

target_link_libraries(SSTLIB OpenSSL::SSL Threads::Threads)

if(MSVC)
  target_compile_options(SSTLIB PRIVATE /W4 /WX)
else()
  target_compile_options(SSTLIB PRIVATE -Wall -Wextra -Wpedantic)
endif()

install(TARGETS SSTLIB DESTINATION lib)

install(FILES c_api.h DESTINATION include/sst-c-api)
