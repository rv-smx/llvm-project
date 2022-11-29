# LLVM for the RISC-V Stream-Based Memory Access Extension (SMX)

LLVM 15 with the RISC-V stream-based memory access extension (SMX) support, includes:

* SMX builtins for Clang.
* SMX intrinsics for LLVM IR.
* Code generation support for SMX intrinsics.

## SMX Builtins for Clang

### Stream Configuration Builtins

```c
/**
 * @brief Configures induction variable stream.
 * 
 * @param iter_num number of iterations
 */
void __builtin_riscv_smx_cfg_iv(size_t iter_num);

/**
 * @brief Configures memory stream.
 * 
 * @param base start address
 * @param stride stride in bytes
 * @param dep_stream dependent stream ID,
 *                   memory stream if pattern==1,
 *                   otherwise induction variable stream
 * @param r non-zero if readable
 * @param w non-zero if writable
 * @param pattern memory access pattern, 0 for affine, 1 for indirect
 * @param width log2(load width), e.g. 4 for 16-byte load
 */
void __builtin_riscv_smx_cfg_ms(void *base, size_t stride, size_t dep_stream,
                                size_t r, size_t w, size_t pattern, size_t width);
```

### Hint Builtins

```c
/**
 * @brief Marks stream configuration complete.
 */
void __builtin_riscv_smx_ready();

/**
 * @brief Marks the end of all stream operations.
 */
void __builtin_riscv_smx_end();
```

### Memory Stream Load/Store Builtins

```c
/**
 * @brief Loads signed/unsigned 8/16/32/64-bit integer/float data
 *        from the given memory stream.
 * 
 * @param stream memory stream ID
 * @param selector data selector, 0 for the least significant data
 * @return data loaded from the stream
 */
signed char __builtin_riscv_smx_load_i8(size_t stream, size_t selector);
unsigned char __builtin_riscv_smx_load_u8(size_t stream, size_t selector);
short __builtin_riscv_smx_load_i16(size_t stream, size_t selector);
unsigned short __builtin_riscv_smx_load_u16(size_t stream, size_t selector);
int32_t __builtin_riscv_smx_load_i32(size_t stream, size_t selector);
uint32_t __builtin_riscv_smx_load_u32(size_t stream, size_t selector);
int64_t __builtin_riscv_smx_load_i64(size_t stream, size_t selector);
uint64_t __builtin_riscv_smx_load_u64(size_t stream, size_t selector);
float __builtin_riscv_smx_load_f32(size_t stream, size_t selector);
double __builtin_riscv_smx_load_f64(size_t stream, size_t selector);

/**
 * @brief Stores signed/unsigned 8/16/32/64-bit integer/float data
 *        to the given memory stream.
 * 
 * @param stream memory stream ID
 * @param selector data selector, 0 for the least significant data
 * @param data data to be stored to the stream
 */
void __builtin_riscv_smx_store_i8(size_t stream, size_t selector, char data);
void __builtin_riscv_smx_store_i16(size_t stream, size_t selector, short data);
void __builtin_riscv_smx_store_i32(size_t stream, size_t selector, int32_t data);
void __builtin_riscv_smx_store_i64(size_t stream, size_t selector, int64_t data);
void __builtin_riscv_smx_store_f32(size_t stream, size_t selector, float data);
void __builtin_riscv_smx_store_f64(size_t stream, size_t selector, double data);
```

### Induction Variable Stream Builtins

```c
/**
 * @brief Reads the value of the given induction variable stream.
 * 
 * @param stream induction variable stream ID
 * @return value of the stream
 */
size_t __builtin_riscv_smx_read_iv(size_t stream);

/**
 * @brief Writes value to the given induction variable stream.
 * 
 * @param stream induction variable stream ID
 * @param value value to be written to the stream
 */
void __builtin_riscv_smx_write_iv(size_t stream, size_t value);

/**
 * @brief Increments the given induction variable stream.
 * 
 * @param stream induction variable stream ID
 * @param step the increment
 */
void __builtin_riscv_smx_step(size_t stream, ssize_t step);
```

## Command Line Options

* `-march=rv64gc_xsmx`: enables SMX extension for RV64GC targets.

# The LLVM Compiler Infrastructure

This directory and its sub-directories contain the source code for LLVM,
a toolkit for the construction of highly optimized compilers,
optimizers, and run-time environments.

The README briefly describes how to get started with building LLVM.
For more information on how to contribute to the LLVM project, please
take a look at the
[Contributing to LLVM](https://llvm.org/docs/Contributing.html) guide.

## Getting Started with the LLVM System

Taken from [here](https://llvm.org/docs/GettingStarted.html).

### Overview

Welcome to the LLVM project!

The LLVM project has multiple components. The core of the project is
itself called "LLVM". This contains all of the tools, libraries, and header
files needed to process intermediate representations and convert them into
object files. Tools include an assembler, disassembler, bitcode analyzer, and
bitcode optimizer. It also contains basic regression tests.

C-like languages use the [Clang](http://clang.llvm.org/) frontend. This
component compiles C, C++, Objective-C, and Objective-C++ code into LLVM bitcode
-- and from there into object files, using LLVM.

Other components include:
the [libc++ C++ standard library](https://libcxx.llvm.org),
the [LLD linker](https://lld.llvm.org), and more.

### Getting the Source Code and Building LLVM

The LLVM Getting Started documentation may be out of date. The [Clang
Getting Started](http://clang.llvm.org/get_started.html) page might have more
accurate information.

This is an example work-flow and configuration to get and build the LLVM source:

1. Checkout LLVM (including related sub-projects like Clang):

     * ``git clone https://github.com/llvm/llvm-project.git``

     * Or, on windows, ``git clone --config core.autocrlf=false
    https://github.com/llvm/llvm-project.git``

2. Configure and build LLVM and Clang:

     * ``cd llvm-project``

     * ``cmake -S llvm -B build -G <generator> [options]``

        Some common build system generators are:

        * ``Ninja`` --- for generating [Ninja](https://ninja-build.org)
          build files. Most llvm developers use Ninja.
        * ``Unix Makefiles`` --- for generating make-compatible parallel makefiles.
        * ``Visual Studio`` --- for generating Visual Studio projects and
          solutions.
        * ``Xcode`` --- for generating Xcode projects.

        Some common options:

        * ``-DLLVM_ENABLE_PROJECTS='...'`` and ``-DLLVM_ENABLE_RUNTIMES='...'`` ---
          semicolon-separated list of the LLVM sub-projects and runtimes you'd like to
          additionally build. ``LLVM_ENABLE_PROJECTS`` can include any of: clang,
          clang-tools-extra, cross-project-tests, flang, libc, libclc, lld, lldb,
          mlir, openmp, polly, or pstl. ``LLVM_ENABLE_RUNTIMES`` can include any of
          libcxx, libcxxabi, libunwind, compiler-rt, libc or openmp. Some runtime
          projects can be specified either in ``LLVM_ENABLE_PROJECTS`` or in
          ``LLVM_ENABLE_RUNTIMES``.

          For example, to build LLVM, Clang, libcxx, and libcxxabi, use
          ``-DLLVM_ENABLE_PROJECTS="clang" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi"``.

        * ``-DCMAKE_INSTALL_PREFIX=directory`` --- Specify for *directory* the full
          path name of where you want the LLVM tools and libraries to be installed
          (default ``/usr/local``). Be careful if you install runtime libraries: if
          your system uses those provided by LLVM (like libc++ or libc++abi), you
          must not overwrite your system's copy of those libraries, since that
          could render your system unusable. In general, using something like
          ``/usr`` is not advised, but ``/usr/local`` is fine.

        * ``-DCMAKE_BUILD_TYPE=type`` --- Valid options for *type* are Debug,
          Release, RelWithDebInfo, and MinSizeRel. Default is Debug.

        * ``-DLLVM_ENABLE_ASSERTIONS=On`` --- Compile with assertion checks enabled
          (default is Yes for Debug builds, No for all other build types).

      * ``cmake --build build [-- [options] <target>]`` or your build system specified above
        directly.

        * The default target (i.e. ``ninja`` or ``make``) will build all of LLVM.

        * The ``check-all`` target (i.e. ``ninja check-all``) will run the
          regression tests to ensure everything is in working order.

        * CMake will generate targets for each tool and library, and most
          LLVM sub-projects generate their own ``check-<project>`` target.

        * Running a serial build will be **slow**. To improve speed, try running a
          parallel build. That's done by default in Ninja; for ``make``, use the option
          ``-j NNN``, where ``NNN`` is the number of parallel jobs to run.
          In most cases, you get the best performance if you specify the number of CPU threads you have.
          On some Unix systems, you can specify this with ``-j$(nproc)``.

      * For more information see [CMake](https://llvm.org/docs/CMake.html).

Consult the
[Getting Started with LLVM](https://llvm.org/docs/GettingStarted.html#getting-started-with-llvm)
page for detailed information on configuring and compiling LLVM. You can visit
[Directory Layout](https://llvm.org/docs/GettingStarted.html#directory-layout)
to learn about the layout of the source code tree.

## Getting in touch

Join [LLVM Discourse forums](https://discourse.llvm.org/), [discord chat](https://discord.gg/xS7Z362) or #llvm IRC channel on [OFTC](https://oftc.net/).

The LLVM project has adopted a [code of conduct](https://llvm.org/docs/CodeOfConduct.html) for
participants to all modes of communication within the project.
