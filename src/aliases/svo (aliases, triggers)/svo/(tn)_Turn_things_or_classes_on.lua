-- check keepup, AI
if svo.tntf_set(matches[2], "on", "noerrors") then return end

local aliases = {
  all = "alchemist apostate bard blademaster dragon druid infernal jester magi monk occultist paladin priest runewarden sentinel serpent shaman sylvan",
  allclasses = "alchemist apostate bard blademaster dragon druid infernal jester magi monk occultist paladin priest runewarden sentinel serpent shaman sylvan",
  serp = "serpent",
  necro = "apostate infernal",
  necromancer = "apostate infernal",
}

matches[2] = matches[2]:lower()

local only
if matches[2]:find("^%w+only") then
  svo.disableallclasses()
  matches[2] = matches[2]:match("^(%w+)only")
  only = true
end

-- check aliases
for shortcut, full in pairs(aliases) do
  matches[2] = string.gsub(matches[2], "%f[%a]"..shortcut.."%f[%A]", full)
end

-- check classes
local classes, alreadyon = {}, {}
for w in string.gmatch(matches[2], "%a+") do
  if svo.classes[w] and not svo.enabledclasses[w] then classes[#classes+1] = w -- weed out invalid names
  elseif svo.classes[w] and svo.enabledclasses[w] then alreadyon[#alreadyon+1] = w end
end

for i = 1, #classes do
  svo.enableclass(classes[i])
end

local setsomething = false
if classes[1] then
  svo.echof("Enabled %s %sclass%s.", svo.concatand(classes), (not only and '' or "only the "), (#classes == 1 and '' or 'es'))
  setsomething = true
end
if alreadyon[1] then
  svo.echof("%s %s already on.", svo.concatand(alreadyon):title(), (#alreadyon == 1 and 'is' or 'are'))
  setsomething = true
end

if not setsomething then
  svo.echof("'%s' isn't something you can change.", matches[2])
end

svo.showprompt()