cmake_minimum_required(VERSION 3.13)
project(appmodules)

# Get the path to shared cpp directory
get_filename_component(PLAYER_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../cpp" ABSOLUTE)

# Include React Native application setup
include(${REACT_ANDROID_DIR}/cmake-utils/ReactNative-application.cmake)

# Add shared PlayerStateCoordinator C++ sources to appmodules target
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    ${PLAYER_CPP_DIR}/PlayerStateCoordinator.cpp
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    ${PLAYER_CPP_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(${CMAKE_PROJECT_NAME}
    log
)
