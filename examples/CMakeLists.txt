cmake_minimum_required (VERSION 3.22)
set_property (GLOBAL PROPERTY USE_FOLDERS ON)
project (RapidlyExamples)
set (CMAKE_CXX_STANDARD 11)

add_library (rapidly-engine SHARED IMPORTED)
if (MSVC)
  set (RAPIDLY_DLL "${CMAKE_SOURCE_DIR}/../bin/windows-x64/RapidlyEngine.dll")
  set_target_properties (rapidly-engine PROPERTIES
    IMPORTED_IMPLIB "${CMAKE_SOURCE_DIR}/../bin/windows-x64/RapidlyEngine.lib"
    IMPORTED_LOCATION "${RAPIDLY_DLL}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/../include")
elseif (APPLE)
  if (${CMAKE_SYSTEM_NAME} MATCHES "iOS")
    set (RAPIDLY_DLL "${CMAKE_SOURCE_DIR}/../bin/ios/libRapidlyEngine.dylib")
  else()
    set (RAPIDLY_DLL "${CMAKE_SOURCE_DIR}/../bin/macos/libRapidlyEngine.dylib")
  endif()
  set_target_properties (rapidly-engine PROPERTIES
    IMPORTED_LOCATION "${RAPIDLY_DLL}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/../include")
  # iOS / macOS app developers will typically prefer the .xcframework
  # at ../bin/RapidlyEngine.xcframework, integrated via Xcode or
  # SwiftPM. This example uses the raw .dylib for cross-platform
  # consistency with the Linux / Windows examples.
else()
  if (${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")
    set (RAPIDLY_DLL "${CMAKE_SOURCE_DIR}/../bin/linux-arm64/libRapidlyEngine.so")
  else()
    set (RAPIDLY_DLL "${CMAKE_SOURCE_DIR}/../bin/linux-x64/libRapidlyEngine.so")
  endif()
  set_target_properties (rapidly-engine PROPERTIES
    IMPORTED_LOCATION "${RAPIDLY_DLL}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/../include")
endif()

add_subdirectory (riffwave)
add_subdirectory (process-file)
