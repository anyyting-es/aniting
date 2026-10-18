# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(seanime_app LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "seanime_app")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# libmpv comes from unified mpv-build repository (edde746/mpv-build)
set(MPV_LOCK_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../mpv-build.lock.json")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${MPV_LOCK_FILE}")
file(READ "${MPV_LOCK_FILE}" MPV_LOCK)
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
  set(MPV_ARCH "aarch64")
else()
  set(MPV_ARCH "x86_64")
endif()
string(JSON MPV_ASSET_BASE GET "${MPV_LOCK}" artifacts windows assetBase)
string(JSON MPV_ASSET GET "${MPV_LOCK}" artifacts windows assets "${MPV_ARCH}" asset)
string(JSON MPV_SHA256 GET "${MPV_LOCK}" artifacts windows assets "${MPV_ARCH}" checksum)

include(FetchContent)
FetchContent_Declare(
  mpv_dev
  URL "${MPV_ASSET_BASE}/${MPV_ASSET}"
  URL_HASH SHA256=${MPV_SHA256}
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(mpv_dev)

set(MPV_INCLUDE_DIR "${mpv_dev_SOURCE_DIR}/include")
set(MPV_LIB_DIR "${mpv_dev_SOURCE_DIR}")

# Vulkan loader
set(VULKAN_RT_VERSION "1.4.357.0")
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
  set(VULKAN_RT_SLUG "warm")
  set(VULKAN_RT_COMPONENTS "VulkanRT-ARM64-${VULKAN_RT_VERSION}-Components")
  set(VULKAN_RT_DLL_SUBPATH "${VULKAN_RT_COMPONENTS}/vulkan-1.dll")
  set(VULKAN_RT_SHA256 "0a51a619525e0c7a156125c4f80c4f591c494cef9ff59dc4481735779a9a280c")
else()
  set(VULKAN_RT_SLUG "windows")
  set(VULKAN_RT_COMPONENTS "VulkanRT-X64-${VULKAN_RT_VERSION}-Components")
  set(VULKAN_RT_DLL_SUBPATH "${VULKAN_RT_COMPONENTS}/x64/vulkan-1.dll")
  set(VULKAN_RT_SHA256 "a14672efed15aafc7f5a16572d35cd3a3416eadf670aeee3cdf50ee32d5fbf83")
endif()
set(VULKAN_RT_DIR "${CMAKE_BINARY_DIR}/vulkan-runtime")
if(NOT EXISTS "${VULKAN_RT_DIR}/vulkan-1.dll" OR NOT EXISTS "${VULKAN_RT_DIR}/VulkanRT-License.txt")
  set(VULKAN_RT_ZIP "${VULKAN_RT_DIR}/vulkan-runtime-components.zip")
  message(STATUS "Downloading Vulkan runtime (${VULKAN_RT_SLUG} ${VULKAN_RT_VERSION})...")
  file(DOWNLOAD
    "https://sdk.lunarg.com/sdk/download/${VULKAN_RT_VERSION}/${VULKAN_RT_SLUG}/vulkan-runtime-components.zip"
    "${VULKAN_RT_ZIP}"
    HTTPHEADER "User-Agent: curl/8.4.0"
    EXPECTED_HASH SHA256=${VULKAN_RT_SHA256}
    STATUS VULKAN_RT_DL_STATUS)
  list(GET VULKAN_RT_DL_STATUS 0 VULKAN_RT_DL_RESULT)
  if(NOT VULKAN_RT_DL_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to download Vulkan runtime: ${VULKAN_RT_DL_STATUS}")
  endif()
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xf "${VULKAN_RT_ZIP}"
    WORKING_DIRECTORY "${VULKAN_RT_DIR}"
    RESULT_VARIABLE VULKAN_RT_EXTRACT_RESULT
  )
  if(NOT VULKAN_RT_EXTRACT_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to extract Vulkan runtime archive")
  endif()
  file(RENAME "${VULKAN_RT_DIR}/${VULKAN_RT_DLL_SUBPATH}" "${VULKAN_RT_DIR}/vulkan-1.dll")
  file(RENAME "${VULKAN_RT_DIR}/${VULKAN_RT_COMPONENTS}/VulkanRT-License.txt"
    "${VULKAN_RT_DIR}/VulkanRT-License.txt")
  file(REMOVE_RECURSE "${VULKAN_RT_DIR}/${VULKAN_RT_COMPONENTS}")
  file(REMOVE "${VULKAN_RT_ZIP}")
endif()

# Fetch simdutf for SIMD-accelerated UTF-8 validation
FetchContent_Declare(
  simdutf
  URL https://github.com/simdutf/simdutf/releases/download/v6.4.2/singleheader.zip
  URL_HASH SHA256=9fe4d6f515724a55c8de88fee4463e0890a1abe2267cda13c4b5d245d58039e6
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(simdutf)

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime
   OPTIONAL)

# Bundle seanime.exe on install/release if present
set(BACKEND_BIN "${CMAKE_CURRENT_SOURCE_DIR}/../backend/seanime.exe")
if(EXISTS "${BACKEND_BIN}")
  install(FILES "${BACKEND_BIN}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# Install mpv DLL
install(CODE "
  file(REMOVE \"${INSTALL_BUNDLE_LIB_DIR}/libmpv-2.dll\")
  " COMPONENT Runtime)
install(FILES "${MPV_LIB_DIR}/libmpv-2.dll"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# Install Vulkan loader
install(FILES "${VULKAN_RT_DIR}/vulkan-1.dll" "${VULKAN_RT_DIR}/VulkanRT-License.txt"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

