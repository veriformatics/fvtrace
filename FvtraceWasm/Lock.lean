/-!
# `tools/wasm.lock`: the pinned inputs of the page engine build

One line per input: `name version key sha256 url`. `emsdk`: key = platform, sha256 of the
release archive. `lean-runtime` + `libuv`: key = commit, sha256 of the manifest of the fetched
files (`manifest`). `tools/pin-wasm.sh` writes every line.
-/

namespace FvtraceWasm.Lock

structure Entry where
  name : String
  version : String
  key : String
  sha256 : String
  url : String
  deriving Repr, BEq, Inhabited

def isHex (n : Nat) (s : String) : Bool :=
  s.length == n && s.all fun c => c.isDigit || ('a' ≤ c && c ≤ 'f')

def parseLine (line : String) : Except String (Option Entry) := do
  let t := line.trimAscii.toString
  if t.isEmpty || t.startsWith "#" then return none
  match (t.splitOn " ").filter (!·.isEmpty) with
  | [name, version, key, sha256, url] =>
    unless isHex 64 sha256 do throw s!"{name} {key}: \"{sha256}\" is not a sha256 digest"
    unless url.startsWith "https://" do throw s!"{name} {key}: \"{url}\" is not an https URL"
    return some { name, version, key, sha256, url }
  | _ => throw s!"a lock line reads `name version key sha256 url`, got \"{t}\""

def parse (text : String) : Except String (List Entry) := do
  let mut out := []
  for line in text.splitOn "\n" do
    if let some e ← parseLine line then out := out ++ [e]
  return out

/-- The single entry named `name` (with key `key`, when given). -/
def find (es : List Entry) (name : String) (key : Option String := none) : Except String Entry :=
  match es.filter fun e => e.name == name && key.all (· == e.key) with
  | [e] => .ok e
  | [] => .error s!"tools/wasm.lock has no {name}{(key.map (" " ++ ·)).getD ""} line"
  | _ => .error s!"tools/wasm.lock has more than one {name}{(key.map (" " ++ ·)).getD ""} line"

/-- The lock's platform key for an LLVM target triple (`System.Platform.target`). -/
def platform (target : String) : Except String String := do
  let arch ← match (target.splitOn "-").head? with
    | some "x86_64" => pure "x86_64"
    | some "aarch64" | some "arm64" => pure "aarch64"
    | _ => throw s!"no pinned Emscripten for the processor of {target}"
  let os ← if (target.splitOn "linux").length > 1 then pure "linux"
    else if (target.splitOn "darwin").length > 1 then pure "darwin"
    else if (target.splitOn "windows").length > 1 || (target.splitOn "mingw").length > 1 then
      pure "windows"
    else throw s!"no pinned Emscripten for the system of {target}"
  return s!"{os}-{arch}"

/-- `sha256sum` output for (relative path, digest) pairs: sorted by path, two spaces, `\n`
after each line. Its sha256 pins a fetched tree (`sha256sum` + `sort` reproduce it). -/
def manifest (files : List (String × String)) : String :=
  String.join ((files.mergeSort fun a b => a.1 ≤ b.1).map fun (p, d) => s!"{d}  {p}\n")

end FvtraceWasm.Lock
