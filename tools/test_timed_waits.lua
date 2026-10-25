--[[
Static test of svof's waits for afflictions only time cures, against the
game's own record.

Each such affliction has a waitingfor action whose customwait is how long svof
waits. Where the entry has an ontimeout that removes the affliction, that
time is when svof stops tracking it, unless the expiry line or GMCP takes it
off first. Elsewhere it is how long svof shows it is waiting.

GAME_TIME is AFFLICTION SHOW's "Default time" field (captured 2026-10-21,
claude-notes/reference/affliction_show.lua) for the entries that follow it.
Some entries keep their own time on purpose, and are not listed:

  * hecate waits 22, its comment citing a log where it lasted at least 18
  * blackout waits 60 as a fallback: a normal prompt coming back ends it
  * voided waits 20, its comment saying some stances change it
  * corrupted, palpatar, phlogistication and vitrification wait 999, because
    stacking extends them

Run: lua tools/test_timed_waits.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"

local GAME_TIME = {
  flamefisted = 15,
  galed = 15,       -- the game's airfisted
  icing = 15,       -- icefisted
  pinshot = 21,
  revealed = 60,
  timeflux = 60,
}

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local checks, failures = 0, {}
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: got %s, want %s", desc, tostring(got), tostring(want))
  end
end

local dict = read_file(DICT)

-- the first customwait inside an entry's waitingfor block. revealed sits at
-- two spaces where every other entry has four, so either indent is taken.
local function wait_of(name)
  local s = dict:find("\n    " .. name .. " = {\n", 1, true) or dict:find("\n  " .. name .. " = {\n", 1, true)
  if not s then return nil end
  local block = dict:match("^%s*" .. name .. " = {\n      waitingfor = {\n        customwait = (%d+)", s + 1)
  return block and tonumber(block)
end

for name, seconds in pairs(GAME_TIME) do
  check(name .. "'s wait", wait_of(name), seconds)
end

-- Trigger lines from the same record. Each is an item in a group's
-- triggers.json whose script muddler reads from the file named after it.
local TRIGGERS = "src/triggers/svo (aliases, triggers)/svo/"
local LINES = {
  -- vitrified's Expire msg: without it, only GMCP took vitrification off,
  -- and in blackout it stayed until the next List
  { group = "General", name = "svo vitrification woreoff",
    pattern = "The glass shards embedded in your skin revert to flesh.",
    call = "svo.valid.vitrification_woreoff()" },
}

for _, t in ipairs(LINES) do
  local json = read_file(TRIGGERS .. t.group .. "/triggers.json")
  local s = json:find('"name": "' .. t.name .. '"', 1, true)
  local e = s and json:find('"name": ', s + 1, true) or #json
  check(t.name .. " is in " .. t.group, s ~= nil, true)
  check(t.name .. " matches its line", s and json:sub(s, e):find('"pattern": "' .. t.pattern .. '"', 1, true) ~= nil, true)
  local f = io.open(TRIGGERS .. t.group .. "/" .. t.name:gsub(" ", "_") .. ".lua", "r")
  check(t.name .. " calls " .. t.call, f and f:read("*a"), t.call)
  if f then f:close() end
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
