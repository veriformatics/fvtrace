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

lean_lib Fvtrace where
  needs := #[traceSchema]

lean_lib Tests

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
