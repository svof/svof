--[[
Test that every affliction svof can show on the prompt has a short tag.

The @affs prompt tag (and its older name, @paracelsus_affs_customtag) shows
each affliction in svo.affl by its dictionary entry's prompttag, read in
`src/scripts/svo (core)/svo Utilities/Custom prompt tags/@affs.lua`. An
affliction with no prompttag shows its whole name instead, so an affliction added
to the dictionary without one still works, but makes the prompt longer, and
nothing caught it: 28 afflictions had no tag, and three tags sat under names
svof doesn't use (asleep, impaled and nausea), so sleep, impale and illness
never got theirs. The tags lived in a table of their own in @affs.lua then;
they are on the entries now, so a tag can't outlive its entry.

It runs svof's real loaders through tools/svof_world.lua for every class svof
knows, and checks:

  * every dictionary entry with an aff block has a prompttag, except the entries
    in NOT_SHOWN, whose aff block never adds the entry itself to svo.affl
  * only affliction entries have one
  * no two afflictions share a tag
  * the real tag function shows an affliction by its prompttag, a counted one
    with its count, and one with no prompttag by its name

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

-- every affliction in every class, and the tags on the entries
local world = dofile("tools/svof_world.lua")
local classes = {}
do
  local w = world.new({ class = "Infernal" })
  for class in pairs(w.svo.knownskills) do classes[#classes + 1] = class end
  table.sort(classes)
end
local affs, tagged = {}, {}
for _, class in ipairs(classes) do
  local w = world.new({ class = class })
  local by_tag = {}
  for name, entry in pairs(w.svo.dict) do
    if type(entry) == "table" and type(entry.aff) == "table" then affs[name] = true end
    if type(entry) == "table" and entry.prompttag ~= nil then
      tagged[name] = true
      check(name .. "'s prompttag is a string", type(entry.prompttag) == "string")
      check(name .. " has a prompttag, and isn't an affliction", type(entry.aff) == "table")
      check(name .. " is never shown, and has a prompttag", not NOT_SHOWN[name])
      -- unknownany and unknownmental both show as ?, and blackout as nothing
      local tag = entry.prompttag
      if tag ~= "?" and tag ~= "" then
        check(string.format("%s: %s and %s share the tag %s", class, tostring(by_tag[tag]), name, tag), by_tag[tag] == nil)
        by_tag[tag] = name
      end
    end
    if type(entry) == "table" and type(entry.aff) == "table" and not NOT_SHOWN[name] then
      check(class .. ": " .. name .. " has a prompt tag", entry.prompttag ~= nil)
    end
  end
end

local names = {}
for name in pairs(affs) do names[#names + 1] = name end
table.sort(names)
for name in pairs(NOT_SHOWN) do check(name .. " in NOT_SHOWN is an entry", affs[name] ~= nil) end

-- the tag function itself, from the shipped file
do
  local w = world.new()
  local svo = w.svo
  w.run(read_file(AFFS), "@affs")
  local tagfn = w.env.paracelsus_affs_customtag2
  check("@affs defines paracelsus_affs_customtag2", type(tagfn) == "function")
  check("and has no table of its own", not read_file(AFFS):find("aff_abbrev", 1, true))
  if type(tagfn) == "function" then
    check("nothing to show is an empty tag", tagfn() == "")
    svo.addaffdict(svo.dict.asthma)
    check("asthma shows as ast (" .. tagfn() .. ")", tagfn() == "<IndianRed>[ast]")
    svo.rmaff("asthma")
    svo.addaffdict(svo.dict.skullfractures)
    svo.dict.skullfractures.count = 2
    svo.updateaffcount(svo.dict.skullfractures)
    check("skullfractures at 2 shows as sf(2) (" .. tagfn() .. ")", tagfn() == "<IndianRed>[sf(2)]")
    svo.rmaff("skullfractures")
    svo.dict.madeup = { aff = {} }
    svo.affl.madeup = { p = svo.dict.madeup }
    check("an affliction with no prompttag shows by its name (" .. tagfn() .. ")", tagfn() == "<IndianRed>[madeup]")
  end
  -- the two registrations, and that they call it
  local defined = {}
  for _, h in ipairs(w.handlers) do
    if h.name == "svo system loaded" then
      local saved = svo.adddefinition
      svo.adddefinition = function(tag, code) defined[tag] = code end
      h.f()
      svo.adddefinition = saved
    end
  end
  check("@affs is registered", defined["@affs"] == "paracelsus_affs_customtag2()")
  check("and @paracelsus_affs_customtag", defined["@paracelsus_affs_customtag"] == "paracelsus_affs_customtag2()")
end

local ntags = 0
for _ in pairs(tagged) do ntags = ntags + 1 end
print(string.format("%d afflictions in %d classes, %d tags", #names, #classes, ntags))
print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
