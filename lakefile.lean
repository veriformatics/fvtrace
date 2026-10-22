import Lake
open Lake DSL System

package fvtrace where
  version := v!"0.1.0"
  description :=
    "Shows which scientific claims an analysis can and cannot make, under a formal-verification " ++
    "stance."
  keywords := #["formal-verification", "science", "claims", "provenance"]
  license := "Apache-2.0 WITH LLVM-exception"
  licenseFiles := #["LICENSE"]
  readmeFile := "README.md"
  testDriver := "«fvtrace-tests»"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩, ⟨`warningAsError, true⟩]

/-- Files the binary embeds with `include_str`: Lake does not trace those reads, so the library
names them here; an edit then rebuilds the embedding module. -/
input_file traceSchema where
  path := "schema/trace.schema.json"
  text := true

/-- The GUI files `fvtrace serve` embeds (module `FvtraceWeb`): a library of their own, so a GUI
edit rebuilds one module, never the kernel + its proofs. -/
input_dir webFiles where
  path := "web"
  text := true

lean_lib FvtraceWeb where
  needs := #[webFiles]

/-- The Agent Skill `fvtrace skills install` writes (module `FvtraceSkill`), traced like the GUI. -/
input_dir skillFiles where
  path := "skill"
  text := true

lean_lib FvtraceSkill where
  needs := #[skillFiles]

lean_lib Fvtrace where
  needs := #[traceSchema]

lean_lib Tests

/-- Build tooling for the exported page's WebAssembly engine (never linked into `fvtrace`). -/
lean_lib FvtraceWasm

lean_exe «fvtrace-wasm» where
  root := `WasmMain

/-- The exported page's engine (`.agent/contracts/kernel.md` E-build): `fvtrace-wasm` compiles
Lake's C for `Fvtrace.Snapshot`'s import closure + the toolchain's own `Init` + the pinned Lean
runtime to WebAssembly and writes base64(gzip(module)). Traced over the tool, that C, the pins,
the runtime patch + the C bridge, so a change to any of them rebuilds the embedded engine. -/
target engine pkg : System.FilePath := do
  let some tool ← findLeanExe? `«fvtrace-wasm» | error "no executable fvtrace-wasm"
  let some root ← findModule? `Fvtrace.Snapshot | error "no module Fvtrace.Snapshot"
  let closure := (← (← root.transImports.fetch).await).push root
  let cJob := Job.collectArray (← closure.mapM (·.c.fetch))
  let inputs := Job.collectArray (← #["tools/wasm.lock", "tools/wasm/lean-runtime.patch",
    "c/page_engine.c"].mapM fun (p : String) => inputTextFile (pkg.dir / p))
  let toolJob ← tool.exe.fetch
  let out := pkg.buildDir / "wasm" / "engine.b64"
  (toolJob.zipWith (·, ·) (cJob.zipWith (·, ·) inputs)).mapM fun (exe, cFiles, _) => do
    addLeanTrace
    buildFileUnlessUpToDate' out (text := true) do
      let lean ← getLeanInstall
      proc { cmd := exe.toString, args := #["--root", pkg.dir.toString,
        "--cache", (pkg.buildDir / "wasm").toString, "--lean", lean.lean.toString,
        "--lean-src", lean.srcDir.toString, "--githash", lean.githash, "--out", out.toString] ++
        cFiles.map (·.toString) }
    return out

/-- The page engine `fvtrace export --html` embeds (module `FvtraceEngine`). -/
lean_lib FvtraceEngine where
  needs := #[engine]

@[default_target]
lean_exe fvtrace where
  root := `Main

lean_exe «fvtrace-tests» where
  root := `TestMain

/-- Dev-only audit: imports `Lean` (a 118 MB link), so it stays out of the shipped binary. -/
lean_exe «fvtrace-trust» where
  root := `TrustMain
  supportInterpreter := true

/-- HACL*'s verified SHA-256 (`c/hacl`, vendored by `tools/vendor-hacl.sh`, compiled verbatim)
+ the FFI shim (`c/fvtrace_digest.c`, warnings are errors). The system C compiler builds them
(`CC`, default `cc`): Lean's bundled clang carries no libc headers. -/
extern_lib fvtracec pkg := do
  let cc := (← IO.getEnv "CC").getD "cc"
  let hacl := pkg.dir / "c" / "hacl"
  let includes := #["-I", (← getLeanIncludeDir).toString, "-I", hacl.toString,
    "-I", (hacl / "include").toString]
  let common := #["-O2", "-fPIC", "-DKRML_VERIFIED_UINT128"]
  let haclO ← buildO (pkg.buildDir / "c" / "Hacl_Hash_SHA2.o")
    (← inputTextFile (hacl / "Hacl_Hash_SHA2.c")) includes common cc
  let shimO ← buildO (pkg.buildDir / "c" / "fvtrace_digest.o")
    (← inputTextFile (pkg.dir / "c" / "fvtrace_digest.c")) includes
    (common ++ #["-Wall", "-Wextra", "-Werror"]) cc
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "fvtracec") #[haclO, shimO]
