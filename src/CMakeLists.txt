# Modifications (c) 2019-2026 Advanced Micro Devices, Inc.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
# OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# This option only works for make/nmake and the ninja generators, but no reason it shouldn't be on all the time
# This tells cmake to create a compile_commands.json file that can be used with clang tooling or vim
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Configure a header file to pass the rocALUTION version
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Version.hpp.in"
               "${PROJECT_BINARY_DIR}/include/Version.hpp"
)

# HPCG CUDA (device-kernel-containing) sources
set(rochpcg_hip_source
  ComputeDotProduct.cpp
  ComputeSPMV.cpp
  ComputeSYMGS.cpp
  ComputeProlongation.cpp
  ComputeResidual.cpp
  ComputeRestriction.cpp
  ComputeWAXPBY.cpp
  ExchangeHalo.cpp
  GenerateCoarseProblem.cpp
  GenerateProblem.cpp
  MultiColoring.cpp
  Permute.cpp
  SetupHalo.cpp
  SparseMatrix.cpp
  TestCG.cpp
)

# HPCG sources
set(rochpcg_source
  CG.cpp
  CG_ref.cpp
  CheckAspectRatio.cpp
  CheckProblem.cpp
  ComputeDotProduct_ref.cpp
  ComputeMG.cpp
  ComputeMG_ref.cpp
  ComputeOptimalShapeXYZ.cpp
  ComputeProlongation_ref.cpp
  ComputeRestriction_ref.cpp
  ComputeSPMV_ref.cpp
  ComputeSYMGS_ref.cpp
  ComputeWAXPBY_ref.cpp
  GenerateGeometry.cpp
  init.cpp
  Memory.cpp
  MixedBaseCounter.cpp
  OptimizeProblem.cpp
  OutputFile.cpp
  ReadHpcgDat.cpp
  ReportResults.cpp
  TestNorms.cpp
  TestSymmetry.cpp
  WriteProblem.cpp
  YAML_Doc.cpp
  YAML_Element.cpp
  finalize.cpp
  mytimer.cpp
)

# Mark the device-kernel-containing files as CUDA sources so nvcc compiles
# them, regardless of their .cpp extension (keeping .cpp avoids renaming
# every file to .cu and minimizes diff churn versus the original HIP source).
set_source_files_properties(${rochpcg_hip_source} PROPERTIES LANGUAGE CUDA)

# NOTE: Do NOT name these variables CMAKE_CUDA_FLAGS/CMAKE_HOST_FLAGS - those
# are reserved CMake variables that CMake itself auto-injects (as a raw,
# unsplit string, not a CMake list) into every compile command. Reusing the
# name causes our semicolon-separated list to be duplicated into the command
# line as one literal unsplit token (e.g. "-O3;--use_fast_math;--extended-lambda"),
# which nvcc/sh then fails to parse (semicolons get passed straight through to
# a subshell, which tries to run "--use_fast_math" as a command). Using our
# own distinctly-named list variables avoids this collision entirely.
#
# Release/Debug flags. nvcc's --use_fast_math bundles the class of
# approximations the original HIPCC flags (-ffp-contract=fast -ffast-math
# -funsafe-math-optimizations) requested. --expt-relaxed-constexpr allows
# constexpr host functions to be called from device code and vice versa;
# this has been an "experimental" nvcc flag for close to a decade and is
# safe/expected to always be enabled.
list(APPEND HPCG_CUDA_FLAGS "-O3;--use_fast_math;--extended-lambda;--expt-relaxed-constexpr")
list(APPEND HPCG_HOST_FLAGS "-O3;-march=native")

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
list(APPEND HPCG_CUDA_FLAGS "-g;-G")
list(APPEND HPCG_HOST_FLAGS "-g")
endif()

# Target executable (native CMake CUDA-language executable, replacing the
# HIP-CMake-package's hip_add_executable() macro)
if(BUILD_TEST)
  add_executable(rochpcg ${rochpcg_source} rochpcg_gtest_main.cpp test_rochpcg.cpp ${rochpcg_hip_source})
else()
  add_executable(rochpcg ${rochpcg_source} main.cpp ${rochpcg_hip_source})
endif()

# Needed for cross-TU device linking, since cudaLaunchCooperativeKernel-style
# kernels and their host wrappers are spread across multiple *_hip_source
# translation units.
set_target_properties(rochpcg PROPERTIES
  CUDA_SEPARABLE_COMPILATION ON
  CUDA_RESOLVE_DEVICE_SYMBOLS ON
)

target_compile_options(rochpcg PRIVATE
  $<$<COMPILE_LANGUAGE:CXX>:${HPCG_HOST_FLAGS}>
  $<$<COMPILE_LANGUAGE:CUDA>:${HPCG_CUDA_FLAGS} -Xcompiler=-march=native>
)

# Support only for contiguous arrays
target_compile_definitions(rochpcg PRIVATE HPCG_CONTIGUOUS_ARRAYS)

if(HPCG_DEBUG)
  target_compile_definitions(rochpcg PRIVATE HPCG_DEBUG)
endif()

if(HPCG_DETAILED_DEBUG)
  target_compile_definitions(rochpcg PRIVATE HPCG_DETAILED_DEBUG)
endif()

if(HPCG_DETAILED_TIMING)
  target_compile_definitions(rochpcg PRIVATE HPCG_DETAILED_TIMING)
endif()

if(HPCG_REFERENCE)
  target_compile_definitions(rochpcg PRIVATE HPCG_REFERENCE)
endif()

if(BUILD_TEST)
  target_compile_definitions(rochpcg PRIVATE GOOGLE_TEST)
endif()

# Optimization definitions
if(OPT_MEMMGMT)
  target_compile_definitions(rochpcg PRIVATE HPCG_MEMMGMT)
endif()
if(OPT_DEFRAG)
  target_compile_definitions(rochpcg PRIVATE DEFRAG_OPT)
endif()
if(GPU_AWARE_MPI)
  target_compile_definitions(rochpcg PRIVATE GPU_AWARE_MPI)
endif()

# Target include directories
target_include_directories(rochpcg
                             PRIVATE
                               $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>)

# CUDA runtime (replaces hip::host)
target_link_libraries(rochpcg PRIVATE CUDA::cudart)

# NVTX (was: Roctx / OPT_ROCTX)
if(OPT_NVTX)
  target_compile_definitions(rochpcg PRIVATE OPT_NVTX)
  target_link_libraries(rochpcg PRIVATE ${HPCG_NVTX_TARGET})
endif()

# MPI
if(HPCG_MPI)
  target_link_libraries(rochpcg PRIVATE MPI::MPI_CXX libnuma::libnuma)
else()
  target_compile_definitions(rochpcg PRIVATE HPCG_NO_MPI)
endif()

# OpenMP
if(HPCG_OPENMP)
  target_link_libraries(rochpcg PRIVATE OpenMP::OpenMP_CXX)
else()
  target_compile_definitions(rochpcg PRIVATE HPCG_NO_OPENMP)
endif()

# CUB (rocPRIM's CUDA-native equivalent) ships header-only with the CUDA
# Toolkit -- no link target needed (replaces target_link_libraries(... roc::rocprim)).

if(BUILD_TEST)
  target_link_libraries(rochpcg PRIVATE GTest::GTest)
endif()

# Target properties
set_target_properties(rochpcg PROPERTIES VERSION ${rochpcg_VERSION})
if(BUILD_TEST)
  set_target_properties(rochpcg PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests")
  set_target_properties(rochpcg PROPERTIES OUTPUT_NAME "rochpcg-test")
  install(TARGETS rochpcg RUNTIME DESTINATION tests)
else()
  set_target_properties(rochpcg PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
endif()
set_target_properties(rochpcg PROPERTIES DEBUG_POSTFIX "-d")

# Install targets (rocm_install_targets/rocm_install_symlink_subdir macros
# no longer available; plain install() used instead)
install(TARGETS rochpcg RUNTIME DESTINATION bin)

# Package specific CPACK vars
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/../LICENSE.md")

if(NOT CPACK_PACKAGING_INSTALL_PREFIX)
  set(CPACK_PACKAGING_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")
endif()

set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION "\${CPACK_PACKAGING_INSTALL_PREFIX}" "\${CPACK_PACKAGING_INSTALL_PREFIX}/include")

# Package name
set(package_name rochpcg)
set(CPACK_PACKAGE_NAME ${package_name})
set(CPACK_PACKAGE_VERSION ${rochpcg_VERSION})
set(CPACK_DEBIAN_PACKAGE_DEPENDS "cuda-toolkit")
set(CPACK_RPM_PACKAGE_REQUIRES "cuda-toolkit")
include(CPack)
