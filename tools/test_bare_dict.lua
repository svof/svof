--[[
Logic-level regression test for the aff handlers of unweavingbody and
crescendo in
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`.

Same approach as tools/test_pyre_ladder.lua: the code under test is extracted
from the real source file by anchor text and executed in a stub environment,
so it is a substring of what ships rather than a reimplementation, and the
test fails loudly if the anchors move instead of silently testing stale logic.

What it covers: both handlers called svo.addaffdict(dict.<name>), and nothing
defines a global `dict` - the file's locals alias svo.sys, svo.affs and the
rest, but not svo.dict. So gaining either affliction from a text trigger or
DIAGNOSE (lifevision runs aff.oncompleted) raised "attempt to index a nil
value (global 'dict')" instead of recording it. The GMCP Add path calls
addaffdict directly and never saw it. The 2018 reference xml has the same
bare reference, so it predates the conversion.

Three things it pins:

  * both real handlers run in an environment with no global `dict`, and add
    their own dictionary entry.
  * the count is published once. Text never sets stacks - only the GMCP Add
    handler does - so a count already above 0 is left alone, and a 0 becomes
    1 once the affliction is recorded (tools/test_counted_floor.lua covers
    that for every counted affliction).
  * no other bare `dict.` or `dict[` reference is left anywhere in the file.

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_bare_dict.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"

local NAMES = {'unweavingbody', 'crescendo'}

local HANDLER_START = "      aff = {\n        oncompleted = function (number)\n"
local HANDLER_END = "\n        end\n      },"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  -- a Windows checkout may have CRLF; the anchors are written with LF
  return (data:gsub("\r\n", "\n"))
end

local source = read_file(SRC)

-- The entry's own aff handler: the first aff block after "    <name> = {".
-- Bounded by the next top-level entry so a missing handler cannot borrow a
-- later entry's.
local function extract_handler(name)
  local entry = "\n    " .. name .. " = {\n"
  local s = source:find(entry, 1, true)
  if not s then
    error("entry anchor for " .. name .. " not found in " .. SRC ..
      " - the entry moved or was reworded; update this test's anchors")
  end
  local next_entry = source:find("\n    [%w_]+ = {\n", s + #entry)
  local h = source:find(HANDLER_START, s, true)
  if not h or (next_entry and h > next_entry) then
    error("aff handler anchor for " .. name .. " not found in its entry - " ..
      "the handler changed shape; update this test's anchors")
  end
  local body_start = h + #HANDLER_START
  local e = source:find(HANDLER_END, body_start, true)
  if not e or (next_entry and e > next_entry) then
    error("end of the aff handler for " .. name .. " not found in its entry")
  end
  return "return function (number)\n" .. source:sub(body_start, e) .. "end"
end

local function load_in(block, chunkname, env)
  -- Mudlet runs Lua 5.1, where only loadstring() takes a source string and
  -- the environment is applied with setfenv. Branch on setfenv rather than on
  -- a version string so this runs under either.
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block, chunkname)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block, chunkname, "t", env)
  end
  if not chunk then error("could not load the extracted handler: " .. tostring(err)) end
  return chunk()
end

local checks, failures = 0, 0
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", desc, tostring(got), tostring(want)))
  end
end

for _, name in ipairs(NAMES) do
  local block = extract_handler(name)
  print(string.format("extracted %d bytes of %s's real aff handler", #block, name))

  for _, start_count in ipairs({0, 4}) do
    local added, published, affs = {}, {}, {}
    local entry = {name = name, count = start_count}
    local svo = {
      dict = {[name] = entry},
      addaffdict = function(what) added[#added + 1] = what; affs[what.name] = {p = what} end,
      updateaffcount = function(what) published[#published + 1] = what end,
    }
    -- No `dict` here, on purpose: the bug was reading one.
    local env = {svo = svo, affs = affs}

    local handler = load_in(block, name .. "_aff_under_test", env)
    local ok, err = pcall(handler)
    local label = string.format("%s from count %d", name, start_count)
    check(label .. " runs without error", ok and true or tostring(err), true)
    check(label .. " adds the affliction once", #added, 1)
    check(label .. " adds its own entry", added[1], entry)
    check(label .. " publishes the count once", #published, 1)
    check(label .. " publishes its own entry", published[1], entry)
    local want = math.max(start_count, 1)
    check(label .. " publishes at least 1", entry.count, want)

    -- With a number, as the fracture-style simple functions pass one: still
    -- ignored, since text never sets stacks.
    added, published = {}, {}
    ok, err = pcall(handler, 3)
    check(label .. " with a number runs without error", ok and true or tostring(err), true)
    check(label .. " with a number leaves the count alone", entry.count, want)
  end
end

-- The rest of the file: any `dict.` or `dict[` not preceded by a dot or an
-- identifier character reads a global nothing defines.
local line_no = 0
local bare = 0
for line in (source .. "\n"):gmatch("([^\n]*)\n") do
  line_no = line_no + 1
  local code = line:gsub("%-%-.*$", "")
  if ("\n" .. code):find("[^%.%w_]dict[%.%[]") then
    bare = bare + 1
    print(string.format("bare dict reference at line %d: %s", line_no, line))
  end
end
check("bare dict references in the file", bare, 0)

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
