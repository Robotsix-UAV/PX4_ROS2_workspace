cmake_minimum_required(VERSION 3.8)
project(lift_drag_system)

find_package(gz-cmake3 REQUIRED)

find_package(gz-sim7 REQUIRED)
gz_find_package(gz-plugin2 REQUIRED COMPONENTS register)
set(GZ_PLUGIN_VER ${gz-plugin2_VERSION_MAJOR})
gz_find_package(gz-common5)
set(GZ_COMMON_VER ${gz-common5_VERSION_MAJOR})

add_library(${PROJECT_NAME} SHARED src/lift_drag_system.cpp)
target_include_directories(${PROJECT_NAME} PRIVATE include)
set_property(TARGET ${PROJECT_NAME} PROPERTY CXX_STANDARD 17)
target_link_libraries(${PROJECT_NAME}
  PUBLIC
  gz-common${GZ_COMMON_VER}::gz-common${GZ_COMMON_VER}
  gz-plugin${GZ_PLUGIN_VER}::register
  gz-sim7::gz-sim7
)

install(
  TARGETS ${PROJECT_NAME}
  DESTINATION lib
)
