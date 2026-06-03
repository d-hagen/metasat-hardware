# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/ext/spdlog"
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-build"
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix"
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix/tmp"
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix/src/spdlog-populate-stamp"
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix/src"
  "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix/src/spdlog-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix/src/spdlog-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/home/dan/metasat-hardware/extra/vortex/third_party/ramulator/build/_deps/spdlog-subbuild/spdlog-populate-prefix/src/spdlog-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
