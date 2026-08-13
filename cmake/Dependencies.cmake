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
#
# Dependencies
#
# NOTE (CUDA port): find_package(HIP)/find_package(rocprim), the manual
# roctracer/roctx find_library()+add_library(IMPORTED) block, and the
# rocm-cmake bootstrap-download-if-not-found + ROCMxxx include block have all
# been replaced below with find_package(CUDAToolkit), which provides
# CUDA::cudart/CUDA::cublas-equivalent imported targets directly with no
# manual find_library boilerplate. CUB (rocPRIM's CUDA-native equivalent)
# ships header-only with the CUDA Toolkit, so no separate find_package call
# is needed for it.

# Git
find_package(Git REQUIRED)

# Find OpenMP package
find_package(OpenMP)
if (NOT OPENMP_FOUND)
  message("-- OpenMP not found. Compiling WITHOUT OpenMP support.")
else()
  option(HPCG_OPENMP "Compile WITH OpenMP support." ON)
endif()

# MPI
set(MPI_HOME ${HPCG_MPI_DIR})
find_package(MPI)
if (NOT MPI_FOUND)
  message("-- MPI not found. Compiling WITHOUT MPI support.")
  if (HPCG_MPI)
    message(FATAL_ERROR "Cannot build with MPI support.")
  endif()
else()
  option(HPCG_MPI "Compile WITH MPI support." ON)
endif()

# gtest
if(BUILD_TEST)
  find_package(GTest REQUIRED)
endif()

# libnuma if MPI is enabled
if(HPCG_MPI)
  find_package(LIBNUMA REQUIRED)
endif()

# CUDA Toolkit (replaces find_package(HIP)/find_package(rocprim))
find_package(CUDAToolkit REQUIRED)
message(STATUS "CUDA Toolkit version: ${CUDAToolkit_VERSION}")
message(STATUS "CUDA Toolkit include dirs: ${CUDAToolkit_INCLUDE_DIRS}")
message(STATUS "CUDA Toolkit library dir: ${CUDAToolkit_LIBRARY_DIR}")

# NVTX target resolution (replaces the roctracer/roctx find_library +
# add_library(IMPORTED) block). Prefer the header-only NVTX v3 target when
# available, falling back to the legacy imported target otherwise.
if(OPT_NVTX)
  if(TARGET CUDA::nvtx3)
    set(HPCG_NVTX_TARGET CUDA::nvtx3)
  elseif(TARGET CUDA::nvToolsExt)
    set(HPCG_NVTX_TARGET CUDA::nvToolsExt)
  else()
    message(FATAL_ERROR "OPT_NVTX was requested but neither CUDA::nvtx3 nor "
                         "CUDA::nvToolsExt is available from this CUDAToolkit "
                         "CMake package.")
  endif()
  message(STATUS "NVTX target: ${HPCG_NVTX_TARGET}")
endif()
