# Third-party software in fvTrace

The `fvtrace` program contains code from other projects. The table shows each project, its
license, and the file in the `licenses` folder that holds the license text.

| Project | Where it is | License | File |
|---|---|---|---|
| Lean 4 runtime and core library | the program and the engine of an exported page | Apache License 2.0 | `licenses/lean.txt` |
| Libraries that the Lean toolchain links into each program, for example GMP and LLVM | the program | Several licenses | `licenses/lean-toolchain.txt` |
| libuv | the program | MIT License | `licenses/libuv.txt` |
| HACL* (SHA-256) | the program | Apache License 2.0 or MIT License | `licenses/hacl-star.txt` |
| mimalloc | the program and the engine of an exported page | MIT License | `licenses/mimalloc.txt` |
| Emscripten system libraries | the engine of an exported page | MIT License or University of Illinois/NCSA License | `licenses/emscripten.txt` |
| musl libc | the engine of an exported page | MIT License | `licenses/musl.txt` |

The program contains GMP, which is under the GNU Lesser General Public License version 3.
fvTrace links GMP statically. If you want to use fvTrace with a different version of GMP, build
fvTrace from its source code. The source code of this version is at
<https://github.com/veriformatics/fvtrace/tree/v@VERSION@>.
