-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local conf, me = svo.conf, svo.me
local stats = svo.stats
local valid, actions = svo.valid, svo.actions
local lifevision = svo.lifevision

do
  local afflist = {'ablaze', 'severeburn', 'extremeburn', 'charredburn', 'meltingburn', 'addiction', 'aeon', 'agoraphobia', 'anorexia', 'asthma', 'blackout', 'bleeding', 'bound', 'burning', 'claustrophobia', 'clumsiness', 'mildconcussion', 'confusion', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'darkshade', 'deadening', 'dementia', 'disloyalty', 'disrupt', 'dissonance', 'dizziness', 'epilepsy', 'fear', 'galed', 'generosity', 'haemophilia', 'hallucinations', 'healthleech', 'heartseed', 'hellsight', 'hypersomnia', 'hypochondria', 'icing', 'illness', 'impale', 'impatience', 'inlove', 'inquisition', 'itching', 'justice', 'laceratedthroat', 'lethargy', 'loneliness', 'lovers', 'madness', 'mangledleftarm', 'mangledleftleg', 'mangledrightarm', 'mangledrightleg', 'masochism', 'mildtrauma', 'mutilatedleftarm', 'mutilatedleftleg', 'mutilatedrightarm', 'mutilatedrightleg', 'pacifism', 'paralysis', 'paranoia', 'peace', 'prone', 'recklessness', 'relapsing', 'roped', 'selarnia', 'sensitivity', 'seriousconcussion', 'serioustrauma', 'shyness', 'slashedthroat', 'slickness', 'stun', 'stupidity', 'stuttering', 'transfixed', 'unknownany', 'unknowncrippledarm', 'unknowncrippledleg', 'unknownmental', 'vertigo', 'voided', 'voyria', 'weakness', 'webbed', 'hamstring', 'shivering', 'frozen', 'blindaff', 'deafaff', 'retardation', 'manaleech', 'sleep', 'amnesia', 'unknowncrippledlimb', 'cholerichumour', 'melancholichumour', 'phlegmatichumour', 'sanguinehumour', 'phlogistication', 'vitrification', 'corrupted', 'stain', 'rixil', 'palpatar', 'cadmus', 'hecate', 'ninkharsag', 'spiritdisrupt', 'airdisrupt', 'firedisrupt', 'earthdisrupt', 'waterdisrupt', 'swellskin', 'pinshot', 'hypothermia', 'scalded', 'dehydrated', 'timeflux', 'lullaby', 'numbedleftarm', 'numbedrightarm', 'unconsciousness', 'depression', 'parasite', 'retribution', 'shadowmadness', 'timeloop', 'degenerate', 'deteriorate', 'hatred'}
  if svo.haveskillset('metamorphosis') then
    afflist[#afflist+1] = 'cantmorph'
  end

  for _,j in ipairs(afflist) do
    valid['simple' .. j] = function ()
      svo.checkaction(svo.dict[j].aff, true)
      lifevision.add(actions[j .. '_aff'].p)
    end
  end
end

svo.valid.simplehoisted = function(name)
  svo.assert(name)

  if (conf.autowrithe == 'white' and me.hoistlist[name]) or (conf.autowrithe == 'black' and not me.hoistlist[name]) then return end

  svo.checkaction(svo.dict.hoisted.aff, true)
  lifevision.add(actions.hoisted_aff.p)
end

svo.valid.simpleprone = function ()
  svo.checkaction(svo.dict.prone.aff, true)
  lifevision.add(actions.prone_aff.p)

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine()
    fg(conf.hinderpausecolour)
    resetFormat()
    deselect()
  end
end

svo.valid.simplewebbed = function ()
  svo.checkaction(svo.dict.webbed.aff, true)
  lifevision.add(actions.webbed_aff.p)

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine()
    fg(conf.hinderpausecolour)
    resetFormat()
    deselect()
  end
end

svo.valid.simpleblackout = function()
  svo.checkaction(svo.dict.blackout.aff, true)
  -- add it first, before others - so stun checking doesn't delay blackout
  lifevision.addcust(actions.blackout_aff.p, 1)
end

svo.valid.simplebleeding = function (amount)
  if not conf.preclot then return end

  svo.checkaction(svo.dict.bleeding.aff, true)
  if lifevision.l.bleeding_aff then
    lifevision.add(actions.bleeding_aff.p, nil, svo.dict.bleeding.count + (amount or 200) + (lifevision.l.bleeding_aff.arg or 0))
  else
    lifevision.add(actions.bleeding_aff.p, nil, svo.dict.bleeding.count + (amount or 200))
  end
end

svo.valid.simplelovers = function (name)
  svo.assert(name)

  if (conf.autoreject == 'white' and me.lustlist[name]) or (conf.autoreject == 'black' and not me.lustlist[name]) then return end

  svo.checkaction(svo.dict.lovers.aff, true)
  svo.dict.lovers.tempmap[#svo.dict.lovers.tempmap+1] = name -- hack to allow multiple names on ALLIES
  lifevision.add(actions.lovers_aff.p, nil)
end

svo.valid.simpleunknowncrippledleg = function (number)
  svo.assert(not number or tonumber(number), "svo.valid.simpleunknowncrippledleg: how many affs do you want to add? Must be a number")

  svo.checkaction(svo.dict.unknowncrippledleg.aff, true)

  if lifevision.l.unknowncrippledleg_aff then
    lifevision.add(actions.unknowncrippledleg_aff.p, nil, (number or 1) + (lifevision.l.unknowncrippledleg_aff.arg or 1))
  else
    lifevision.add(actions.unknowncrippledleg_aff.p, nil, (number or 1))
  end
end

svo.valid.simpleunknowncrippledarm = function (number)
  svo.assert(not number or tonumber(number), "svo.valid.simpleunknowncrippledarm: how many affs do you want to add? Must be a number")

  svo.checkaction(svo.dict.unknowncrippledarm.aff, true)

  if lifevision.l.unknowncrippledarm_aff then
    lifevision.add(actions.unknowncrippledarm_aff.p, nil, (number or 1) + (lifevision.l.unknowncrippledarm_aff.arg or 1))
  else
    lifevision.add(actions.unknowncrippledarm_aff.p, nil, (number or 1))
  end
end

svo.valid.simpleunknowncrippledlimb = function (number)
  svo.assert(not number or tonumber(number), "svo.valid.simpleunknowncrippledlimb: how many affs do you want to add? Must be a number")

  svo.checkaction(svo.dict.unknowncrippledlimb.aff, true)

  if lifevision.l.unknowncrippledlimb_aff then
    lifevision.add(actions.unknowncrippledlimb_aff.p, nil, (number or 1) +(lifevision.l.unknowncrippledlimb_aff.arg or 1))
  else
    lifevision.add(actions.unknowncrippledlimb_aff.p, nil, (number or 1))
  end
end

svo.valid.simpleunknownany = function (number)
  svo.assert(not number or tonumber(number), "svo.valid.simpleunknownany: how many affs do you want to add? Must be a number")
  if number then svo.assert(number > 0, "svo.valid.simpleunknownany: number must be positive") end

  svo.checkaction(svo.dict.unknownany.aff, true)
  if lifevision.l.unknownany_aff then
    lifevision.add(actions.unknownany_aff.p, nil, (number or 1) +(lifevision.l.unknownany_aff.arg or 1))
  else
    lifevision.add(actions.unknownany_aff.p, nil, (number or 1))
  end

  -- to check if we got reckless!
  if stats.currenthealth ~= stats.maxhealth then
    svo.dict.unknownany.reckhp = true end
  if stats.currentmana ~= stats.maxmana then
    svo.dict.unknownany.reckmana = true end
end

svo.valid.simpleunknownmental = function (number)
  svo.assert(not number or tonumber(number), "svo.valid.simpleunknownany: how many affs do you want to add? Must be a number")
  if number then svo.assert(number > 0, "svo.valid.simpleunknownmental: number must be positive") end

  svo.checkaction(svo.dict.unknownmental.aff, true)
  if lifevision.l.unknownmental_aff then
    lifevision.add(actions.unknownmental_aff.p, nil, (number or 1) +(lifevision.l.unknownmental_aff.arg or 1))
  else
    lifevision.add(actions.unknownmental_aff.p, nil, (number or 1))
  end

  -- to check if we got reckless!
  if stats.currenthealth ~= stats.maxhealth then
    svo.dict.unknownmental.reckhp = true end
  if stats.currentmana ~= stats.maxmana then
    svo.dict.unknownmental.reckmana = true end
end

for _, affname in ipairs({'skullfractures', 'crackedribs', 'wristfractures', 'torntendons'}) do
  valid['simple'..affname] = function (number)
    svo.assert(not number or tonumber(number), "svo.valid.simple"..affname..": how many affs do you want to add? Must be a number")

    svo.checkaction(svo.dict[affname].aff, true)

    if lifevision.l[affname..'_aff'] then
      lifevision.add(actions[affname..'_aff'].p, nil, (number or 1) +(lifevision.l[affname..'_aff'].arg or 1))
    else
      lifevision.add(actions[affname..'_aff'].p, nil, (number or 1))
    end
  end
end

-- historical API compatibility
svo.valid.proper_crippledleftleg = valid.simplecrippledrightleg
svo.valid.proper_crippledrightleg = valid.simplecrippledrightleg
svo.valid.proper_crippledrightarm = valid.simplecrippledrightarm
svo.valid.proper_crippledleftarm = valid.simplecrippledleftarm

if svo.haveskillset('aeonics') then
  valid.simpleage = function(value)
    svo.checkaction(svo.dict.age.happened, true)
    lifevision.add(actions.age_happened.p, nil, tonumber(value))
  end
end
