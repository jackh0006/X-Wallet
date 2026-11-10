cmake_minimum_required(VERSION 3.10)
project(x_wallet_argon2 LANGUAGES C)

# The reference Argon2 implementation (CC0/Apache-2.0). Vendored so the
# Android release always ships the native KDF; it must not depend on a
# third-party Gradle plugin being selected at build time.
add_library(argon2-arm SHARED
  argon2/src/argon2.c
  argon2/src/core.c
  argon2/src/encoding.c
  argon2/src/ref.c
  argon2/src/thread.c
  argon2/src/blake2/blake2b.c
)
target_include_directories(argon2-arm PUBLIC argon2/include)
target_compile_options(argon2-arm PRIVATE -Os)
