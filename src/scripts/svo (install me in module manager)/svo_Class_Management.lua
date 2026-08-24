--[[ start of a class management (tn class/tn classonly) + class-specifics tricks ]]

svo.classes = {
  air          = {fighting = false, skills = {"duress"}},
  alchemist    = {fighting = false, skills = {"transmutation", "physiology", "alchemy"}},
  apostate     = {fighting = false, skills = {"evileye", "necromancy", "apostasy"}},
  bard         = {fighting = false, skills = {"voicecraft", "swashbuckling", "harmonics"}},
  blademaster  = {fighting = false, skills = {"twoarts", "striking", "shindo"}},
  depthswalker = {fighting = false, skills = {"shadowmancy", "aeonics", "terminus"}},
  dragon       = {fighting = false, skills = {"dragoncraft"}},
  druid        = {fighting = false, skills = {"groves", "metamorphosis", "concoctions"}},
  earth        = {fighting = false, skills = {"sculpting"}},
  fire         = {fighting = false, skills = {"ignition"}},
  infernal     = {fighting = false, skills = {"oppression", "malignity", "weaponmastery"}},
  jester       = {fighting = false, skills = {"tarot", "pranks", "puppetry"}},
  magi         = {fighting = false, skills = {"elementalism", "crystalism", "enchantment"}},
  monk         = {fighting = false, skills = {"tekura", "kaido", "telepathy"}},
  occultist    = {fighting = false, skills = {"occultism", "tarot", "domination"}},
  paladin      = {fighting = false, skills = {"valour", "excision", "weaponmastery"}},
  pariah       = {fighting = false, skills = {"memorium", "pestilence", "charnel"}},
  priest       = {fighting = false, skills = {"spirituality", "devotion", "zeal"}},
  psion        = {fighting = false, skills = {"weaving", "psionics", "emulation"}},
  runewarden   = {fighting = false, skills = {"runelore", "discipline", "weaponmastery"}},
  sentinel     = {fighting = false, skills = {"metamorphosis", "woodlore", "concoctions"}},
  serpent      = {fighting = false, skills = {"subterfuge", "venom", "hypnosis"}},
  shaman       = {fighting = false, skills = {"spiritlore", "curses", "vodun"}},
  sylvan       = {fighting = false, skills = {"elementalism", "groves", "concoctions"}},
  unnamable    = {fighting = false, skills = {"anathema", "dominion", "weaponmastery"}},
  water        = {fighting = false, skills = {"pervasion"}},
}
-- keeps track of what skills are actually enabled
svo.enabledskills, svo.enabledclasses = svo.enabledskills or {}, svo.enabledclasses or {}

-- this is used before we're actually sure that we're fighting a class and not illusions
svo.maybefighting = svo.maybefighting or {}

function svo.enableclass(class)
  if not svo.classes[class] or svo.enabledclasses[class] then return end

  for i = 1, #svo.classes[class].skills do
    local skill = svo.classes[class].skills[i]

    svo.enabledskills[skill] = (svo.enabledskills[skill] or 0) + 1
  end

  svo.enabledclasses[class] = true
  raiseEvent("svo enabled class", class)
end

function svo.disableclass(class)
  if not svo.classes[class] or not svo.enabledclasses[class] then return end

  for i = 1, #svo.classes[class].skills do
    local skill = svo.classes[class].skills[i]

    svo.enabledskills[skill] = (svo.enabledskills[skill] or 0) - 1
    if svo.enabledskills[skill] <= 0 then svo.enabledskills[skill] = nil end
  end

  svo.enabledclasses[class] = nil
  raiseEvent("svo disabled class", class)
end

function svo.enableallclasses()
  for class in pairs(svo.classes) do
    svo.enableclass(class)
  end
end

function svo.disableallclasses()
  for class in pairs(svo.classes) do
    svo.disableclass(class)
  end
end

-- once a class is enabled, maybefighting shouldn't be added, but the timer renewed
function svo.startedfighting(class, name)
  svo.valid.gothit(class, name) -- check for **ILLUSION**s
end