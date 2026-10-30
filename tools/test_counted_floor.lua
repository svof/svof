--[[
Logic-level regression test for the aff handlers of the counted afflictions in
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`.

Same approach as tools/test_bare_dict.lua: each handler is extracted from the
real source file by anchor text and executed in a stub environment, so it is a
substring of what ships rather than a reimplementation, and the test fails
loudly if the anchors move instead of silently testing stale logic.

What it covers: GMCP reports a counted affliction at level 1 when it is
gained, and the GMCP Add handler copies that level into the count. The gain
line and DIAGNOSE give no level, and run aff.oncompleted with none, so a
counted affliction only text reported (blackout, or GMCP off) used to keep a
count of 0, which the @affs prompt tag showed as pressure(0). Each handler now
raises a count of 0 to 1 once the affliction is recorded.

Four things it pins:

  * each of the 15 handlers records its affliction at count 1 from 0, and
    publishes that once.
  * a level GMCP already set is kept.
  * an add GMCP refused, which records nothing, leaves the count at 0.
  * every entry in the file with a count field either has the floor or is
    listed in OWN_AMOUNT with the reason it sets its own count, so a new
    counted affliction can't be added without deciding.

A control strips the floor from one real handler and expects the count to
stay at 0, so the checks above can't pass without the floor doing the work.

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_counted_floor.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"

local FLOORED = {
  'skullfractures', 'crackedribs', 'wristfractures', 'torntendons',
  'pressure', 'horror', 'pyre', 'crescendo',
  'cholerichumour', 'melancholichumour', 'phlegmatichumour', 'sanguinehumour',
  'unweavingbody', 'unweavingmind', 'unweavingspirit',
}

-- Counted entries whose aff handler sets the count itself, so the floor
-- doesn't apply
local OWN_AMOUNT = {
  bleeding = "adds the amount it's given, or 200",
  paradox = "sets 5",
  unknownany = "adds from 1",
  unknownmental = "adds from 1",
  unknowncrippledlimb = "adds from 1",
  unknowncrippledarm = "adds from 1",
  unknowncrippledleg = "adds from 1",
  unknowncure = "adds from 1",
}

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
    -- horror's entry is indented two spaces short
    entry = "\n  " .. name .. " = {\n"
    s = source:find(entry, 1, true)
  end
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

-- Runs a handler from count start. refuse: addaffdict records nothing, as
-- when the GMCP gate refuses the add. Returns the count and how many times
-- it was published.
local function run(block, name, start, refuse)
  local affs, published = {}, 0
  local entry = {name = name, count = start}
  local svo = {
    dict = {[name] = entry},
    addaffdict = function(what) if not refuse then affs[what.name] = {p = what} end end,
    updateaffcount = function() published = published + 1 end,
  }
  local handler = load_in(block, name .. "_aff_under_test", {svo = svo, affs = affs})
  local ok, err = pcall(handler)
  if not ok then return "error: " .. tostring(err), published end
  return entry.count, published
end

for _, name in ipairs(FLOORED) do
  local block = extract_handler(name)
  local count, published = run(block, name, 0)
  check(name .. " gained by text is recorded at count 1", count, 1)
  check(name .. " publishes the count once", published, 1)
  check(name .. " keeps a level GMCP set", (run(block, name, 3)), 3)
  check(name .. " refused stays at 0", (run(block, name, 0, true)), 0)
end

-- The control: the same handler with the floor taken out keeps 0, so the
-- checks above depend on the floor.
local stripped, n = extract_handler('pressure'):gsub("\n%s*if affs%.pressure and [^\n]*", "")
check("the control found the floor to take out", n, 1)
check("control: pressure without the floor stays at 0", (run(stripped, 'pressure', 0)), 0)

-- Every entry with a count field is floored or sets its own count.
local floored, seen = {}, {}
for _, name in ipairs(FLOORED) do floored[name] = true end
-- An entry starts with "<name> = {" alone on a line, indented two or four
-- spaces (horror's is two), and its count field is six in, though not always
-- its first field
local current
for line in (source .. "\n"):gmatch("([^\n]*)\n") do
  local name = line:match("^  ([%w_]+) = {$") or line:match("^    ([%w_]+) = {$")
  if name then current = name
  elseif line == "      count = 0," and current then seen[current] = true end
end
for name in pairs(seen) do
  if not floored[name] and not OWN_AMOUNT[name] then
    check(name .. " has a count but neither the floor nor its own amount", false, true)
  end
end
for _, name in ipairs(FLOORED) do check(name .. " is a counted entry", seen[name], true) end
for name in pairs(OWN_AMOUNT) do check(name .. " is a counted entry", seen[name], true) end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
