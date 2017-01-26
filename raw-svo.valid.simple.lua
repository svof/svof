-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

for i,j in ipairs({"ablaze", "severeburn", "extremeburn", "charredburn", "meltingburn", "addiction", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "bleeding", "bound", "burning", "claustrophobia", "clumsiness", "mildconcussion", "confusion", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "dementia", "disloyalty", "disrupt", "dissonance", "dizziness", "epilepsy", "fear", "galed", "generosity", "haemophilia", "hallucinations", "healthleech", "heartseed", "hellsight", "hypersomnia", "hypochondria", "icing", "illness", "impale", "impatience", "inlove", "inquisition", "itching", "justice", "laceratedthroat", "lethargy", "loneliness", "lovers", "madness", "mangledleftarm", "mangledleftleg", "mangledrightarm", "mangledrightleg", "masochism", "mildtrauma", "mutilatedleftarm", "mutilatedleftleg", "mutilatedrightarm", "mutilatedrightleg", "pacifism", "paralysis", "paranoia", "peace", "prone", "recklessness", "relapsing", "roped", "selarnia", "sensitivity", "seriousconcussion", "serioustrauma", "shyness", "slashedthroat", "slickness", "stun", "stupidity", "stuttering", "transfixed", "unknownany", "unknowncrippledarm", "unknowncrippledleg", "unknownmental", "vertigo", "voided", "voyria", "weakness", "webbed", "hamstring", "shivering", "frozen", "blindaff", "deafaff", "retardation", "manaleech", "sleep", "amnesia", "unknowncrippledlimb", "cholerichumour", "melancholichumour", "phlegmatichumour", "sanguinehumour", "phlogistication", "vitrification", "corrupted", "stain", "rixil", "palpatar", "cadmus", "hecate", "ninkharsag", "spiritdisrupt", "airdisrupt", "firedisrupt", "earthdisrupt", "waterdisrupt", "hoisted", "swellskin", "pinshot", "hypothermia", "scalded", "dehydrated", "timeflux", "lullaby", "numbedleftarm", "numbedrightarm", "unconsciousness", "depression", "parasite", "retribution", "shadowmadness", "timeloop", "degenerate", "deteriorate", "hatred",
#if skills.metamorphosis then
  "cantmorph",
#end
}) do
  valid["simple" .. j] = function ()
    checkaction(dict[j].aff, true)
    lifevision.add(actions[j .. "_aff"].p)
  end
end

valid.simpleprone = function ()
  checkaction(dict.prone.aff, true)
  lifevision.add(actions.prone_aff.p)

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine()
    fg(conf.hinderpausecolour)
    resetFormat()
    deselect()
  end
end

valid.simplewebbed = function ()
  checkaction(dict.webbed.aff, true)
  lifevision.add(actions.webbed_aff.p)

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine()
    fg(conf.hinderpausecolour)
    resetFormat()
    deselect()
  end
end

valid.simpleblackout = function()
  checkaction(dict.blackout.aff, true)
  -- add it first, before others - so stun checking doesn't delay blackout
  lifevision.addcust(actions.blackout_aff.p, 1)
end

valid.simplebleeding = function (amount)
  if not conf.preclot then return end

  checkaction(dict.bleeding.aff, true)
  if lifevision.l.bleeding_aff then
    lifevision.add(actions.bleeding_aff.p, nil, dict.bleeding.count + (amount or 200) + (lifevision.l.bleeding_aff.arg or 0))
  else
    lifevision.add(actions.bleeding_aff.p, nil, dict.bleeding.count + (amount or 200))
  end
end

valid.simplelovers = function (name)
  assert(name)

  if (conf.autoreject == "white" and me.lustlist[name]) or (conf.autoreject == "black" and not me.lustlist[name]) then return end

  checkaction(dict.lovers.aff, true)
  dict.lovers.tempmap[#dict.lovers.tempmap+1] = name -- hack to allow multiple names on ALLIES
  lifevision.add(actions.lovers_aff.p, nil)
end

valid.simpleunknowncrippledleg = function (number)
  assert(not number or tonumber(number), "svo.valid.simpleunknowncrippledleg: how many affs do you want to add? Must be a number")

  checkaction(dict.unknowncrippledleg.aff, true)

  if lifevision.l.unknowncrippledleg_aff then
    lifevision.add(actions.unknowncrippledleg_aff.p, nil, (number or 1) + (lifevision.l.unknowncrippledleg_aff.arg or 1))
  else
    lifevision.add(actions.unknowncrippledleg_aff.p, nil, (number or 1))
  end
end

valid.simpleunknowncrippledarm = function (number)
  assert(not number or tonumber(number), "svo.valid.simpleunknowncrippledarm: how many affs do you want to add? Must be a number")

  checkaction(dict.unknowncrippledarm.aff, true)

  if lifevision.l.unknowncrippledarm_aff then
    lifevision.add(actions.unknowncrippledarm_aff.p, nil, (number or 1) + (lifevision.l.unknowncrippledarm_aff.arg or 1))
  else
    lifevision.add(actions.unknowncrippledarm_aff.p, nil, (number or 1))
  end
end

valid.simpleunknowncrippledlimb = function (number)
  assert(not number or tonumber(number), "svo.valid.simpleunknowncrippledlimb: how many affs do you want to add? Must be a number")

  checkaction(dict.unknowncrippledlimb.aff, true)

  if lifevision.l.unknowncrippledlimb_aff then
    lifevision.add(actions.unknowncrippledlimb_aff.p, nil, (number or 1) +(lifevision.l.unknowncrippledlimb_aff.arg or 1))
  else
    lifevision.add(actions.unknowncrippledlimb_aff.p, nil, (number or 1))
  end
end

valid.simpleunknownany = function (number)
  assert(not number or tonumber(number), "svo.valid.simpleunknownany: how many affs do you want to add? Must be a number")
  if number then assert(number > 0, "svo.valid.simpleunknownany: number must be positive") end

  checkaction(dict.unknownany.aff, true)
  if lifevision.l.unknownany_aff then
    lifevision.add(actions.unknownany_aff.p, nil, (number or 1) +(lifevision.l.unknownany_aff.arg or 1))
  else
    lifevision.add(actions.unknownany_aff.p, nil, (number or 1))
  end

  -- to check if we got reckless!
  if stats.currenthealth ~= stats.maxhealth then
    dict.unknownany.reckhp = true end
  if stats.currentmana ~= stats.maxmana then
    dict.unknownany.reckmana = true end
end

valid.simpleunknownmental = function (number)
  assert(not number or tonumber(number), "svo.valid.simpleunknownany: how many affs do you want to add? Must be a number")
  if number then assert(number > 0, "svo.valid.simpleunknownmental: number must be positive") end

  checkaction(dict.unknownmental.aff, true)
  if lifevision.l.unknownmental_aff then
    lifevision.add(actions.unknownmental_aff.p, nil, (number or 1) +(lifevision.l.unknownmental_aff.arg or 1))
  else
    lifevision.add(actions.unknownmental_aff.p, nil, (number or 1))
  end

  -- to check if we got reckless!
  if stats.currenthealth ~= stats.maxhealth then
    dict.unknownmental.reckhp = true end
  if stats.currentmana ~= stats.maxmana then
    dict.unknownmental.reckmana = true end
end

#for _, aff in ipairs({"skullfractures", "crackedribs", "wristfractures", "torntendons"}) do
valid.simple$(aff) = function (number)
  assert(not number or tonumber(number), "svo.valid.simple$(aff): how many affs do you want to add? Must be a number")

  checkaction(dict.$(aff).aff, true)

  if lifevision.l.$(aff)_aff then
    lifevision.add(actions.$(aff)_aff.p, nil, (number or 1) +(lifevision.l.$(aff)_aff.arg or 1))
  else
    lifevision.add(actions.$(aff)_aff.p, nil, (number or 1))
  end
end
#end

-- historical API compatibility
valid.proper_crippledleftleg = simplecrippledrightleg
valid.proper_crippledrightleg = simplecrippledrightleg
valid.proper_crippledrightarm = simplecrippledrightarm
valid.proper_crippledleftarm = simplecrippledleftarm

#if skills.aeonics then
valid.simpleage = function(value)
  checkaction(dict.age.happened, true)
  lifevision.add(actions.age_happened.p, nil, tonumber(value))
end
#end
