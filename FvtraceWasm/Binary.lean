/-!
# The import + export sections of a WebAssembly module

The page engine's link check (`kernel.md` E-build): the module may import only what the page's
loader provides and must export what it calls. Parsed here rather than by a disassembler so the
check needs no extra tool on any platform.
-/

namespace FvtraceWasm.Binary

structure Import where
  module : String
  name : String
  /-- 0 function · 1 table · 2 memory · 3 global · 4 tag. -/
  kind : Nat
  deriving Repr, BEq, DecidableEq

structure Export where
  name : String
  kind : Nat
  deriving Repr, BEq, DecidableEq

structure Module where
  imports : List Import := []
  exports : List Export := []
  deriving Repr, BEq

abbrev P := StateT Nat (ReaderT ByteArray (Except String))

def byte : P Nat := do
  let p ← get
  let b ← read
  if h : p < b.size then
    set (p + 1)
    return b[p].toNat
  throw s!"truncated at byte {p}"

/-- Unsigned LEB128 (at most 10 bytes: a u64). -/
def leb : P Nat := go 10 0 0
where
  go : Nat → Nat → Nat → P Nat
    | 0, _, _ => throw "LEB128 longer than 10 bytes"
    | fuel + 1, shift, acc => do
      let b ← byte
      let acc := acc + (b % 128) * 2 ^ shift
      if b < 128 then return acc else go fuel (shift + 7) acc

def name : P String := do
  let n ← leb
  let p ← get
  let b ← read
  unless p + n ≤ b.size do throw s!"name of {n} bytes runs past the end at byte {p}"
  set (p + n)
  match String.fromUTF8? (b.extract p (p + n)) with
  | some s => return s
  | none => throw s!"name at byte {p} is not UTF-8"

/-- Memory or table limits: flag bit 0 = a maximum follows (bits 1 + 2: shared, 64-bit). -/
def limits : P Unit := do
  let flags ← byte
  discard leb
  if flags % 2 == 1 then discard leb

def refType : P Unit := do
  let t ← byte
  -- 0x63 / 0x64 = (ref null? heaptype), heaptype as a signed LEB (a type index or abstract type)
  if t == 0x63 || t == 0x64 then discard leb

def importDesc : P Nat := do
  let kind ← byte
  match kind with
  | 0 => discard leb
  | 1 => refType; limits
  | 2 => limits
  | 3 => discard byte; discard byte
  | 4 => discard byte; discard leb
  | k => throw s!"unknown import kind {k}"
  return kind

def vec {α : Type} (item : P α) : P (List α) := do
  let n ← leb
  let rec go : Nat → List α → P (List α)
    | 0, acc => return acc.reverse
    | k + 1, acc => do go k ((← item) :: acc)
  go n []

def imports : P (List Import) :=
  vec do
    let module ← name
    let field ← name
    let kind ← importDesc
    return { module, name := field, kind }

def exports : P (List Export) :=
  vec do
    let n ← name
    let kind ← byte
    discard leb
    return { name := n, kind }

/-- Every section in order; the import (2) and export (7) sections are read, the rest skipped. -/
def sections : Nat → Module → P Module
  | 0, _ => throw "too many sections"
  | fuel + 1, m => do
    let b ← read
    if (← get) ≥ b.size then return m
    let id ← byte
    let size ← leb
    let start ← get
    unless start + size ≤ b.size do throw s!"section {id} runs past the end"
    let m ← match id with
      | 2 => do pure { m with imports := ← imports }
      | 7 => do pure { m with exports := ← exports }
      | _ => pure m
    unless (← get) ≤ start + size do throw s!"section {id} reads past its size"
    set (start + size)
    sections fuel m

def magic : List Nat := [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

def parse (b : ByteArray) : Except String Module := do
  unless (b.extract 0 8).toList.map (·.toNat) == magic do
    throw "not a WebAssembly 1 module"
  let (m, _) ← (sections b.size {}).run 8 |>.run b
  return m

/-! ## The page engine's link contract -/

/-- What the page's loader (`web/engine.js`) provides. -/
def allowedImports : List (String × String) :=
  [("env", "emscripten_notify_memory_growth")] ++
  (["proc_exit", "fd_close", "fd_read", "fd_write", "fd_seek", "fd_fdstat_get",
    "environ_sizes_get", "environ_get", "clock_time_get", "random_get"].map
    ("wasi_snapshot_preview1", ·))

/-- What the page's loader uses, with its kind: the memory + six functions. -/
def requiredExports : List (String × Nat) :=
  [("memory", 2)] ++ (["_initialize", "fvtrace_init", "fvtrace_alloc", "fvtrace_free",
    "fvtrace_load", "fvtrace_answer"].map (·, 0))

/-- Why the module breaks the link contract (empty = it keeps it). -/
def problems (m : Module) : List String :=
  (m.imports.filter (fun i => i.kind != 0 || !allowedImports.contains (i.module, i.name))).map
    (fun i => s!"imports {i.module}.{i.name} (kind {i.kind}), which the page does not provide") ++
  (requiredExports.filter fun (e, k) => !m.exports.any fun x => x.name == e && x.kind == k).map
    fun (e, k) => s!"exports no {e} of kind {k}"

end FvtraceWasm.Binary
