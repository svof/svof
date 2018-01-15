-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

function svo.valid.diagnose_start()
  svo.checkaction(svo.dict.diag.physical)
  if svo.actions.diag_physical then
    svo.lifevision.add(svo.actions.diag_physical.p)
  elseif svo.conf.aillusion then
    setTriggerStayOpen("svo diag", 0)
    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
    insertLink(" (i)", '', 'Ignored this diagnose because we aren\'t actually diagnosing right now (if this is godfeelings, don\'t mind me, then)')
    moveCursorEnd()

    -- necessary since the trigger itself lasts on the next line
    svo.prompttrigger("reset diag", function() svo.sk.diag_list = {} end)
   end
end

function svo.valid.empty_diagnose()
  svo.checkaction(svo.dict.diag.physical)
  if svo.actions.diag_physical then
    svo.lifevision.add(svo.actions.diag_physical.p, nil, nil, 1)
    svo.valid.diagnose_end()
  else
    svo.ignore_illusion("Ignoring this illusion because we weren't diagnosing right now.")
  end
end

local whitelist = {}
whitelist.lovers, whitelist.retardation, whitelist.hoisted, whitelist.paradox = true, true, true, true
if svo.haveskillset('metamorphosis') then
  whitelist.cantvitality = true
end
if svo.haveskillset('metamorphosis') or svo.haveskillset('shindo') or svo.haveskillset('kaido') then
  whitelist.cantmorph = true
end

function svo.valid.diagnose_end()
  if svo.sk.diag_list.godfeelings then svo.sk.diag_list = {} setTriggerStayOpen("svo diag", 0) return end

  -- clear ones we don't have
  for affn, _ in pairs(svo.affs) do
    if not svo.sk.diag_list[affn] and not whitelist[affn] then
      svo.debugf("removed %s, don't actually have it.", affn)
      if svo.dict[affn].count then svo.dict[affn].count = 0 end
      svo.rmaff(affn)
    elseif not whitelist[affn] then -- if we do have the aff, remove from diag list, so we don't add it again
      -- but update the current count!
      if type(svo.sk.diag_list[affn]) == "number" and svo.dict[affn].count then
        svo.dict[affn].count = svo.sk.diag_list[affn]
        svo.updateaffcount(svo.dict[affn])
        svo.debugf("%s count updated to %d", affn, svo.dict[affn].count)
      end

      svo.sk.diag_list[affn] = nil
    end
  end

  -- add left over ones
  for j,k in pairs(svo.sk.diag_list) do
    if not svo.dict[j].aff then svo.debugf("svo: invalid %s in diag end", j) end
    -- skip defs
    if svo.defc[j] == nil then
      svo.checkaction(svo.dict[j].aff, true)
      if type(k) == "number" and not svo.dict[j].count then
        for _ = 1, k do svo.lifevision.add(svo.actions[j .. "_aff"].p) end
      elseif type(k) == "number" and svo.dict[j].count then
        svo.lifevision.add(svo.actions[j .. "_aff"].p, nil, k)
      else
        svo.lifevision.add(svo.actions[j .. "_aff"].p)
      end
    end
  end

  svo.affsp = {} -- potential affs
  svo.sk.checkaeony()
  svo.signals.aeony:emit()
  setTriggerStayOpen("svo diag", 0)
  svo.sk.diag_list = {}
end

for _,affname in ipairs({"ablaze", "severeburn", "extremeburn", "charredburn", "meltingburn", "addiction", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "bleeding", "bound", "burning", "claustrophobia", "clumsiness", "mildconcussion", "confusion", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "dementia", "disloyalty", "disrupt", "dissonance", "dizziness", "epilepsy", "fear", "galed", "generosity", "haemophilia", "hallucinations", "healthleech", "heartseed", "hellsight", "hypersomnia", "hypochondria", "icing", "illness", "impale", "impatience", "inlove", "inquisition", "itching", "justice", "laceratedthroat", "lethargy", "loneliness", "lovers", "madness", "mangledleftarm", "mangledleftleg", "mangledrightarm", "mangledrightleg", "masochism", "mildtrauma", "mutilatedleftarm", "mutilatedleftleg", "mutilatedrightarm", "mutilatedrightleg", "pacifism", "paralysis", "paranoia", "peace", "prone", "recklessness", "relapsing", "roped", "selarnia", "sensitivity", "seriousconcussion", "serioustrauma", "shyness", "slashedthroat", "slickness", "stun", "stupidity", "stuttering", "transfixed", "unknownany", "unknowncrippledarm", "unknowncrippledleg", "unknownmental", "vertigo", "voided", "voyria", "weakness", "webbed", "hamstring", "shivering", "frozen", "manaleech", "voyria", "slightfluid", "elevatedfluid", "highfluid", "seriousfluid", "criticalfluid", "godfeelings", "phlogistication", "vitrification", "corrupted", "stain", "rixil", "palpatar", "cadmus", "hecate", "ninkharsag", "spiritdisrupt", "airdisrupt", "firedisrupt", "earthdisrupt", "waterdisrupt", "hoisted", "swellskin", "pinshot", "hypothermia", "scalded", "dehydrated", "timeflux", "numbedleftarm", "numbedrightarm", "unconsciousness", "depression", "parasite", "retribution", "shadowmadness", "timeloop", "degenerate", "deteriorate", "hatred"}) do
  svo.valid["diag_"..affname] = function()
    svo.sk.diag_list[affname] = true

    if not svo.affs[affname] then
      decho(svo.getDefaultColor().."(new)")
    else
      decho(svo.getDefaultColor().." ("..getStopWatchTime(svo.affs[affname].sw).."s)")
    end

    if svo.ignore[affname] then
      decho(svo.getDefaultColor().." (currently ignored)")
    end
  end
end

-- afflictions with a count
for _, aff in ipairs({"cholerichumour", "melancholichumour", "phlegmatichumour", "sanguinehumour", "bleeding", "skullfractures", "crackedribs", "wristfractures", "torntendons"}) do
  svo.valid['diag_'..aff] = function(howmuch)
    svo.sk.diag_list[aff] = tonumber(howmuch)

    if svo.ignore[aff] then
      echo(" (currently ignored)")
    end
  end
end
