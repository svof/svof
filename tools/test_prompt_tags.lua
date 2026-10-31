--[[
Test that every affliction svof can show on the prompt has a short tag.

The @affs prompt tag (and its older name, @paracelsus_affs_customtag) shows
each affliction in svo.affl by its entry in aff_abbrev, in
`src/scripts/svo (core)/svo Utilities/Custom prompt tags/@affs.lua`. An
affliction with no entry shows its whole name instead, so an affliction added
to the dictionary without a tag still works, but makes the prompt longer, and
nothing caught it: 28 afflictions had no tag, and three tags sat under names
svof doesn't use (asleep, impaled and nausea), so sleep, impale and illness
never got theirs.

It runs svof's real loaders through tools/svof_world.lua for every class svof
knows, and checks:

  * every dictionary entry with an aff block has a tag, except the entries in
    NOT_SHOWN, whose aff block never adds the entry itself to svo.affl
  * every tag names an affliction, so a renamed one can't leave its tag behind
  * no two afflictions share a tag

Run: lua tools/test_prompt_tags.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local AFFS = "src/scripts/svo (core)/svo Utilities/Custom prompt tags/@affs.lua"

-- entries with an aff block that never add themselves to svo.affl
local NOT_SHOWN = {
  checkanorexia = "adds anorexia",
  checkasthma = "adds asthma",
  checkhypersomnia = "adds hypersomnia",
  checkimpatience = "adds impatience",
  checkparalysis = "adds paralysis",
  checkslows = "adds aeon or retardation",
  checkstun = "adds stun",
  checkwrithes = "adds a writhe",
  insomnia = "its aff block gains the insomnia defence",
}

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local checks, failures = 0, {}
local function check(desc, ok)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc end
end

-- the tags, read from the table itself
local table_src = read_file(AFFS):match("\nlocal aff_abbrev = (%b{})")
check("aff_abbrev is found in " .. AFFS, table_src ~= nil)
local tags = (loadstring or load)("return " .. (table_src or "{}"))()

-- every affliction in every class
local world = dofile("tools/svof_world.lua")
local classes = {}
do
  local w = world.new({ class = "Infernal" })
  for class in pairs(w.svo.knownskills) do classes[#classes + 1] = class end
  table.sort(classes)
end
local affs = {}
for _, class in ipairs(classes) do
  local w = world.new({ class = class })
  for name, entry in pairs(w.svo.dict) do
    if type(entry) == "table" and type(entry.aff) == "table" then affs[name] = true end
  end
end

local names = {}
for name in pairs(affs) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
  if NOT_SHOWN[name] then
    check(name .. " is never shown, so it has no tag", tags[name] == nil)
  else
    check(name .. " has a prompt tag", tags[name] ~= nil)
  end
end
for name in pairs(NOT_SHOWN) do check(name .. " in NOT_SHOWN is an entry", affs[name] ~= nil) end

local by_tag = {}
for name, tag in pairs(tags) do
  check("the tag " .. name .. " names an affliction", affs[name] ~= nil)
  -- unknownany and unknownmental both show as ?, and blackout as nothing
  if tag ~= "?" and tag ~= "" then
    check(string.format("%s and %s share the tag %s", tostring(by_tag[tag]), name, tag), by_tag[tag] == nil)
    by_tag[tag] = name
  end
end

print(string.format("%d afflictions in %d classes, %d tags", #names, #classes, (function() local n = 0 for _ in pairs(tags) do n = n + 1 end return n end)()))
print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
