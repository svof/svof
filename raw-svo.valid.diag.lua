-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

function valid.diagnose_start()
  checkaction(dict.diag.physical)
  if actions.diag_physical then
    lifevision.add(actions.diag_physical.p)
  elseif conf.aillusion then
    setTriggerStayOpen("svo diag", 0)
    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
    insertLink(" (i)", '', 'Ignored this diagnose because we aren\'t actually diagnosing right now (if this is godfeelings, don\'t mind me, then)')
    moveCursorEnd()

    -- necessary since the trigger itself lasts on the next line
    prompttrigger("reset diag", function() sk.diag_list = {} end)
   end
end

function valid.empty_diagnose()
  checkaction(dict.diag.physical)
  if actions.diag_physical then
    lifevision.add(actions.diag_physical.p, nil, nil, 1)
    valid.diagnose_end()
  else
    ignore_illusion("Ignoring this illusion because we weren't diagnosing right now.")
  end
end

local whitelist = {}
whitelist.lovers, whitelist.retardation, whitelist.hoisted = true, true, true
#if skills.metamorphosis then
whitelist.cantvitality = true
#end
#if skills.metamorphosis or skills.shindo or skills.kaido then
whitelist.cantmorph = true
#end

function valid.diagnose_end()
  if sk.diag_list.godfeelings then sk.diag_list = {} setTriggerStayOpen("svo diag", 0) return end

  -- clear ones we don't have
  for affn, afft in pairs(affs) do
    if not sk.diag_list[affn] and not whitelist[affn] then
#if DEBUG_diag then
      debugf("removed %s, don't actually have it.", affn)
#end
      if dict[affn].count then dict[affn].count = 0 end
      removeaff(affn)
    elseif not whitelist[affn] then -- if we do have the aff, remove from diag list, so we don't add it again
      -- but update the current count!
      if type(sk.diag_list[affn]) == "number" and dict[affn].count then
        dict[affn].count = sk.diag_list[affn]
        updateaffcount(dict[affn])
#if DEBUG_diag then
        debugf("%s count updated to %d", affn, dict[affn].count)
#end
      end

      sk.diag_list[affn] = nil
    end
  end

  -- add left over ones
  for j,k in pairs(sk.diag_list) do
#if DEBUG_diag then
    if not dict[j].aff then debugf("svo: invalid %s in diag end", j) end
#end
    -- skip defs
    if defc[j] == nil then
      checkaction(dict[j].aff, true)
      if type(k) == "number" and not dict[j].count then
        for amount = 1, k do lifevision.add(actions[j .. "_aff"].p) end
      elseif type(k) == "number" and dict[j].count then
        lifevision.add(actions[j .. "_aff"].p, nil, k)
      else
        lifevision.add(actions[j .. "_aff"].p)
      end
    end
  end

  affsp = {} -- potential affs
  sk.checkaeony()
  signals.aeony:emit()
  setTriggerStayOpen("svo diag", 0)
  sk.diag_list = {}
end

#for i,j in ipairs({"ablaze", "severeburn", "extremeburn", "charredburn", "meltingburn", "addiction", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "bleeding", "bound", "burning", "claustrophobia", "clumsiness", "mildconcussion", "confusion", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "dementia", "disloyalty", "disrupt", "dissonance", "dizziness", "epilepsy", "fear", "galed", "generosity", "haemophilia", "hallucinations", "healthleech", "heartseed", "hellsight", "hypersomnia", "hypochondria", "icing", "illness", "impale", "impatience", "inlove", "inquisition", "itching", "justice", "laceratedthroat", "lethargy", "loneliness", "lovers", "madness", "mangledleftarm", "mangledleftleg", "mangledrightarm", "mangledrightleg", "masochism", "mildtrauma", "mutilatedleftarm", "mutilatedleftleg", "mutilatedrightarm", "mutilatedrightleg", "pacifism", "paralysis", "paranoia", "peace", "prone", "recklessness", "relapsing", "roped", "selarnia", "sensitivity", "seriousconcussion", "serioustrauma", "shyness", "slashedthroat", "slickness", "stun", "stupidity", "stuttering", "transfixed", "unknownany", "unknowncrippledarm", "unknowncrippledleg", "unknownmental", "vertigo", "voided", "voyria", "weakness", "webbed", "hamstring", "shivering", "frozen", "manaleech", "voyria", "slightfluid", "elevatedfluid", "highfluid", "seriousfluid", "criticalfluid", "godfeelings", "phlogistication", "vitrification", "corrupted", "stain", "rixil", "palpatar", "cadmus", "hecate", "ninkharsag", "spiritdisrupt", "airdisrupt", "firedisrupt", "earthdisrupt", "waterdisrupt", "hoisted", "swellskin", "pinshot", "hypothermia", "scalded", "dehydrated", "timeflux", "numbedleftarm", "numbedrightarm", "unconsciousness", "depression", "parasite"}) do
function valid.diag_$(j)()
  sk.diag_list.$(j) = true

  if not affs.$(j) then
    decho(getDefaultColor().."(new)")
  else
    decho(getDefaultColor().." ("..getStopWatchTime(affs.$(j).sw).."s)")
  end

  if ignore.$(j) then
    decho(getDefaultColor().." (currently ignored)")
  end
end
#end

-- afflictions with a count
#for _, aff in ipairs({"cholerichumour", "melancholichumour", "phlegmatichumour", "sanguinehumour", "bleeding", "skullfractures", "crackedribs", "wristfractures", "torntendons"}) do
function valid.diag_$(aff)(howmuch)
  sk.diag_list.$(aff) = tonumber(howmuch)

  if ignore.$(aff) then
    echo(" (currently ignored)")
  end
end
#end
