--[[
lipread's defup skip. Defup doesn't wait for lipread while you can't lip
read: blind, without mindseye to see through it, which is when
svo.dict.lipread's isadvisable won't raise it either. The skip read a global
mindseye, which is always nil, so it always said to skip, and defup finished
without waiting for lipread.

It runs svof's real loaders through tools/svof_world.lua, as a Serpent.

  lua tools/test_lipread.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local w = world.new({ class = "Serpent" })
local svo = w.svo
local skip = svo.defs_data.lipread.specialskip

eq(skip(), false, "not blind: defup waits for lipread")
svo.defc.mindseye = true
eq(skip(), false, "not blind, with mindseye: it waits")
svo.addaffdict(svo.dict.blindaff)
eq(skip(), false, "blind, with mindseye: it waits")
svo.defc.mindseye = false
eq(skip(), true, "blind, without mindseye: it doesn't wait")
svo.rmaff('blindaff')
svo.defc.blind = true
eq(skip(), true, "and the same with the blind defence")
svo.defc.blind = false
eq(w.unknown_globals.mindseye, nil, "and it reads no global mindseye")

-- defup lists lipread as one it waits on
svo.defdefup[svo.defs.mode].lipread = true
local done, waiting = svo.sk.have_defup_defs()
local listed = false
for _, name in ipairs(waiting or {}) do
  if name:match("^lipread") then listed = true end
end
eq(done, false, "defup with lipread on it isn't done while lipread is down")
eq(listed, true, "and says it's waiting on lipread")

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
