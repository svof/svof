-- check keepup, AI
if svo.tntf_set(matches[2], "off", "noerrors") then return end

local aliases = {
  all = "alchemist apostate bard blademaster dragon druid infernal jester magi monk occultist paladin priest runewarden sentinel serpent shaman sylvan",
  allclasses = "alchemist apostate bard blademaster dragon druid infernal jester magi monk occultist paladin priest runewarden sentinel serpent shaman sylvan",
  serp = "serpent",
  necro = "apostate infernal",
  necromancer = "apostate infernal",
}

matches[2] = matches[2]:lower()

-- check aliases
for shortcut, full in pairs(aliases) do
  matches[2] = string.gsub(matches[2], "%f[%a]"..shortcut.."%f[%A]", full)
end

-- check classes
local classes, alreadyoff = {}, {}
for w in string.gmatch(matches[2], "%a+") do
  if svo.classes[w] and svo.enabledclasses[w] then classes[#classes+1] = w -- weed out invalid names
  elseif svo.classes[w] and not svo.enabledclasses[w] then alreadyoff[#alreadyoff+1] = w end
end

for i = 1, #classes do
  svo.disableclass(classes[i])
end

local setsomething = false
if classes[1] then
  svo.echof("Disabled %s class%s.", svo.concatand(classes), (#classes == 1 and '' or 'es'))
  setsomething = true
end
if alreadyoff[1] then
  svo.echof("%s %s already off.", svo.concatand(alreadyoff):title(), (#alreadyoff == 1 and 'is' or 'are'))
  setsomething = true
end

if not setsomething then
  svo.echof("'%s' isn't something you can change.", matches[2])
end

svo.showprompt()