-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

--[[
spriority: global async priority. In use when curing in sync mode.
aspriority: inter-balance sync priority. In use when curing in async mode.
isadvisable: determines if it is possible to cure this aff. some things that
  block bals might not block a single aff
]]

$(
function basicdef(which, command, balanceless, gamename, undeffable)
  if type (command) == "string" then
    _put(string.format(which..[[ = {
      ]] .. (gamename and ("gamename = '"..gamename.."',") or "") .. [[
      physical = {
        %s = true,
        aspriority = 0,
        spriority = 0,
        def = true,
        ]] .. (undeffable and ("undeffable = true, ") or "") .. [[

        isadvisable = function ()
          return (not defc.]]..which..[[ and ((sys.deffing and defdefup[defs.mode].]]..which..[[) or (conf.keepup and defkeepup[defs.mode].]]..which..[[)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone%s) or false
        end,

        oncompleted = function ()
          defences.got("]]..which..[[")
        end,

        action = "]]..command..[[",
        onstart = function ()
          send("]]..command..[[", conf.commandecho)
        end
      }
    },]], balanceless and "balanceless_act" or "balanceful_act", not balanceless and "" or " and not doingaction'"..which.."'"))
  else
    _put(string.format(which..[[ = {
      ]] .. (gamename and ("gamename = '"..gamename.."',") or "") .. [[
      physical = {
        %s = true,
        aspriority = 0,
        spriority = 0,
        def = true,
        ]] .. (undeffable and ("undeffable = true, ") or "") .. [[

        isadvisable = function ()
          return (((sys.deffing and defdefup[defs.mode].]]..which..[[ and not defc.]]..which..[[) or (conf.keepup and defkeepup[defs.mode].]]..which..[[ and not defc.]]..which..[[)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone%s) or false
        end,

        oncompleted = function ()
          defences.got("]]..which..[[")
        end,

        onstart = function ()
          %s
        end
      }
    },]], balanceless and "balanceless_act" or "balanceful_act",not balanceless and "" or " and not doingaction'"..which.."'",
      (function(command)
        local t = {}
        for _, cmd in ipairs(command) do
          t[#t+1] = "send('"..cmd.."', conf.commandecho)"
        end
        return table.concat(t, ";")
      end)(command)))
  end
end
)

local dict_balanceful = {}
local dict_balanceless = {}


-- defence shortlists
local dict_balanceful_def = {}
local dict_balanceless_def = {}
local dict_herb = {}
local dict_misc = {}
local dict_misc_def = {}
local dict_purgative = {}
local dict_salve_def = {}
local dict_smoke_def = {}

local codepaste = {}


-- used to check if we're writhing from something already
--impale stacks below other writhes
codepaste.writhe = function()
  return (
    not doingaction("curingtransfixed") and not doingaction("transfixed") and
    not doingaction("curingimpale") and not doingaction("impale") and
    not doingaction("curingbound") and not doingaction("bound") and
    not doingaction("curingwebbed") and not doingaction("webbed") and
    not doingaction("curingroped") and not doingaction("roped") and
    not doingaction("curinghoisted") and not doingaction("hoisted") and
    not doingaction("dragonflex"))
end

-- gives a warning if we're having too many reaves
codepaste.checkreavekill = function()
  -- count up all humours, if three - warn of nearly, if four - warn of reaveability
  local c = 0
  if affs.cholerichumour then c = c + 1 end
  if affs.melancholichumour then c = c + 1 end
  if affs.phlegmatichumour then c = c + 1 end
  if affs.sanguinehumour then c = c + 1 end

  if c == 4 then
    sk.warn "reavable"
  elseif c == 3 then
    sk.warn "nearlyreavable"
  elseif c == 2 then
    sk.warn "somewhatreavable"
  end
end

codepaste.checkdismemberkill = function()
  if not enabledclasses.sentinel then return end

  if affs.bound and affs.impale then
    sk.warn "dismemberable"
  end
end

codepaste.badaeon = function()
  -- if we're in a poor aeon situation, warn to gtfo
  if not affs.aeon then return end

  local c = 0
  if affs.asthma then c = c + 1 end
  if affs.stupidity then c = c + 1 end
  if affs.voided then c = c + 1 end
  if affs.asthma and affs.anorexia then c = c + 1 end

  if c >= 1 then sk.warn "badaeon" end
end

codepaste.addrestobreakleg = function(aff, oldhp, tekura)
  local leg = aff:find("right") and "right" or "left"

  if not conf.aillusion or ((not oldhp or oldhp > stats.currenthealth) or paragraph_length >= 3 or (affs.recklessness and getStopWatchTime(affs[aff].sw) >= conf.ai_restoreckless))
    or (sk.tremoloside and sk.tremoloside[leg]) -- accept it when it was a tremolo hit that set us up for a break as well
  then

    -- clear sk.tremoloside for the leg, so tremolo later on can know when it /didn't/ break a leg
    if sk.tremoloside and sk.tremoloside[leg] then
      sk.tremoloside[leg] = nil
    end

    if not tekura then
      addaff(dict[aff])

    else
      if not sk.delaying_break then
        sk.delaying_break = tempTimer(getNetworkLatency() + conf.tekura_delay, function() -- from the first hit, it's approximately getNetworkLatency() time until the second - add the conf.tekura_delay to allow for variation in ping
          sk.delaying_break = nil

          for _, aff in ipairs(sk.tekura_mangles) do
            addaff(dict[aff])
          end
          sk.tekura_mangles = nil
          make_gnomes_work()
        end)
      end

      sk.tekura_mangles = sk.tekura_mangles or {}
      sk.tekura_mangles[#sk.tekura_mangles+1] = aff
    end
  end
end

codepaste.addrestobreakarm = function(aff, oldhp, tekura)
  if not conf.aillusion or ((not oldhp or oldhp > stats.currenthealth) or paragraph_length >= 3 or (affs.recklessness and getStopWatchTime(affs[aff].sw) >= conf.ai_restoreckless)) then

    if not tekura then
      addaff(dict[aff])
      signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      signals.canoutr:emit()

    else
      if not sk.delaying_break then
        sk.delaying_break = tempTimer(getNetworkLatency() + conf.tekura_delay, function() -- from the first hit, it's approximately getNetworkLatency() time until the second - add the conf.tekura_delay to allow for variation in ping
          sk.delaying_break = nil

          for _, aff in ipairs(sk.tekura_mangles) do
            addaff(dict[aff])
          end
          sk.tekura_mangles = nil

          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          signals.canoutr:emit()

          make_gnomes_work()
        end)
      end

      sk.tekura_mangles = sk.tekura_mangles or {}
      sk.tekura_mangles[#sk.tekura_mangles+1] = aff
    end

  end
end

codepaste.remove_focusable = function ()
  if not affs.unknownmental then return end
  affs.unknownmental.p.count = affs.unknownmental.p.count - 1
  if affs.unknownmental.p.count <= 0 then
    removeaff("unknownmental")
    dict.unknownmental.count = 0
  else
    updateaffcount(dict.unknownmental)
  end
end

-- keep argument is used when the aff is still on you
codepaste.remove_stackableaff = function (aff, keep)
  if not affs[aff] then return end
  dict[aff].count = dict[aff].count - 1

  if keep and dict[aff].count <= 0 then dict[aff].count = 1 end

  if dict[aff].count <= 0 then
    removeaff(aff)
    dict[aff].count = 0
  else
    updateaffcount(dict[aff])
  end
end

-- -> boolean
-- returns true if we're using some non-standard cure - tree, restore, class skill...
codepaste.nonstdcure = function()
  return (doingaction"touchtree" or doingaction"restore"
#if skills.venom then
      or doingaction"shrugging"
#end
#if skills.healing then
      or doingaction"usehealing"
#end
    )
end

#if skills.metamorphosis then
codepaste.nonmorphdefs = function ()
  for _, def in ipairs{"flame", "lyre", "nightsight", "rest", "resistance", "stealth", "temperance", "elusiveness"} do
    if ((sys.deffing and defdefup[defs.mode][def]) or (not sys.deffing and conf.keepup and defkeepup[defs.mode][def])) and not defc[def] then return false end
  end

  -- local def = "vitality"
  -- if ((sys.deffing and defdefup[defs.mode][def]) or (conf.keepup and defkeepup[defs.mode][def])) and not doingaction"cantvitality" then return false end
  return true
end
#end

codepaste.smoke_elm_pipe = function()
  if pipes.elm.id == 0 then sk.warn "noelmid" end
  if not (pipes.elm.lit or pipes.elm.arty) then
    sk.forcelight_elm = true
  end

  return (not (pipes.elm.id == 0) and
    (pipes.elm.lit or pipes.elm.arty) and
    not (pipes.elm.puffs == 0))
end

codepaste.smoke_valerian_pipe = function()
  if pipes.valerian.id == 0 then sk.warn "novalerianid" end
  if not (pipes.valerian.lit or pipes.valerian.arty) then
    sk.forcelight_valerian = true
  end

  return (not (pipes.valerian.id == 0) and
    (pipes.valerian.lit or pipes.valerian.arty) and
    not (pipes.valerian.puffs == 0))
end

codepaste.smoke_skullcap_pipe = function()
  if pipes.skullcap.id == 0 then sk.warn "noskullcapid" end
  if not (pipes.skullcap.lit or pipes.skullcap.arty) then
    sk.forcelight_skullcap = true
  end

  return (not (pipes.skullcap.id == 0) and
    (pipes.skullcap.lit or pipes.skullcap.arty) and
    not (pipes.skullcap.puffs == 0))
end

codepaste.balanceful_defs_codepaste = function()
  for k,v in pairs(dict_balanceful_def) do
    if doingaction(k) then return true end
  end
end

-- adds the unknownany aff or increases the count by 1 or specified amount
codepaste.addunknownany = function(amount)
  local count = dict.unknownany.count
  addaff(dict.unknownany)

  dict.unknownany.count = (count or 0) + (amount or 1)
  updateaffcount(dict.unknownany)
end

sk.burns = {"ablaze", "severeburn", "extremeburn", "charredburn", "meltingburn"}
-- removes all burning afflictions except for the optional specified one
codepaste.remove_burns = function(skipaff)
  local burns = deepcopy(sk.burns)
  if skipaff then
    table.remove(burns, table.index_of(burns, skipaff))
  end

  removeaff(burns)
end

sk.next_burn = function()
  for i,v in ipairs(sk.burns) do
    if affs[v] then return sk.burns[i+1] or sk.burns[#sk.burns] end
  end
end

sk.current_burn = function()
  for i,v in ipairs(sk.burns) do
    if affs[v] then return v end
  end
end

sk.previous_burn = function(howfar)
  for i,v in ipairs(sk.burns) do
    if affs[v] then return sk.burns[i-(howfar and howfar or 1)] or nil end
  end
end

codepaste.serversideahealthmanaprio = function()
  local healhealth_prio = svo.prio.getnumber("healhealth", "sip")
  local healmana_prio   = svo.prio.getnumber("healmana"  , "sip")

  -- swap using curing system commands as appropriate
  -- setup special balance in cache mentioning which is first, so it is remembered
  sk.priochangecache.special = sk.priochangecache.special or { healthormana = ""}

  if healhealth_prio > healmana_prio and sk.priochangecache.special.healthormana ~= "health" then
    sendcuring("priority health")
    sk.priochangecache.special.healthormana = "health"
  elseif healmana_prio > healhealth_prio and sk.priochangecache.special.healthormana ~= "mana" then
    sendcuring("priority mana")
    sk.priochangecache.special.healthormana = "mana"
  end
end

--[[ dict is to NEVER be iterated over fully by prompt checks; so isadvisable functions can
      typically expect not to check for the common things because pre-
      filtering is done.
  ]]

dict = {
  gamename = nil, -- (string) what serverside calls this by - names can be different as they were revealed years after Svof was made
  onservereignore = nil, -- (function) a function which'll return true if this needs to be ignored serverside
  healhealth = {
    description = "heals health with health/vitality or moss/potash",
    sip = {
      name = false, --"healhealth_sip",
      balance = false, --"sip",
      action_name = false, --"healhealth"
      aspriority = 0,
      spriority = 0,

      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
        -- should healhealth be prioritised above health affs, don't apply if above healthaffsabove% and have an aff
        local function shouldntsip()
          local crackedribs    = prio.getnumber("crackedribs", "sip")
          local healhealth     = prio.getnumber("healhealth", "sip")
          local skullfractures = prio.getnumber("skullfractures", "sip")
          local torntendons    = prio.getnumber("torntendons", "sip")
          local wristfractures = prio.getnumber("wristfractures", "sip")

          if stats.hp >= conf.healthaffsabove and ((healhealth > crackedribs and affs.crackedribs) or (healhealth > skullfractures and affs.skullfractures) or (healhealth > torntendons and affs.torntendons) or (healhealth > wristfractures and affs.wristfractures)) then
            return true
          end

          return false
        end

#if not skills.kaido then
        return ((stats.currenthealth < sys.siphealth or (sk.gettingfullstats and stats.currenthealth < stats.maxhealth)) and not actions.healhealth_sip and not shouldntsip())
#else
        return ((stats.currenthealth < sys.siphealth or (sk.gettingfullstats and stats.currenthealth < stats.maxhealth)) and not actions.healhealth_sip  and not shouldntsip() and
          (defc.dragonform or -- sip health if we're in dragonform, can't use Kaido
            not can_usemana() or -- or we don't have enough mana (should be an option). The downside of this is that we won't get mana back via sipping, only moss, the time to being able to transmute will approach slower than straight sipping mana
            (affs.prone and not conf.transsipprone) or -- or we're prone and sipping while prone is off (better for bashing, not so for PK)
            (conf.transmute ~= "replaceall" and conf.transmute ~= "replacehealth" and not doingaction"transmute") -- or we're not in a replacehealth/replaceall mode, so we can still sip
          )
        )
#end
      end,

      oncompleted = function ()
        lostbal_sip()
      end,

      noeffect = function()
        lostbal_sip()
      end,

      onprioswitch = function()
        codepaste.serversideahealthmanaprio()
      end,

      sipcure = {"health", "vitality"},

      onstart = function ()
        sip(dict.healhealth.sip)
      end
    },
    moss = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
#if not skills.kaido then
        return ((stats.currenthealth < sys.mosshealth) and (not doingaction ("healhealth") or (stats.currenthealth < (sys.mosshealth-600)))) or false
#else
        return ((stats.currenthealth < sys.mosshealth) and (not doingaction ("healhealth") or (stats.currenthealth < (sys.mosshealth-600))) and (defc.dragonform or not can_usemana() or affs.prone or (conf.transmute ~= "replaceall" and not doingaction"transmute"))) or false
#end
      end,

      oncompleted = function ()
        lostbal_moss()
      end,

      noeffect = function()
        lostbal_moss()
      end,

      eatcure = {"irid", "potash"},
      actions = {"eat moss", "eat irid", "eat potash"},
      onstart = function ()
        eat(dict.healhealth.moss)
      end
    },
  },
  healmana = {
    description = "heals mana with mana/mentality or moss/potash",
    sip = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
        return ((stats.currentmana < sys.sipmana or (sk.gettingfullstats and stats.currentmana < stats.maxmana)) and not doingaction ("healmana")) or false
      end,

      oncompleted = function ()
        lostbal_sip()
      end,

      noeffect = function()
        lostbal_sip()
      end,

      onprioswitch = function()
        codepaste.serversideahealthmanaprio()
      end,

      sipcure = {"mana", "mentality"},

      onstart = function ()
        sip(dict.healmana.sip)
      end
    },
    moss = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priority lists
      irregular = true,

      isadvisable = function ()
        return ((stats.currentmana < sys.mossmana) and (not doingaction ("healmana") or (stats.currentmana < (sys.mossmana-600)))) or false
      end,

      oncompleted = function ()
        lostbal_moss()
      end,

      noeffect = function()
        lostbal_moss()
      end,

      eatcure = {"irid", "potash"},
      actions = {"eat moss", "eat irid", "eat potash"},
      onstart = function ()
        eat(dict.healmana.moss)
      end
    },
  },
  skullfractures = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.skullfractures and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        lostbal_sip()
        -- two counts are cured if you're above 5
        local howmany = dict.skullfractures.count
        codepaste.remove_stackableaff("skullfractures", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("skullfractures", true)
        end
      end,

      cured = function()
        lostbal_sip()
        removeaff("skullfractures")
        dict.skullfractures.count = 0
      end,

      fizzled = function ()
        lostbal_sip()
        empty.apply_health_head()
      end,

      noeffect = function ()
        lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to head"},
      onstart = function ()
        send("apply health to head", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = dict.skullfractures.count
        addaff(dict.skullfractures)

        dict.skullfractures.count = (count or 0) + (number or 1)
        if dict.skullfractures.count > 7 then
          dict.skullfractures.count = 7
        end
        updateaffcount(dict.skullfractures)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("skullfractures")
        dict.skullfractures.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = dict.skullfractures.count
        for i = 1, (amount or 1) do
          codepaste.remove_stackableaff("skullfractures", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("skullfractures", not dontkeep)
        end
      end,

      general_cured = function(amount)
        removeaff("skullfractures")
        dict.skullfractures.count = 0
      end,
    }
  },
  crackedribs = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crackedribs and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        lostbal_sip()
        -- two counts are cured if you're above 5
        local howmany = dict.crackedribs.count
        codepaste.remove_stackableaff("crackedribs", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("crackedribs", true)
        end
      end,

      cured = function()
        lostbal_sip()
        removeaff("crackedribs")
        dict.crackedribs.count = 0
      end,

      fizzled = function ()
        lostbal_sip()
        empty.apply_health_torso()
      end,

      noeffect = function ()
        lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to torso"},
      onstart = function ()
        send("apply health to torso", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = dict.crackedribs.count
        addaff(dict.crackedribs)

        dict.crackedribs.count = (count or 0) + (number or 1)
        if dict.crackedribs.count > 7 then
          dict.crackedribs.count = 7
        end
        updateaffcount(dict.crackedribs)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("crackedribs")
        dict.crackedribs.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = dict.crackedribs.count
        for i = 1, (amount or 1) do
          codepaste.remove_stackableaff("crackedribs", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("crackedribs", not dontkeep)
        end
      end,

      general_cured = function(amount)
        removeaff("crackedribs")
        dict.crackedribs.count = 0
      end,
    }
  },
  wristfractures = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.wristfractures and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        lostbal_sip()
        -- two counts are cured if you're above 5
        local howmany = dict.wristfractures.count
        codepaste.remove_stackableaff("wristfractures", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("wristfractures", true)
        end
      end,

      cured = function()
        lostbal_sip()
        removeaff("wristfractures")
        dict.wristfractures.count = 0
      end,

      fizzled = function ()
        lostbal_sip()
        empty.apply_health_arms()
      end,

      noeffect = function ()
        lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to arms"},
      onstart = function ()
        send("apply health to arms", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = dict.wristfractures.count
        addaff(dict.wristfractures)

        dict.wristfractures.count = (count or 0) + (number or 1)
        if dict.wristfractures.count > 7 then
          dict.wristfractures.count = 7
        end
        updateaffcount(dict.wristfractures)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("wristfractures")
        dict.wristfractures.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = dict.wristfractures.count
        for i = 1, (amount or 1) do
          codepaste.remove_stackableaff("wristfractures", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("wristfractures", not dontkeep)
        end
      end,

      general_cured = function(amount)
        removeaff("wristfractures")
        dict.wristfractures.count = 0
      end,
    }
  },
  torntendons = {
    count = 0,
    sip = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.torntendons and stats.hp >= conf.healthaffsabove) or false
      end,

      oncompleted = function ()
        lostbal_sip()
                -- two counts are cured if you're above 5
        local howmany = dict.torntendons.count
        codepaste.remove_stackableaff("torntendons", true)
        if howmany > 5 then
          codepaste.remove_stackableaff("torntendons", true)
        end
      end,

      cured = function()
        lostbal_sip()
        removeaff("torntendons")
        dict.torntendons.count = 0
      end,

      fizzled = function ()
        lostbal_sip()
        empty.apply_health_legs()
      end,

      noeffect = function ()
        lostbal_sip()
      end,

      -- in case an unrecognised message is shown, don't error
      empty = function()
      end,

      actions = {"apply health to legs"},
      onstart = function ()
        send("apply health to legs", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (number)
        -- double kngiht affs from precision strikes
        if sk.doubleknightaff then number = (number or 0) + 1 end

        local count = dict.torntendons.count
        addaff(dict.torntendons)

        dict.torntendons.count = (count or 0) + (number or 1)
        if dict.torntendons.count > 7 then
          dict.torntendons.count = 7
        end
        updateaffcount(dict.torntendons)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("torntendons")
        dict.torntendons.count = 0
      end,

      general_cure = function(amount, dontkeep)
        -- two counts are cured if you're above 5
        local howmany = dict.torntendons.count
        for i = 1, (amount or 1) do
          codepaste.remove_stackableaff("torntendons", not dontkeep)
        end
        if howmany > 5 then
          codepaste.remove_stackableaff("torntendons", not dontkeep)
        end
      end,

      general_cured = function(amount)
        removeaff("torntendons")
        dict.torntendons.count = 0
      end,
    }
  },
  cholerichumour = {
    gamename = "temperedcholeric",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.cholerichumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        lostbal_herb()
        codepaste.remove_stackableaff("cholerichumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        lostbal_herb()
      end,

      cured = function()
        lostbal_herb()
        removeaff("cholerichumour")
        dict.cholerichumour.count = 0
      end,

      noeffect = function()
        lostbal_herb()
      end,

      -- does damage based on humour count
      inundated = function()
        removeaff("cholerichumour")
        dict.cholerichumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        eat(dict.cholerichumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = dict.cholerichumour.count
        addaff(dict.cholerichumour)

        dict.cholerichumour.count = (count or 0) + (number or 1)
        if dict.cholerichumour.count > 8 then
          dict.cholerichumour.count = 8
        end
        updateaffcount(dict.cholerichumour)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("cholerichumour")
        dict.cholerichumour.count = 0
      end
    }
  },
  melancholichumour = {
    gamename = "temperedmelancholic",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.melancholichumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        lostbal_herb()
        codepaste.remove_stackableaff("melancholichumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        lostbal_herb()
      end,

      cured = function()
        lostbal_herb()
        removeaff("melancholichumour")
        dict.melancholichumour.count = 0
      end,

      noeffect = function()
        lostbal_herb()
      end,

      -- does mana damage based on humour count
      inundated = function()
        removeaff("melancholichumour")
        dict.melancholichumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        eat(dict.melancholichumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = dict.melancholichumour.count
        addaff(dict.melancholichumour)

        dict.melancholichumour.count = (count or 0) + (number or 1)
        if dict.melancholichumour.count > 8 then
          dict.melancholichumour.count = 8
        end
        updateaffcount(dict.melancholichumour)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("melancholichumour")
        dict.melancholichumour.count = 0
      end
    }
  },
  phlegmatichumour = {
    gamename = "temperedphlegmatic",
    count = 0,
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.phlegmatichumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        lostbal_herb()
        codepaste.remove_stackableaff("phlegmatichumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        lostbal_herb()
      end,

      cured = function()
        lostbal_herb()
        removeaff("phlegmatichumour")
        dict.phlegmatichumour.count = 0
      end,

      noeffect = function()
        lostbal_herb()
      end,

      -- gives various afflictions, amount of which depends on your humour level
      --[[
        slickness always seems to happen
        1-2: add 1 unknown
        3-6: add 2 unknowns
        7-9: add 3 unknowns
        10: add 4 unknowns

        anorexia 50% time
        slickness 8+
      ]]
      inundated = function()
        addaff(dict.slickness)

        if dict.phlegmatichumour.count >= 3 and math.random(1,2) == 1 then
          addaff(dict.anorexia)
        end

        if dict.phlegmatichumour.count == 8 then
          codepaste.addunknownany(4)
        elseif dict.phlegmatichumour.count >= 6 then
          codepaste.addunknownany(3)
        elseif dict.phlegmatichumour.count >= 4 then
          codepaste.addunknownany(2)
        else
          codepaste.addunknownany(1)
        end

        removeaff("phlegmatichumour")
        dict.phlegmatichumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        eat(dict.phlegmatichumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = dict.phlegmatichumour.count
        addaff(dict.phlegmatichumour)

        dict.phlegmatichumour.count = (count or 0) + (number or 1)
        if dict.phlegmatichumour.count > 8 then
          dict.phlegmatichumour.count = 8
        end
        updateaffcount(dict.phlegmatichumour)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("phlegmatichumour")
        dict.phlegmatichumour.count = 0
      end
    }
  },
  sanguinehumour = {
    gamename = "temperedsanguine",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.sanguinehumour) or false
      end,

      -- this is called when you still have some left
      oncompleted = function ()
        lostbal_herb()
        codepaste.remove_stackableaff("sanguinehumour", true)
      end,

      empty = function()
        empty.eat_ginger()
        lostbal_herb()
      end,

      cured = function()
        lostbal_herb()
        removeaff("sanguinehumour")
        dict.sanguinehumour.count = 0
      end,

      noeffect = function()
        lostbal_herb()
      end,

      -- gives bleeding depending on your sanguine humour level, from 250 for first to 2500 for last
      inundated = function()
        local min, max = 250, 2500
        if not affs.sanguinehumour then return end

        local bledfor = dict.sanguinehumour.count * min

        addaff(dict.bleeding)
        dict.bleeding.count = bledfor
        updateaffcount(dict.bleeding)

        removeaff("sanguinehumour")
        dict.sanguinehumour.count = 0
      end,

      eatcure = {"ginger", "antimony"},

      onstart = function ()
        eat(dict.sanguinehumour.herb)
      end
    },
    aff = {
      oncompleted = function (number)
        local count = dict.sanguinehumour.count
        addaff(dict.sanguinehumour)

        dict.sanguinehumour.count = (count or 0) + (number or 1)
        if dict.sanguinehumour.count > 8 then
          dict.sanguinehumour.count = 8
        end
        updateaffcount(dict.sanguinehumour)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("sanguinehumour")
        dict.sanguinehumour.count = 0
      end
    }
  },
  waterbubble = {
    gamename = "airpocket",
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,
      -- not handled by serverside
      undeffable = true,

      isadvisable = function ()
        return false
      end,

      eatcure = {"pear", "calcite"},

      onstart = function ()
        eat(dict.waterbubble.herb)
      end,

      oncompleted = function ()
      end,

      empty = function()
      end
    }
  },
  pacifism = {
    gamename = "pacified",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.pacifism and
          not doingaction("pacifism")
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("pacifism")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.pacifism.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.pacifism and
          not doingaction("pacifism")
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("pacifism")
        lostbal_focus()
      end,

      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.pacifism)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("pacifism")
        codepaste.remove_focusable()
      end,
    }
  },
  peace = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.peace
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("peace")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.peace.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.peace)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("peace")
      end,
    }
  },
  inlove = {
    gamename = "lovers",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.inlove
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("inlove")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.inlove.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.inlove)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("inlove")
      end,
    }
  },
  dissonance = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dissonance and not usingbal("focus")) or false
      end,

      oncompleted = function ()
        removeaff("dissonance")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.dissonance.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.dissonance)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("dissonance")
      end,
    }
  },
  dizziness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dizziness and
          not doingaction("dizziness") and not usingbal("focus")) or false
      end,

      oncompleted = function ()
        removeaff("dizziness")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.dizziness.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dizziness and
          not doingaction("dizziness")) or false
      end,

      oncompleted = function ()
        removeaff("dizziness")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.dizziness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("dizziness")
        codepaste.remove_focusable()
      end,
    }
  },
  shyness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.shyness and
          not doingaction("shyness") and not usingbal("focus")) or false
      end,

      oncompleted = function ()
        removeaff("shyness")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.shyness.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.shyness and
          not doingaction("shyness")) or false
      end,

      oncompleted = function ()
        removeaff("shyness")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.shyness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("shyness")
        codepaste.remove_focusable()
      end,
    }
  },
  epilepsy = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.epilepsy and
          not doingaction("epilepsy") and not usingbal("focus")) or false
      end,

      oncompleted = function ()
        removeaff("epilepsy")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.epilepsy.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.epilepsy and
          not doingaction("epilepsy")) or false
      end,

      oncompleted = function ()
        removeaff("epilepsy")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.epilepsy)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("epilepsy")
        codepaste.remove_focusable()
      end,
    }
  },
  impatience = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing impatience before hypochondria will make it get re-applied
        return (affs.impatience and not affs.madness and not usingbal("focus")  and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        removeaff("impatience")
        lostbal_herb()

        -- if serverside cures impatience before we can even validate it, cancel it
        affsp.impatience = nil
        killaction (dict.checkimpatience.misc)
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.impatience.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.impatience)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("impatience")
      end,
    }
  },
  stupidity = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.stupidity and
          not doingaction("stupidity") and not usingbal("focus")) or false
      end,

      oncompleted = function ()
        removeaff("stupidity")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.stupidity.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.stupidity and
          not doingaction("stupidity") and not affs.madness) or false
      end,

      oncompleted = function ()
        removeaff("stupidity")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.stupidity)
        sk.stupidity_count = 0
        codepaste.badaeon()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("stupidity")
        codepaste.remove_focusable()
      end,
    }
  },
  masochism = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.masochism and not affs.madness and
          not doingaction("masochism")) or false
      end,

      oncompleted = function ()
        removeaff("masochism")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.masochism.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.masochism and not affs.madness and
          not doingaction("masochism")) or false
      end,

      oncompleted = function ()
        removeaff("masochism")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.masochism)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("masochism")
        codepaste.remove_focusable()
      end,
    }
  },
  recklessness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.recklessness and not affs.madness and
          not doingaction("recklessness")) or false
      end,

      oncompleted = function ()
        removeaff("recklessness")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.recklessness.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.recklessness and not affs.madness and
          not doingaction("recklessness")) or false
      end,

      oncompleted = function ()
        removeaff("recklessness")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function (data)
        if data and data.attacktype and data.attacktype == "domination" and (data.atline+1 == getLastLineNumber("main") or (data.atline+1 == getLastLineNumber("main") and find_until_last_paragraph("The gremlin races between your legs, throwing you off-balance.", "exact"))) then
          addaff(dict.recklessness)
        elseif not conf.aillusion or (stats.maxhealth == stats.currenthealth and stats.maxmana == stats.currentmana) then
          addaff(dict.recklessness)
        end
      end,

      -- used for addaff to skip all checks
      forced = function ()
        addaff(dict.recklessness)
      end
    },
    gone = {
      oncompleted = function()
        removeaff("recklessness")
        codepaste.remove_focusable()
      end,
    },
    onremoved = function ()
      check_generics()
      if not affs.blackout then
        killaction (dict.nomana.waitingfor)
      end
      signals.before_prompt_processing:block(valid.check_recklessness)
    end,
    onadded = function()
      signals.before_prompt_processing:unblock(valid.check_recklessness)
    end,
  },
  justice = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.justice
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("justice")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.justice.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.justice)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("justice")
      end,
    }
  },
  generosity = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.generosity and
          not doingaction("generosity")
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("generosity")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.generosity.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.generosity and
          not doingaction("generosity")
#if skills.chivalry then
        and not dict.rage.misc.isadvisable()
#end
        ) or false
      end,

      oncompleted = function ()
        removeaff("generosity")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.generosity)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("generosity")
        codepaste.remove_focusable()
      end,
    }
  },
  weakness = {
    gamename = "weariness",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.weakness and
          not doingaction("weakness")) or false
      end,

      oncompleted = function ()
        removeaff("weakness")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.weakness.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.weakness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("weakness")
        codepaste.remove_focusable()
      end,
    }
  },
  vertigo = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.vertigo and not affs.madness and
          not doingaction("vertigo")) or false
      end,

      oncompleted = function ()
        removeaff("vertigo")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.vertigo.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.vertigo and not affs.madness and
          not doingaction("vertigo")) or false
      end,

      oncompleted = function ()
        removeaff("vertigo")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.vertigo)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("vertigo")
        codepaste.remove_focusable()
      end,
    }
  },
  loneliness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.loneliness and not affs.madness and not doingaction("loneliness")) or false
      end,

      oncompleted = function ()
        removeaff("loneliness")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.loneliness.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.loneliness and not affs.madness and not doingaction("loneliness")) or false
      end,

      oncompleted = function ()
        removeaff("loneliness")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.loneliness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("loneliness")
        codepaste.remove_focusable()
      end,
    }
  },
  dementia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dementia and not affs.madness and not doingaction("dementia")) or false
      end,

      oncompleted = function ()
        removeaff("dementia")
        lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        eat(dict.dementia.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.dementia and not affs.madness and not doingaction("dementia")) or false
      end,

      oncompleted = function ()
        removeaff("dementia")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.dementia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("dementia")
      end,
    }
  },
  paranoia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.paranoia and not affs.madness and not doingaction("paranoia")) or false
      end,

      oncompleted = function ()
        removeaff("paranoia")
        lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        eat(dict.paranoia.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.paranoia and not affs.madness and not doingaction("paranoia")) or false
      end,

      oncompleted = function ()
        removeaff("paranoia")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.paranoia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("paranoia")
      end,
    }
  },
  hypersomnia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hypersomnia and not affs.madness) or false
      end,

      oncompleted = function ()
        removeaff("hypersomnia")
        lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        eat(dict.hypersomnia.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hypersomnia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hypersomnia")
      end,
    }
  },
  hallucinations = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hallucinations and not affs.madness and not doingaction("hallucinations")) or false
      end,

      oncompleted = function ()
        removeaff("hallucinations")
        lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        eat(dict.hallucinations.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hallucinations and not affs.madness and not doingaction("hallucinations")) or false
      end,

      oncompleted = function ()
        removeaff("hallucinations")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hallucinations)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hallucinations")
      end,
    }
  },
  confusion = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.confusion and
          not doingaction("confusion") and not affs.madness) or false
      end,

      oncompleted = function ()
        removeaff("confusion")
        lostbal_herb()
      end,

      eatcure = {"ash", "stannum"},
      onstart = function ()
        eat(dict.confusion.herb)
      end,

      empty = function()
        empty.eat_ash()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.confusion and
          not doingaction("confusion") and not affs.madness) or false
      end,

      oncompleted = function ()
        removeaff("confusion")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.confusion)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("confusion")
        codepaste.remove_focusable()
      end,
    }
  },
  agoraphobia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.agoraphobia and
          not doingaction("agoraphobia")) or false
      end,

      oncompleted = function ()
        removeaff("agoraphobia")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.agoraphobia.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.agoraphobia and
          not doingaction("agoraphobia")) or false
      end,

      oncompleted = function ()
        removeaff("agoraphobia")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.agoraphobia)
        codepaste.remove_focusable()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("agoraphobia")
      end,
    }
  },
  claustrophobia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.claustrophobia and
          not doingaction("claustrophobia")) or false
      end,

      oncompleted = function ()
        removeaff("claustrophobia")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.claustrophobia.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.claustrophobia and
          not doingaction("claustrophobia")) or false
      end,

      oncompleted = function ()
        removeaff("claustrophobia")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.claustrophobia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("claustrophobia")
        codepaste.remove_focusable()
      end,
    }
  },
  paralysis = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.paralysis) or false
      end,

      oncompleted = function ()
        removeaff("paralysis")
        lostbal_herb()
        killaction(dict.checkparalysis.misc)
      end,

      eatcure = {"bloodroot", "magnesium"},
      onstart = function ()
        eat(dict.paralysis.herb)
      end,

      empty = function()
        empty.eat_bloodroot()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.paralysis)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("paralysis")
      end,
    },
    onremoved = function () affsp.paralysis = nil donext() end
  },
  asthma = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.asthma) or false
      end,

      oncompleted = function ()
        removeaff("asthma")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.asthma.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.asthma)
        local r = findbybal("smoke")
        if r then
          killaction(dict[r.action_name].smoke)
        end

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        codepaste.badaeon()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("asthma")
      end,
    }
  },
  clumsiness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.clumsiness) or false
      end,

      oncompleted = function ()
        removeaff("clumsiness")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.clumsiness.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.clumsiness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("clumsiness")
      end,
    }
  },
  sensitivity = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.sensitivity) or false
      end,

      oncompleted = function ()
        removeaff("sensitivity")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.sensitivity.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.sensitivity)
      end,

      -- used by AI to check if we're deaf when we got sensi
      checkdeaf = function()
        -- if deafness was stripped, then prompt flags would have removed it at this point and defc.deaf wouldn't be set
        -- also check back to see if deafness went instead, like from bloodleech:
        -- A bloodleech leaps at you, clamping with teeth onto exposed flesh and secreting some foul toxin into your bloodstream. You stumble as you are afflicted with sensitivity.$Your hearing is suddenly restored.
        -- or dragoncurse: A sudden sense of panic overtakes you as the draconic curse manifests, afflicting you with sensitivity.$Your hearing is suddenly restored.
        -- however, don't go off on dstab: Bob pricks you twice in rapid succession with her dirk.$Your hearing is suddenly restored.$A prickly, stinging sensation spreads through your body.
        if find_until_last_paragraph("Your hearing is suddenly restored.", "exact") and not find_until_last_paragraph("A prickly, stinging sensation spreads through your body.", "exact") then return end

        if not conf.aillusion or (not defc.deaf and not affs.deafaff) then
          addaff(dict.sensitivity)
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("sensitivity")
      end,
    }
  },
  healthleech = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.healthleech) or false
      end,

      oncompleted = function ()
        removeaff("healthleech")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.healthleech.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.healthleech)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("healthleech")
      end,
    }
  },
  relapsing = {
    -- if it's an aff that can be checked, remove it's action and add an appropriate checkaff. Then if the checkaff succeeds, add the relapsing too.
    saw_with_checkable = false,
    gamename = "scytherus",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.relapsing) or false
      end,

      oncompleted = function ()
        removeaff("relapsing")
        lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        eat(dict.relapsing.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    --[[
      relapsing:  ai off, accept everything
                  ai on, accept everything only if we do have relapsing, or it's a checkable symptom -> undeaf/unblind, blind/deaf, camus, else -> ignore

      implementation: generic affs get called to aff.oncompleted, otherwise specialities deal with aff.<func>
    ]]
    aff = {
      -- this goes off when there is no AI or we got a generic affliction that doesn't mean much
      oncompleted = function ()
        -- don't mess with anything special if we have it confirmed
        if affs.relapsing then return end

        if not conf.aillusion or lifevision.l.diag_physical then
          addaff(dict.relapsing)
          dict.relapsing.saw_with_checkable = nil
        else
          if actions.checkparalysis_aff then
            dict.relapsing.saw_with_checkable = "paralysis"
          elseif not pl.tablex.find_if(actions:keys(), function (key) return string.find(key, "check", 1, true) end) then
            -- don't process the rest of the affs it gives if it's not checkable and we don't have relapsing already
            sk.stopprocessing = true
          end
        end
        dict.relapsing.aff.hitvitality = nil
      end,

      forced = function ()
        addaff(dict.relapsing)
      end,

      camus = function (oldhp)
        if not conf.aillusion or
          ((not affs.recklessness and stats.currenthealth < oldhp) -- health went down without recklessness
           or (dict.relapsing.aff.hitvitality and ((100/stats.maxhealth)* stats.currenthealth) <= 60)) then -- or we're above due to vitality
          addaff(dict.relapsing)
          dict.relapsing.aff.hitvitality = nil
          dict.relapsing.saw_with_checkable = nil
        end
      end,

      sumac = function (oldhp)
        if not conf.aillusion or
          ((not affs.recklessness and stats.currenthealth < oldhp) -- health went down without recklessness
           or (dict.relapsing.aff.hitvitality and ((100/stats.maxhealth)* stats.currenthealth) <= 60)) then -- or we're above due to vitality
          addaff(dict.relapsing)
          dict.relapsing.aff.hitvitality = nil
          dict.relapsing.saw_with_checkable = nil
        end
      end,

      oleander = function (hadblind)
        if not conf.aillusion or (not hadblind and (defc.blind or affs.blindaff)) then
          addaff(dict.relapsing)
          dict.relapsing.saw_with_checkable = nil
        end
      end,

      colocasia = function (hadblindordeaf)
        if not conf.aillusion or (not hadblindordeaf and (defc.blind or affs.blindaff or defc.deaf or deafaff)) then
          addaff(dict.relapsing)
          dict.relapsing.saw_with_checkable = nil
        end
      end,

      oculus = function (hadblind)
        if not conf.aillusion or (hadblind and not (defc.blind or affs.blindaff)) then
          addaff(dict.relapsing)
          dict.relapsing.saw_with_checkable = nil
        end
      end,

      prefarar = function (haddeaf)
        if not conf.aillusion or (haddeaf and not (defc.deaf or affs.deafaff)) then
          addaff(dict.relapsing)
          dict.relapsing.saw_with_checkable = nil
        end
      end,

      asthma = function ()
        if not conf.aillusion or lifevision.l.diag_physical then
          addaff(dict.relapsing)
          dict.relapsing.saw_with_checkable = nil
        else
          if actions.checkasthma_aff then
            dict.relapsing.saw_with_checkable = "asthma"
          elseif not pl.tablex.find_if(actions:keys(), function (key) return string.find(key, "check", 1, true) end) then
            -- don't process the rest of the affs it gives.
            sk.stopprocessing = true
          end
        end
        dict.relapsing.aff.hitvitality = nil
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("relapsing")
        dict.relapsing.saw_with_checkable = nil
      end,
    }
  },
  darkshade = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.darkshade) or false
      end,

      oncompleted = function ()
        removeaff("darkshade")
        lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        eat(dict.darkshade.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or (not oldhp or stats.currenthealth < oldhp) then
          addaff(dict.darkshade)
        end
      end,

      forced = function ()
        addaff(dict.darkshade)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("darkshade")
      end,
    }
  },
  lethargy = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing lethargy before hypochondria or torntendons will make it get re-applied
        return (affs.lethargy and not affs.madness and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        removeaff("lethargy")
        lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        eat(dict.lethargy.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.lethargy)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("lethargy")
      end,
    }
  },
  illness = {
    gamename = "nausea",
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing illness before hypochondria will make it get re-applied
        return (affs.illness and not affs.madness and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        removeaff("illness")
        lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        eat(dict.illness.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        if not find_until_last_paragraph("Your enhanced constitution allows you to shrug off the nausea.", "exact") then
          addaff(dict.illness)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("illness")
      end,
    }
  },
  addiction = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        -- curing addiction before hypochondria or skullfractures will make it get re-applied
        return (affs.addiction and not affs.madness and not affs.hypochondria) or false
      end,

      oncompleted = function ()
        removeaff("addiction")
        lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        eat(dict.addiction.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.addiction)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("addiction")
      end,
    },
    onremoved = function ()
      rift.checkprecache()
    end
  },
  haemophilia = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.haemophilia) or false
      end,

      oncompleted = function ()
        removeaff("haemophilia")
        lostbal_herb()
      end,

      eatcure = {"ginseng", "ferrum"},
      onstart = function ()
        eat(dict.haemophilia.herb)
      end,

      empty = function()
        empty.eat_ginseng()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.haemophilia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("haemophilia")
      end,
    }
  },
  hypochondria = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hypochondria) or false
      end,

      oncompleted = function ()
        removeaff("hypochondria")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.hypochondria.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hypochondria)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hypochondria")
      end,
    }
  },

-- smoke cures
  aeon = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.aeon and codepaste.smoke_elm_pipe()) or false
      end,

      oncompleted = function ()
        removeaff("aeon")
        lostbal_smoke()
        sk.elm_smokepuff()
      end,

      smokecure = {"elm", "cinnabar"},
      onstart = function ()
        send("smoke " .. pipes.elm.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_elm()
        lostbal_smoke()
        sk.elm_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.aeon)
        affsp.aeon = nil
        defences.lost("speed")
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        sk.checkaeony()
        signals.aeony:emit()
        codepaste.badaeon()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("aeon")
      end,
    },
    onremoved = function ()
      affsp.aeon = nil
      sk.retardation_count = 0
      sk.checkaeony()
      signals.aeony:emit()
    end
  },
  hellsight = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hellsight and not affs.inquisition and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        removeaff("hellsight")
        lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      inquisition = function ()
        addaff(dict.inquisition)
        sk.valerian_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hellsight)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hellsight")
      end,
    }
  },
  deadening = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.deadening and codepaste.smoke_elm_pipe()) or false
      end,

      oncompleted = function ()
        removeaff("deadening")
        lostbal_smoke()
        sk.elm_smokepuff()
      end,

      smokecure = {"elm", "cinnabar"},
      onstart = function ()
        send("smoke " .. pipes.elm.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_elm()
        lostbal_smoke()
        sk.elm_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.deadening)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("deadening")
      end,
    }
  },
  madness = {
    gamename = "whisperingmadness",
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.madness and codepaste.smoke_elm_pipe() and not affs.hecate) or false
      end,

      oncompleted = function ()
        removeaff("madness")
        lostbal_smoke()
        sk.elm_smokepuff()
      end,

      smokecure = {"elm", "cinnabar"},
      onstart = function ()
        send("smoke " .. pipes.elm.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_elm()
        lostbal_smoke()
        sk.elm_smokepuff()
      end,

      hecate = function()
        sk.elm_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.madness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("madness")
      end,
    }
  },
  -- valerian cures
  slickness = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.slickness and codepaste.smoke_valerian_pipe() and not doingaction"slickness") or false
      end,

      oncompleted = function ()
        removeaff("slickness")
        lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        lostbal_smoke()
        sk.valerian_smokepuff()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.slickness and not affs.anorexia and not doingaction"slickness" and not affs.stain) or false -- anorexia is redundant, but just in for now
      end,

      oncompleted = function ()
        removeaff("slickness")
        lostbal_herb()
      end,

      eatcure = {"bloodroot", "magnesium"},
      onstart = function ()
        eat(dict.slickness.herb)
      end,

      empty = function()
        empty.eat_bloodroot()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.slickness)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("slickness")
      end,
    }
  },
  disloyalty = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.disloyalty and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        removeaff("disloyalty")
        lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        lostbal_smoke()
        sk.valerian_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.disloyalty)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("disloyalty")
      end,
    }
  },
  manaleech = {
    smoke = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.manaleech and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        removeaff("manaleech")
        lostbal_smoke()
        sk.valerian_smokepuff()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end,

      empty = function ()
        empty.smoke_valerian()
        lostbal_smoke()
        sk.valerian_smokepuff()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.manaleech)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("manaleech")
      end,
    }
  },


  -- restoration cures
  heartseed = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.heartseed and not affs.mildtrauma) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingheartseed.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        apply(dict.heartseed.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.heartseed.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.heartseed)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("heartseed")
      end,
    }
  },
  curingheartseed = {
    spriority = 0,
    waitingfor = {
      customwait = 6, -- 4 to cure

      oncompleted = function ()
        removeaff("heartseed")
      end,

      ontimeout = function ()
        removeaff("heartseed")
      end,

      noeffect = function ()
        removeaff("heartseed")
      end,

      onstart = function ()
    -- add blocking of the cure coming too early if it'll become necessary.
      end,
    }
  },
  hypothermia = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.hypothermia and not affs.mildtrauma) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curinghypothermia.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        apply(dict.hypothermia.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.hypothermia.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hypothermia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hypothermia")
      end,
    }
  },
  curinghypothermia = {
    spriority = 0,
    waitingfor = {
      customwait = 6, -- 4 to cure

      oncompleted = function ()
        removeaff("hypothermia")
      end,

      ontimeout = function ()
        removeaff("hypothermia")
      end,

      noeffect = function ()
        removeaff("hypothermia")
      end,

      onstart = function ()
        -- add blocking of the cure coming too early if it'll become necessary.
      end,
    }
  },

  mutilatedrightleg = {
    gamename = "mangledrightleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedrightleg) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmutilatedrightleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        apply(dict.mutilatedrightleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mutilatedrightleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          dict.mutilatedrightleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mutilatedrightleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mutilatedrightleg", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mutilatedrightleg")
      end,
    }
  },
  curingmutilatedrightleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mutilatedrightleg")
        addaff(dict.mangledrightleg)

        local result = checkany(dict.curingmutilatedleftleg.waitingfor, dict.curingmangledrightleg.waitingfor, dict.curingmangledleftleg.waitingfor, dict.curingparestolegs.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedrightleg then
          removeaff("mutilatedrightleg")
          addaff(dict.mangledrightleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mutilatedrightleg")
        addaff(dict.mangledrightleg)
      end,

      noeffect = function ()
        removeaff("mutilatedrightleg")
      end
    }
  },
  parestolegs = {
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      customwaitf = function()
        return not affs.blackout and 0 or 4 -- can't see applies in blackout
      end,

      isadvisable = function ()
        return (affs.parestolegs) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingparestolegs.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        apply(dict.parestolegs.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.parestolegs.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.parestolegs)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("parestolegs")
      end,
    }
  },
  curingparestolegs = {
    waitingfor = {
      customwait = 4,

      oncompleted = function ()
        removeaff("parestolegs")

        local result = checkany(dict.curingmutilatedrightleg.waitingfor, dict.curingmutilatedleftleg.waitingfor, dict.curingmangledrightleg.waitingfor, dict.curingmangledleftleg.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      onstart = function ()
      end,

      ontimeout = function ()
        removeaff("parestolegs")
      end,

      noeffect = function ()
        removeaff("parestolegs")
      end
    }
  },
  mangledrightleg = {
    gamename = "damagedrightleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledrightleg and not (affs.mutilatedrightleg or affs.mutilatedleftleg)) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmangledrightleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        apply(dict.mangledrightleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mangledrightleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          dict.mangledrightleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mangledrightleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mangledrightleg", oldhp, true)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("mangledrightleg")
      end,
    }
  },
  curingmangledrightleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("parestolegs")
        removeaff("mangledrightleg")
        addaff(dict.crippledrightleg)

        local result = checkany(dict.curingmutilatedrightleg.waitingfor, dict.curingmutilatedleftleg.waitingfor, dict.curingmangledleftleg.waitingfor, dict.curingparestolegs.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledrightleg then
          removeaff("mangledrightleg")
          addaff(dict.crippledrightleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mangledrightleg")
        addaff(dict.crippledrightleg)
      end,

      noeffect = function ()
        removeaff("mangledrightleg")
      end
    }
  },
  crippledrightleg = {
    gamename = "brokenrightleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledrightleg and not (affs.mutilatedrightleg or affs.mangledrightleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("crippledrightleg")

        if affs.unknowncrippledlimb then
          dict.unknowncrippledlimb.count = dict.unknowncrippledlimb.count - 1
          if dict.unknowncrippledlimb.count <= 0 then removeaff"unknowncrippledlimb" else updateaffcount(dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledleg then return end
        dict.unknowncrippledleg.count = dict.unknowncrippledleg.count - 1
        if dict.unknowncrippledleg.count <= 0 then removeaff"unknowncrippledleg" else updateaffcount(dict.unknowncrippledleg) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to legs", "apply mending", "apply renewal to legs", "apply renewal"},
      onstart = function ()
        apply(dict.crippledrightleg.salve, " to legs")
      end,

      fizzled = function ()
        lostbal_salve()
        addaff(dict.mangledrightleg)
      end,

      noeffect = function ()
        lostbal_salve()
        empty.noeffect_mending_legs()
      end,

      -- sometimes restoration can lag out and hit when this goes - ignore
      empty = function() end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.crippledrightleg)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("crippledrightleg")
      end,
    }
  },
  mutilatedleftleg = {
    gamename = "mangledleftleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedleftleg) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmutilatedleftleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        apply(dict.mutilatedleftleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mutilatedleftleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          dict.mutilatedleftleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mutilatedleftleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mutilatedleftleg", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mutilatedleftleg")
      end,
    }
  },
  curingmutilatedleftleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mutilatedleftleg")
        addaff(dict.mangledleftleg)

        local result = checkany(dict.curingmutilatedrightleg.waitingfor, dict.curingmangledrightleg.waitingfor, dict.curingmangledleftleg.waitingfor, dict.curingparestolegs.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedleftleg then
          removeaff("mutilatedleftleg")
          addaff(dict.mangledleftleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mutilatedleftleg")
        addaff(dict.mangledleftleg)
      end,

      noeffect = function ()
        removeaff("mutilatedleftleg")
      end
    }
  },
  mangledleftleg = {
    gamename = "damagedleftleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledleftleg and not (affs.mutilatedrightleg or affs.mutilatedleftleg)) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmangledleftleg.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to legs", "apply restoration", "apply reconstructive to legs", "apply reconstructive"},
      onstart = function ()
        apply(dict.mangledleftleg.salve, " to legs")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mangledleftleg.salve.oncompleted()
      end,

      -- in blackout, this goes through quietly
      ontimeout = function()
        if affs.blackout then
          dict.mangledleftleg.salve.oncompleted()
        end
      end,
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakleg("mangledleftleg", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakleg("mangledleftleg", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mangledleftleg")
      end,
    }
  },
  curingmangledleftleg = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("parestolegs")
        removeaff("mangledleftleg")
        addaff(dict.crippledleftleg)

        local result = checkany(dict.curingmutilatedrightleg.waitingfor, dict.curingmutilatedleftleg.waitingfor, dict.curingmangledrightleg.waitingfor, dict.curingparestolegs.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledleftleg then
          removeaff("mangledleftleg")
          addaff(dict.crippledleftleg)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mangledleftleg")
        addaff(dict.crippledleftleg)
      end,

      noeffect = function ()
        removeaff("mangledleftleg")
      end
    }
  },
  crippledleftleg = {
    gamename = "brokenleftleg",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledleftleg and not (affs.mutilatedleftleg or affs.mangledleftleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("crippledleftleg")

        if affs.unknowncrippledlimb then
          dict.unknowncrippledlimb.count = dict.unknowncrippledlimb.count - 1
          if dict.unknowncrippledlimb.count <= 0 then removeaff"unknowncrippledlimb" else updateaffcount(dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledleg then return end
        dict.unknowncrippledleg.count = dict.unknowncrippledleg.count - 1
        if dict.unknowncrippledleg.count <= 0 then removeaff"unknowncrippledleg" else updateaffcount(dict.unknowncrippledleg) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to legs", "apply mending", "apply renewal to legs", "apply renewal"},
      onstart = function ()
        apply(dict.crippledleftleg.salve, " to legs")
      end,

      fizzled = function ()
        lostbal_salve()
        addaff(dict.mangledleftleg)
      end,

      noeffect = function ()
        lostbal_salve()
        empty.noeffect_mending_legs()
      end,

      -- sometimes restoration can lag out and hit when this goes - ignore
      empty = function() end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.crippledleftleg)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("crippledleftleg")
      end,
    }
  },
  parestoarms = {
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      customwaitf = function()
        return not affs.blackout and 0 or 4 -- can't see applies in blackout
      end,

      isadvisable = function ()
        return (affs.parestoarms) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingparestoarms.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        apply(dict.parestoarms.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.parestoarms.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.parestoarms)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("parestoarms")
      end,
    }
  },
  curingparestoarms = {
    waitingfor = {
      customwait = 4,

      oncompleted = function ()
        removeaff("parestoarms")

        local result = checkany(dict.curingmutilatedrightarm.waitingfor, dict.curingmutilatedleftarm.waitingfor, dict.curingmangledrightarm.waitingfor, dict.curingmangledleftarm.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      onstart = function ()
      end,

      ontimeout = function ()
        removeaff("parestoarms")
      end,

      noeffect = function ()
        removeaff("parestoarms")
      end
    }
  },
  mutilatedleftarm = {
    gamename = "mangledleftarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedleftarm) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmutilatedleftarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        apply(dict.mutilatedleftarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mutilatedleftarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mutilatedleftarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mutilatedleftarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mutilatedleftarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmutilatedleftarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mutilatedleftarm")
        addaff(dict.mangledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = checkany(dict.curingmutilatedrightarm.waitingfor, dict.curingmangledrightarm.waitingfor, dict.curingmangledleftarm.waitingfor, dict.curingparestoarms.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedleftarm then
          removeaff("mutilatedleftarm")
          addaff(dict.mangledleftarm)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mutilatedleftarm")
        addaff(dict.mangledleftarm)
      end,

      noeffect = function ()
        removeaff("mutilatedleftarm")
      end
    }
  },
  mangledleftarm = {
    gamename = "damagedleftarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledleftarm and not (affs.mutilatedrightarm or affs.mutilatedleftarm)) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmangledleftarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        apply(dict.mangledleftarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mangledleftarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mangledleftarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mangledleftarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mangledleftarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmangledleftarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("parestoarms")
        removeaff("mangledleftarm")
        addaff(dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = checkany(dict.curingmutilatedrightarm.waitingfor, dict.curingmutilatedleftarm.waitingfor, dict.curingmangledrightarm.waitingfor, dict.curingparestoarms.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledleftarm then
          removeaff("mangledleftarm")
          addaff(dict.crippledleftarm)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mangledleftarm")
        addaff(dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      noeffect = function ()
        removeaff("mangledleftarm")
      end
    }
  },
  crippledleftarm = {
    gamename = "brokenleftarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledleftarm and not (affs.mutilatedleftarm or affs.mangledleftarm or affs.parestoarms)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("crippledleftarm")

        if affs.unknowncrippledlimb then
          dict.unknowncrippledlimb.count = dict.unknowncrippledlimb.count - 1
          if dict.unknowncrippledlimb.count <= 0 then removeaff"unknowncrippledlimb" else updateaffcount(dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledarm then return end
        dict.unknowncrippledarm.count = dict.unknowncrippledarm.count - 1
        if dict.unknowncrippledarm.count <= 0 then removeaff"unknowncrippledarm" else updateaffcount(dict.unknowncrippledarm) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to arms", "apply mending", "apply renewal to arms", "apply renewal"},
      onstart = function ()
        apply(dict.crippledleftarm.salve, " to arms")
      end,

      fizzled = function ()
        lostbal_salve()
        addaff(dict.mangledleftarm)
      end,

      noeffect = function ()
        lostbal_salve()
        empty.noeffect_mending_arms()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("crippledleftarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  mutilatedrightarm = {
    gamename = "mangledrightarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mutilatedrightarm) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmutilatedrightarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        apply(dict.mutilatedrightarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mutilatedrightarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mutilatedrightarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mutilatedrightarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mutilatedrightarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmutilatedrightarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mutilatedrightarm")
        addaff(dict.mangledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = checkany(dict.curingmutilatedleftarm.waitingfor, dict.curingmangledrightarm.waitingfor, dict.curingmangledleftarm.waitingfor, dict.curingparestoarms.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mutilatedrightarm then
          removeaff("mutilatedrightarm")
          addaff(dict.mangledrightarm)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mutilatedleftarm")
        addaff(dict.mangledleftarm)
      end,

      noeffect = function ()
        removeaff("mutilatedrightarm")
      end
    }
  },
  mangledrightarm = {
    gamename = "damagedrightarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mangledrightarm and not (affs.mutilatedrightarm or affs.mutilatedleftarm)) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmangledrightarm.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to arms", "apply restoration", "apply reconstructive to arms", "apply reconstructive"},
      onstart = function ()
        apply(dict.mangledrightarm.salve, " to arms")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mangledrightarm.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        codepaste.addrestobreakarm("mangledrightarm", oldhp)
      end,

      tekura = function (oldhp)
        codepaste.addrestobreakarm("mangledrightarm", oldhp, true)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mangledrightarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingmangledrightarm = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mangledrightarm")
        removeaff("parestoarms")
        addaff(dict.crippledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        local result = checkany(dict.curingmutilatedrightarm.waitingfor, dict.curingmutilatedleftarm.waitingfor, dict.curingmangledleftarm.waitingfor, dict.curingparestoarms.waitingfor)

        if result then
          killaction(dict[result.action_name].waitingfor)
        end
      end,

      ontimeout = function ()
        if affs.mangledrightarm then
          removeaff("mangledrightarm")
          addaff(dict.crippledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      onstart = function ()
      end,

      oncuredleft = function()
        removeaff("mangledleftarm")
        addaff(dict.crippledleftarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      noeffect = function ()
        removeaff("mangledrightarm")
      end
    }
  },
  crippledrightarm = {
    gamename = "brokenrightarm",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.crippledrightarm and not (affs.mutilatedrightarm or affs.mangledrightarm or affs.parestoarms)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("crippledrightarm")

        if affs.unknowncrippledlimb then
          dict.unknowncrippledlimb.count = dict.unknowncrippledlimb.count - 1
          if dict.unknowncrippledlimb.count <= 0 then removeaff"unknowncrippledlimb" else updateaffcount(dict.unknowncrippledlimb) end
        end

        if not affs.unknowncrippledarm then return end
        dict.unknowncrippledarm.count = dict.unknowncrippledarm.count - 1
        if dict.unknowncrippledarm.count <= 0 then removeaff"unknowncrippledarm" else updateaffcount(dict.unknowncrippledarm) end
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to arms", "apply mending", "apply renewal to arms", "apply renewal"},
      onstart = function ()
        apply(dict.crippledrightarm.salve, " to arms")
      end,

      fizzled = function ()
        lostbal_salve()
        addaff(dict.mangledrightarm)
      end,

      noeffect = function ()
        lostbal_salve()
        empty.noeffect_mending_arms()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.crippledrightarm)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("crippledrightarm")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  laceratedthroat = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.laceratedthroat) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curinglaceratedthroat.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to head", "apply restoration", "apply reconstructive to head", "apply reconstructive"},
      onstart = function ()
        apply(dict.laceratedthroat.salve, " to head")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.laceratedthroat.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.laceratedthroat)
      end,

      -- separated, so we can use it normally if necessary - another class might get it
      sylvanhit = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          addaff(dict.laceratedthroat)
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("laceratedthroat")
      end,
    }
  },
  curinglaceratedthroat = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("laceratedthroat")
        addaff(dict.slashedthroat)
      end,

      onstart = function ()
      end,

      noeffect = function()
        removeaff("laceratedthroat")
        addaff(dict.slashedthroat)
      end,

      noeffect = function ()
        removeaff("laceratedthroat")
      end
    }
  },
  slashedthroat = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.slashedthroat) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("slashedthroat")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        apply(dict.slashedthroat.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.slashedthroat)
      end,

      -- separated, so we can use it normally if necessary - another class might get it
      sylvanhit = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          addaff(dict.slashedthroat)
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("slashedthroat")
      end,
    }
  },
  serioustrauma = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.serioustrauma) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingserioustrauma.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        apply(dict.serioustrauma.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.serioustrauma.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or paragraph_length >= 3 then
          if affs.mildtrauma then removeaff("mildtrauma") end
          addaff(dict.serioustrauma)
        end
      end,

      forced = function ()
        if affs.mildtrauma then removeaff("mildtrauma") end
        addaff(dict.serioustrauma)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("serioustrauma")
      end,
    }
  },
  curingserioustrauma = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("serioustrauma")
        addaff(dict.mildtrauma)
      end,

      ontimeout = function ()
        if affs.serioustrauma then
          removeaff("serioustrauma")
          addaff(dict.mildtrauma)
        end
      end,

      onstart = function ()
      end,

      noeffect = function ()
        removeaff("serioustrauma")
        removeaff("mildtrauma")
      end
    }
  },
  mildtrauma = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mildtrauma) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmildtrauma.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to torso", "apply restoration", "apply reconstructive to torso", "apply reconstructive"},
      onstart = function ()
        apply(dict.mildtrauma.salve, " to torso")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mildtrauma.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or paragraph_length >= 3 then
          addaff(dict.mildtrauma)
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mildtrauma")
      end,
    }
  },
  curingmildtrauma = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mildtrauma")
      end,

      ontimeout = function ()
        removeaff("mildtrauma")
      end,

      onstart = function ()
      end,

      noeffect = function ()
        removeaff("mildtrauma")
      end
    }
  },
  seriousconcussion = {
    gamename = "mangledhead",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.seriousconcussion) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingseriousconcussion.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to head", "apply restoration", "apply reconstructive to head", "apply reconstructive"},
      onstart = function ()
        apply(dict.seriousconcussion.salve, " to head")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.seriousconcussion.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or paragraph_length >= 3 then
          if affs.mildconcussion then removeaff("mildconcussion") end
          addaff(dict.seriousconcussion)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      forced = function ()
        if affs.mildconcussion then removeaff("mildconcussion") end
        addaff(dict.seriousconcussion)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("seriousconcussion")
      end,
    },
    onadded = function()
      if affs.prone and affs.seriousconcussion then
        sk.warn "pulpable"
      end
    end
  },
  curingseriousconcussion = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("seriousconcussion")
        addaff(dict.mildconcussion)
      end,

      ontimeout = function ()
        if affs.seriousconcussion then
          removeaff("seriousconcussion")
          addaff(dict.mildconcussion)
        end
      end,

      onstart = function ()
      end,

      noeffect = function ()
        removeaff("seriousconcussion")
        removeaff("mildconcussion")
      end
    }
  },
  mildconcussion = {
    gamename = "damagedhead",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.mildconcussion) or false
      end,

      oncompleted = function ()
        lostbal_salve()

        doaction(dict.curingmildconcussion.waitingfor)
      end,

      applycure = {"restoration", "reconstructive"},
      actions = {"apply restoration to head", "apply restoration", "apply reconstructive to head", "apply reconstructive"},
      onstart = function ()
        apply(dict.mildconcussion.salve, " to head")
      end,

      -- we get no msg from an application of this
      empty = function ()
        dict.mildconcussion.salve.oncompleted()
      end
    },
    aff = {
      oncompleted = function (oldhp)
        if not conf.aillusion or not oldhp or oldhp > stats.currenthealth or paragraph_length >= 3 then
          addaff(dict.mildconcussion)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end
      end,

      forced = function ()
        addaff(dict.mildconcussion)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mildconcussion")
      end,
    }
  },
  curingmildconcussion = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("mildconcussion")
      end,

      ontimeout = function ()
        removeaff("mildconcussion")
      end,

      onstart = function ()
      end,

      noeffect = function ()
        removeaff("mildconcussion")
      end
    }
  },


-- salve cures
  anorexia = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.anorexia and not doingaction "anorexia") or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("anorexia")
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_epidermal_body()
      end,

      empty = function ()
        empty.apply_epidermal_body()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to body", "apply epidermal", "apply sensory to body", "apply sensory"},
      onstart = function ()
        apply(dict.anorexia.salve, " to body")
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.anorexia and
          not doingaction("anorexia")) or false
      end,

      oncompleted = function ()
        removeaff("anorexia")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.anorexia)
        codepaste.badaeon()
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("anorexia")
        codepaste.remove_focusable()
      end,
    }
  },
  ablaze = {
    gamename = "burning",
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.ablaze) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("ablaze")
      end,

      all = function()
        lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        apply(dict.ablaze.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("ablaze")
        addaff(dict.ablaze)
      end,
    },
    gone = {
      oncompleted = function ()
        local currentburn = sk.current_burn()
        removeaff(currentburn)
      end,

      -- used in blackout and passive curing where multiple levels could be cured at once
      generic_reducelevel = function(amount)
        -- if no amount is specified, find the current level and take it down a notch
        if not amount then
          local reduceto, currentburn = sk.previous_burn(), sk.current_burn()

          removeaff(currentburn)
          addaff(dict[reduceto])
        else -- amount is specified
          local reduceto, currentburn = sk.previous_burn(amount), sk.current_burn()
          removeaff(currentburn)

          if not reduceto then reduceto = "ablaze" end
          addaff(dict[reduceto])
        end
      end
    }
  },
  severeburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.severeburn) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("severeburn")
        addaff(dict.ablaze)
      end,

      all = function()
        lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        apply(dict.severeburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("severeburn")
        addaff(dict.severeburn)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("severeburn")
      end,
    }
  },
  extremeburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.extremeburn) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("extremeburn")
        addaff(dict.severeburn)
      end,

      all = function()
        lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        apply(dict.extremeburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("extremeburn")
        addaff(dict.extremeburn)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("extremeburn")
      end,
    }
  },
  charredburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.charredburn) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("charredburn")
        addaff(dict.extremeburn)
      end,

      all = function()
        lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        apply(dict.charredburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("charredburn")
        addaff(dict.charredburn)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("charredburn")
      end,
    }
  },
  meltingburn = {
    salve = {
      aspriority = 0,
      spriority = 0,
      irregular = true,

      isadvisable = function ()
        return (affs.meltingburn) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("meltingburn")
        addaff(dict.charredburn)
      end,

      all = function()
        lostbal_salve()
        codepaste.remove_burns()
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal"},
      onstart = function ()
        apply(dict.meltingburn.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        codepaste.remove_burns("meltingburn")
        addaff(dict.meltingburn)

        sk.warn "golemdestroyable"
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("meltingburn")
      end,
    }
  },
  selarnia = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.selarnia) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("selarnia")
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      empty = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending to body", "apply mending", "apply renewal to body", "apply renewal", "apply mending to torso", "apply renewal to torso"},
      onstart = function ()
        apply(dict.selarnia.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.selarnia)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("selarnia")
      end,
    }
  },
  itching = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.itching) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("itching")
      end,

      noeffect = function ()
        empty.apply_epidermal_body()
      end,

      empty = function ()
        empty.apply_epidermal_body()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to body", "apply epidermal", "apply sensory to body", "apply sensory"},
      onstart = function ()
        apply(dict.itching.salve, " to body")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.itching)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("itching")
      end,
    }
  },
  stuttering = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.stuttering) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("stuttering")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        apply(dict.stuttering.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.stuttering)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("stuttering")
      end,
    }
  },
  scalded = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.scalded and not defc.blind and not affs.blindaff) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("scalded")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        apply(dict.scalded.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.scalded)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("scalded")
      end,
    }
  },
  numbedleftarm = {
    waitingfor = {
      customwait = 15, -- lasts 15s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        removeaff("numbedleftarm")
        make_gnomes_work()
      end,

      oncompleted = function ()
        removeaff("numbedleftarm")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.numbedleftarm)
        if not actions.numbedleftarm_waitingfor then doaction(dict.numbedleftarm.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("numbedleftarm")
        killaction (dict.numbedleftarm.waitingfor)
      end,
    }
  },
  numbedrightarm = {
    waitingfor = {
      customwait = 8, -- lasts 8s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        removeaff("numbedrightarm")
        make_gnomes_work()
      end,

      oncompleted = function ()
        removeaff("numbedrightarm")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.numbedrightarm)
        if not actions.numbedrightarm_waitingfor then doaction(dict.numbedrightarm.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("numbedrightarm")
        killaction (dict.numbedrightarm.waitingfor)
      end,
    }
  },
  blindaff = {
    gamename = "blind",
    onservereignore = function()
      return not dict.blind.onservereignore()
    end,
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.blindaff or (defc.blind and not ((sys.deffing and defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind))) or affs.scalded) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("blindaff")
        defences.lost("blind")

        local restoreaff, restoredef
        if affs.deafaff then restoreaff = true end
        if defc.deaf then restoredef = true end

        empty.apply_epidermal_head()

        if restoreaff then addaff(dict.deafaff) end
        if restoredef then defences.got("deaf") end
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        apply(dict.blindaff.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        if (defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)
#if class ~= "apostate" then
         or defc.mindseye
#end
         then
          defences.got("blind")
        else
          addaff(dict.blindaff)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("blindaff")
        defences.lost("blind")
      end,
    }
  },
  deafaff = {
    gamename = "deaf",
    onservereignore = function()
      return not dict.deaf.onservereignore()
    end,
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.deafaff or defc.deaf and not ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf))) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("deafaff")
        defences.lost("deaf")
      end,

      noeffect = function ()
        empty.apply_epidermal_head()
      end,

      empty = function ()
        empty.apply_epidermal_head()
      end,

      applycure = {"epidermal", "sensory"},
      actions = {"apply epidermal to head", "apply epidermal", "apply sensory to head", "apply sensory"},
      onstart = function ()
        apply(dict.deafaff.salve, " to head")
      end
    },
    aff = {
      oncompleted = function ()
        if (defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye then
          defences.got("deaf")
        else
          addaff(dict.deafaff)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("deafaff")
        defences.lost("deaf")
      end,
    }
  },

  shivering = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.shivering and not affs.frozen and not affs.hypothermia) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("shivering")
      end,

      noeffect = function()
        lostbal_salve()
      end,

      gotcaloricdef = function (hypothermia)
        if not hypothermia then removeaff({"frozen", "shivering"}) end
        dict.caloric.salve.oncompleted ()
      end,

      applycure = {"caloric", "exothermic"},
      actions = {"apply caloric to body", "apply caloric", "apply exothermic to body", "apply exothermic"},
      onstart = function ()
        apply(dict.shivering.salve, " to body")
      end,

      empty = function ()
        lostbal_salve()
        removeaff("shivering")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.shivering)
        defences.lost("caloric")
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("shivering")
      end,
    }
  },
  frozen = {
    salve = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.frozen and not affs.hypothermia) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("frozen")
        addaff(dict.shivering)
      end,

      noeffect = function()
        lostbal_salve()
      end,

      gotcaloricdef = function (hypothermia)
        if not hypothermia then removeaff({"frozen", "shivering"}) end
        dict.caloric.salve.oncompleted ()
      end,

      applycure = {"caloric", "exothermic"},
      actions = {"apply caloric to body", "apply caloric", "apply exothermic to body", "apply exothermic"},
      onstart = function ()
        apply(dict.frozen.salve, " to body")
      end,

      empty = function ()
        lostbal_salve()
        removeaff("frozen")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.frozen)
        defences.lost("caloric")
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("frozen")
      end
    }
  },

-- purgatives
  voyria = {
    purgative = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.voyria) or false
      end,

      oncompleted = function ()
        lostbal_purgative()
        removeaff("voyria")
      end,

      sipcure = {"immunity", "antigen"},
      onstart = function ()
        sip(dict.voyria.purgative)
      end,

      noeffect = function()
        removeaff("voyria")
        lostbal_purgative()
      end,

      empty = function ()
        lostbal_purgative()
        empty.sip_immunity()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.voyria)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("voyria")
      end
    }
  },


-- misc
  lovers = {
    map = {},
    tempmap = {},
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.lovers and not doingaction("lovers")) or false
      end,

      oncompleted = function (whom)
        dict.lovers.map[whom] = nil
        if not next(dict.lovers.map) then
          removeaff("lovers")
        end
      end,

      onclear = function ()
        dict.lovers.tempmap = {}
      end,

      nobody = function ()
        if dict.lovers.rejecting then
          dict.lovers.map[dict.lovers.rejecting] = nil
          dict.lovers.rejecting = nil
        end

        if not next(dict.lovers.map) then
          removeaff("lovers")
        end
      end,

      onstart = function ()
        dict.lovers.rejecting = next(dict.lovers.map)
        if not dict.lovers.rejecting then -- if we added it via some manual way w/o a name, this failsafe will catch & remove it
          removeaff("lovers")
          return
        end

        send("reject " .. dict.lovers.rejecting, conf.commandecho)
      end
    },
    aff = {
      oncompleted = function (whom)
        if not dict.lovers.tempmap and not whom then return end

        addaff(dict.lovers)
        for _, name in ipairs(dict.lovers.tempmap) do
          dict.lovers.map[name] = true
        end
        dict.lovers.tempmap = {}

        if whom then
          dict.lovers[whom] = true
        end

        affl.lovers = {names = dict.lovers.map}
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("lovers")
        dict.lovers.map = {}
      end,
    }
  },
  fear = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.fear and not doingaction("fear")) or false
      end,

      oncompleted = function ()
        removeaff("fear")
      end,

      action = "compose",
      onstart = function ()
        send("compose", conf.commandecho)
      end
    },
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return false
        --[[return (affs.fear and
          not doingaction("fear")) or false]]
      end,

      oncompleted = function ()
        removeaff("fear")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.fear)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("fear")
        codepaste.remove_focusable()
      end
    }
  },
  sleep = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.sleep and
          not doingaction("curingsleep") and not doingaction("sleep")) or false
      end,

      oncompleted = function ()
        doaction(dict.curingsleep.waitingfor)
      end,

      actions = {"wake", "wake up"},
      onstart = function ()
        send("wake up", conf.commandecho)
      end,

      -- ???
      empty = function ()
      end
    },
    aff = {
      oncompleted = function ()
        if not affs.sleep then addaff(dict.sleep) defences.lost("insomnia") end
      end,

      symptom = function()
        if not affs.sleep then addaff(dict.sleep) defences.lost("insomnia") end
        addaff(dict.prone)

        -- reset non-wait things we were doing, because they got cancelled by the stun
        if affs.sleep or actions.sleep_aff then
          for k,v in actions:iter() do
            if v.p.balance ~= "waitingfor" and v.p.balance ~= "aff" and v.p.name ~= "sleep_misc" then
              killaction(dict[v.p.action_name][v.p.balance])
            end
          end
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("sleep")
      end,
    }
  },
  curingsleep = {
    spriority = 0,
    waitingfor = {
      customwait = 999,

      oncompleted = function ()
        removeaff("sleep")

        -- reset sleep so we try waking up again after being awoken and slept at once (like in a dsl or a delph snipe)
        if actions.sleep_misc then
          killaction(dict.sleep.misc)
        end
      end,

      onstart = function () end
    }
  },
  bleeding = {
    count = 0,
    -- affs.bleeding.spammingbleed is used to throttle bleed spamming so it doesn't get out of control
    misc = {
      aspriority = 0,
      spriority = 0,
      -- managed outside priorities
      uncurable = true,

      isadvisable = function ()
        if affs.bleeding and not doingaction("bleeding") and not affs.bleeding.spammingbleed and not affs.haemophilia and not affs.sleep and can_usemana() and conf.clot then
          if (not affs.corrupted and dict.bleeding.count >= conf.bleedamount) then
            return true
          elseif (affs.corrupted and dict.bleeding.count >= conf.manableedamount) then
            if stats.currenthealth >= sys.corruptedhealthmin then
              return true
            else
              sk.warn "cantclotmana"
              return false
            end
          end
        else return false end
      end,

      -- by default, oncompleted means a clot went through okay
      oncompleted = function ()
        dict.bleeding.saw_haemophilia = nil
      end,

      -- oncured in this case means that we actually cured it; don't have any more bleeding
      oncured = function ()
        if affs.bleeding and affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
        removeaff("bleeding")
        dict.bleeding.count = 0
        dict.bleeding.saw_haemophilia = nil
      end,

      nomana = function ()
        if not actions.nomana_waitingfor and stats.currentmana ~= 0 then
          echof("Seems we're out of mana.")
          doaction(dict.nomana.waitingfor)
        end

        dict.bleeding.saw_haemophilia = nil
        if affs.bleeding and affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
      end,

      haemophilia = function()
        if dict.bleeding.saw_haemophilia then
          addaff(dict.haemophilia)
          echof("Seems like we do have haemophilia for real.")
        else
          dict.bleeding.saw_haemophilia = true
        end
        if affs.bleeding and affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
      end,

      action = "clot",
      onstart = function ()
        local show = conf.commandecho and not conf.gagclot
        send("clot", show)

        -- don't optimize with corruption for now (but do if need need be)
        if not sys.sync and ((not affs.corrupted and svo.stats.mp >= 70 and (dict.bleeding.count and dict.bleeding.count >= 200))
            or (affs.corrupted and stats.currenthealth+500 >= sys.corruptedhealthmin)) then
          send("clot", show)
          send("clot", show)

          -- after sending a bunch of clots, wait a bit before doing it again
          if affs.bleeding then
            if affs.bleeding.spammingbleed then killTimer(affs.bleeding.spammingbleed); affs.bleeding.spammingbleed = nil end
            affs.bleeding.spammingbleed = tempTimer(getping(), function () affs.bleeding.spammingbleed = nil; make_gnomes_work() end)
          end
        end
      end
    },
    aff = {
      oncompleted = function (amount)
        addaff(dict.bleeding)
        -- TODO: affs.count vs dict.count?
        affs.bleeding.p.count = amount or (affs.bleeding.p.count + 200)
        updateaffcount(dict.bleeding)

        -- remove bleeding if we've had it for a while and didn't clot it up
        if sk.smallbleedremove then killTimer(sk.smallbleedremove) end
        sk.smallbleedremove = tempTimer(conf.smallbleedremove or 8, function()
          sk.smallbleedremove = nil
          if not affs.bleeding then return end

          if dict.bleeding.count <= conf.bleedamount or dict.bleeding.count <= conf.manableedamount then
            removeaff("bleeding")
          end
        end)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("bleeding")
      end,
    },
    onremoved = function()
      dict.bleeding.count = 0
      if sk.smallbleedremove then
        killTimer(sk.smallbleedremove)
        sk.smallbleedremove = nil
      end
    end
  },
  touchtree = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not bals.tree or doingaction("touchtree") or affs.sleep or not conf.tree or affs.stun or affs.unconsciousness or affs.numbedrightarm or affs.numbedleftarm or affs.paralysis or affs.webbed or affs.bound or affs.transfixed or affs.roped or affs.impale or ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm)) or codepaste.nonstdcure() then return false end

        for name, func in pairs(tree) do
          if not me.disabledtreefunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function (aff)
        -- small heuristic - shivering can be upgraded to frozen
        if aff == "shivering" and not affs.shivering and affs.frozen then
          removeaff("frozen")
        -- handle levels of burns
        elseif aff == "all burns" then
          codepaste.remove_burns()
        elseif aff == "burn" then
          local previousburn, currentburn = sk.previous_burn(), sk.current_burn()

          if not burn then
            codepaste.remove_burns()
          else
            removeaff(currentburn)
            addaff(dict[previousburn])
          end
#for _, aff in ipairs({"skullfractures", "crackedribs", "wristfractures", "torntendons"}) do
        elseif aff == "$(aff)" then
          -- two counts are cured if you're above 5
          local howmany = dict.$(aff).count
          codepaste.remove_stackableaff("$(aff)", true)
          if howmany > 5 then
            codepaste.remove_stackableaff("$(aff)", true)
          end
        elseif aff == "$(aff) cured" then
          removeaff("$(aff)")
          dict.$(aff).count = 0
#end
        else
          removeaff(aff)
        end

        lostbal_tree()
      end,

      action = "touch tree",
      onstart = function ()
        send("touch tree", conf.commandecho)
      end,

      empty = function ()
        lostbal_tree()
        empty.tree()
      end,

      offbal = function ()
        lostbal_tree()
      end
    }
  },
#if skills.healing then
  usehealing = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not bals.balance or not bals.equilibrium or not bals.healing or conf.usehealing == "none" or not can_usemana() or doingaction "usehealing" or affs.transfixed or stats.currentwillpower <= 50 or defc.bedevil or ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm)) then return false end

        -- we calculate here if we can use Healing on any of the affs we got; cache the result as well

        -- small func for getting the spriority of a thing
        local function getprio(what)
          local type = type
          for k,v in pairs(what) do
            if type(v) == "table" and v.spriority then
              return v.spriority
            end
          end
        end

        local t = {}
        for affname, aff in pairs(affs) do
          if sk.healingmap[affname] and not ignore[affname] and not doingaction (affname) and not doingaction ("curing"..affname) and sk.healingmap[affname]() then
            t[affname] = getprio(dict[affname])
          end
        end

        if not next(t) then return false end
        dict.usehealing.afftocure = getHighestKey(t)
        return true
      end,

      oncompleted = function()
        if not dict.usehealing.curingaff or (dict.usehealing.curingaff ~= "deaf" and dict.usehealing.curingaff ~= "blind") then
          lostbal_healing()
        end

        dict.usehealing.curingaff = nil
      end,

      empty = function ()
        if not dict.usehealing.curingaff or (dict.usehealing.curingaff ~= "deaf" and dict.usehealing.curingaff ~= "blind") then
          lostbal_healing()
        end

        if not dict.usehealing.curingaff then return end
        removeaff(dict.usehealing.curingaff)
        dict.usehealing.curingaff = nil
      end,

      -- haven't regained healing balance yet
      nobalance = function()
        if not dict.usehealing.curingaff or (dict.usehealing.curingaff ~= "deaf" and dict.usehealing.curingaff ~= "blind") then
          lostbal_healing()
        end

        dict.usehealing.curingaff = nil
      end,

      -- have bedevil def up; can't use healing
      bedevilheal = function()
        dict.usehealing.curingaff = nil
        defences.got("bedevil")
      end,

      onstart = function ()
        local aff = dict.usehealing.afftocure
        local svonames = {
          blind = "blindness",
          deaf = "deafness",
          blindaff = "blindness",
          deafaff = "deafness",
          illness = "vomiting",
          weakness = "weariness",
          crippledleftarm = "arms",
          crippledrightarm = "arms",
          crippledleftleg = "legs",
          crippledrightleg = "legs",
          unknowncrippledleg = "legs",
          unknowncrippledarm = "arms",
          ablaze = "burning",
        }

        local use_no_name = {
          unknowncrippledlimb = true,
          blackout = true,
        }

        if use_no_name[aff] then
          send("heal", conf.commandecho)
        else
          send("heal me "..(svonames[aff] or aff), conf.commandecho)
        end
        dict.usehealing.curingaff = dict.usehealing.afftocure
        dict.usehealing.afftocure = nil
      end
    }
  },
#end
  restore = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not conf.restore or usingbal("salve") or codepaste.balanceful_codepaste() or codepaste.nonstdcure() then return false end

        for name, func in pairs(restore) do
          if not me.disabledrestorefunc[name] then
            local s,m = pcall(func[1])
            if s and m then debugf("restore: %s strat went off", name) return true end
          end
        end
      end,

      oncompleted = function (number)
        if number then
          -- empty
          if number+1 == getLineNumber() then
            dict.unknowncrippledlimb.count = 0
            dict.unknowncrippledarm.count = 0
            dict.unknowncrippledleg.count = 0
            removeaff({"crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "unknowncrippledarm", "unknowncrippledleg", "unknowncrippledlimb"})
          end
        end
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      action = "restore",
      onstart = function ()
        send("restore", conf.commandecho)
      end
    }
  },
  dragonheal = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      uncurable = true,

      isadvisable = function ()
        if not next(affs) or not defc.dragonform or not conf.dragonheal or not bals.dragonheal or codepaste.balanceful_codepaste() or codepaste.nonstdcure() or (affs.recklessness and affs.weakness) then return false end

        for name, func in pairs(dragonheal) do
          if not me.disableddragonhealfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function (number)
        if number then
          -- empty
          if number+1 == getLineNumber() then
            empty.dragonheal()
          end
        end

        lostbal_dragonheal()
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      nobalance = function ()
        lostbal_dragonheal()
      end,

      action = "dragonheal",
      onstart = function ()
        send("dragonheal", conf.commandecho)
      end
    }
  },
  defcheck = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        local bals = bals
        return (bals.balance and bals.equilibrium and me.manualdefcheck and not doingaction("defcheck")) or false
      end,

      oncompleted = function ()
        me.manualdefcheck = false
        process_defs()
      end,

      ontimeout = function ()
        me.manualdefcheck = false
      end,

      action = "def",
      onstart = function ()
        send("def", conf.commandecho)
      end
    },
  },
  diag = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return ((sys.manualdiag or (affs.unknownmental and affs.unknownmental.p.count >= conf.unknownfocus) or (affs.unknownany and affs.unknownany.p.count >= conf.unknownany)) and bals.balance and bals.equilibrium and not doingaction("diag")) or false
      end,

      oncompleted = function ()
        sys.manualdiag = false
        sk.diag_list = {}
        removeaff("unknownmental")
        removeaff("unknownany")
        dict.unknownmental.count = 0
        dict.unknownany.count = 0
        dict.bleeding.saw_haemophilia = nil
        dict.relapsing.saw_with_checkable = nil

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,

      actions = {"diag", "diagnose", "diag me", "diagnose me"},
      onstart = function ()
        send("diag", conf.commandecho)
      end
    },
  },
  block = {
    gamename = "blocking",
    physical = {
      blockingdir = "",
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        if defc.block and ((conf.keepup and not defkeepup[defs.mode].block and not sys.deffing) or (sys.deffing and not defdefup[defs.mode].block)) and not doingaction"block" then return true end

        return (((sys.deffing and defdefup[defs.mode].block) or (conf.keepup and defkeepup[defs.mode].block and not sys.deffing)) and (not defc.block or dict.block.physical.blockingdir ~= conf.blockingdir) and not doingaction"block" and (not sys.enabledgmcp or (gmcp.Room and gmcp.Room.Info.exits[conf.blockingdir])) and not codepaste.balanceful_codepaste() and not affs.prone
#if skills.metamorphosis then
        and (defc.riding or defc.elephant or defc.dragonform or defc.hydra)
#end
#if skills.subterfuge then
  -- you can't block while phased
        and not defc.phase
#end
        ) or false
      end,

      oncompleted = function (dir)
        if dir then
          dict.block.physical.blockingdir = sk.anytoshort(dir)
        else --workaround for looping
          dict.block.physical.blockingdir = conf.blockingdir
        end
        defences.got("block")
      end,

      -- in case of failing to block, register that the action has been completed
      failed = function()
      end,

      onstart = function ()
        if (not defc.block or dict.block.physical.blockingdir ~= conf.blockingdir) then
          send("block "..tostring(conf.blockingdir), conf.commandecho)
        else
          send("unblock", conf.commandecho)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        defences.lost("block")
        dict.block.physical.blockingdir = ""

        if actions.block_physical then
          killaction(dict.block.physical)
        end
      end
    }
  },
#if skills.kaido then
  transmute = {
    -- transmutespam is used to throttle bleed spamming so it doesn't get out of control
    transmutespam = false,
    transmutereps = 0,
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (conf.transmute ~= "none" and not defc.dragonform and (stats.currenthealth < sys.transmuteamount or (sk.gettingfullstats and stats.currenthealth < stats.maxhealth)) and not doingaction"healhealth" and not doingaction"transmute" and not codepaste.balanceful_codepaste() and can_usemana() and (not affs.prone or doingaction"prone") and not dict.transmute.transmutespam) or false
      end,

      oncompleted = function()
        -- count down transmute reps, and if we can, cancel the transmute-blocking timer
        dict.transmute.transmutereps = dict.transmute.transmutereps - 1
        if dict.transmute.transmutereps <= 0 then
          -- in case transmute expired and we finish after
          if dict.transmute.transmutespam then killTimer(dict.transmute.transmutespam); dict.transmute.transmutespam = nil end
          dict.transmute.transmutereps = 0
        end
      end,

      onstart = function ()
        local necessary_amount = (not sk.gettingfullstats and math.ceil(sys.transmuteamount - stats.currenthealth) or (stats.maxhealth - stats.currenthealth))
        local available_mana = math.floor(stats.currentmana - sys.manause)

        -- compute just how much of the necessary amount can we transmute given our available mana, and a 1:1 health gain/mana loss mapping
        necessary_amount = (available_mana > necessary_amount) and necessary_amount or available_mana

        dict.transmute.transmutereps = 0
        local reps = math.floor(necessary_amount/1000)

        for i = 1, reps do
          send("transmute 1000", conf.commandecho)
          dict.transmute.transmutereps = dict.transmute.transmutereps + 1
        end
        if necessary_amount % 1000 ~= 0 then
          send("transmute "..necessary_amount % 1000, conf.commandecho)
          dict.transmute.transmutereps = dict.transmute.transmutereps + 1
        end

        -- after sending a bunch of transmutes, wait a bit before doing it again
        if dict.transmute.transmutespam then killTimer(dict.transmute.transmutespam); dict.transmute.transmutespam = nil end
        dict.transmute.transmutespam = tempTimer(getping()*1.5, function () dict.transmute.transmutespam = nil; dict.transmute.transmutereps = 0 make_gnomes_work() end)
        -- if it's just one transmute, then we can get it done in ping time (but allow for flexibility) - otherwise do it in 2x ping time, as there's a big skip between the first and latter commands
      end
    }
  },
#end
  doparry = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (not sys.sp_satisfied and not sys.blockparry and not affs.paralysis
          and not doingaction "doparry" and (
#if class == "monk" then
            conf.guarding
#else
            conf.parry
#end
           ) and not codepaste.balanceful_codepaste()
#if class ~= "blademaster" and class ~= "monk" then
          -- blademasters can parry with their sword sheathed
          and ((not sys.enabledgmcp or defc.dragonform) or (next(me.wielded) and sk.have_parryable()))
#end
          and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function (limb)
        local t = sps.parry_currently
        for limb, _ in pairs(t) do t[limb] = false end
        t[limb] = true
        check_sp_satisfied()
      end,

      onstart = function ()
        if sps.something_to_parry() then
          for name, limb in pairs(sp_config.parry_shouldbe) do
            if limb and limb ~= sps.parry_currently[name] then
#if not skills.tekura then
              send(string.format("%sparry %s", (not defc.dragonform and "" or "claw"), name), conf.commandecho)
#else
              send(string.format("%s %s", (not defc.dragonform and "guard" or "clawparry"), name), conf.commandecho)
#end
              return
            end
          end
        elseif type(sp_config.parry) == "string" and sp_config.parry == "manual" then
          -- check if we need to unparry in manual
          for limb, status in pairs(sps.parry_currently) do
            if status ~= sp_config.parry_shouldbe[limb] then
#if not skills.tekura then
             send(string.format("%sparry nothing", (not defc.dragonform and "" or "claw")), conf.commandecho)
#else
             send(string.format("%s nothing", (not defc.dragonform and "guard" or "clawparry")), conf.commandecho)
#end
             return
            end
          end

          -- got here? nothing to do...
          sys.sp_satisfied = true
        elseif sp_config.priority[1] and not sps.parry_currently[sp_config.priority[1]] then
#if not skills.tekura then
          send(string.format("%sparry %s", (not defc.dragonform and "" or "claw"), sp_config.priority[1]), conf.commandecho)
#else
          send(string.format("%s %s", (not defc.dragonform and "guard" or "clawparry"), sp_config.priority[1]), conf.commandecho)
#end
        else -- got here? nothing to do...
          sys.sp_satisfied = true end
      end,

      none = function ()
        for limb, _ in pairs(sps.parry_currently) do
          sps.parry_currently[limb] = false
        end

        check_sp_satisfied()
      end
    }
  },
  doprecache = {
    misc = {
      aspriority = 0,
      spriority = 0,
      -- not a curable in-game affliction? mark it so priority doesn't get set
      uncurable = true,

      isadvisable = function ()
        return (rift.doprecache and not sys.blockoutr and not findbybal"herb" and not doingaction"doprecache" and sys.canoutr) or false
      end,

      oncompleted = function ()
        -- check if we still need to precache, and if not, clear rift.doprecache
        rift.checkprecache()

        if rift.doprecache then
          -- allow other outrs to catch up, then re-check again
          if sys.blockoutr then killTimer(sys.blockoutr); sys.blockoutr = nil end
          sys.blockoutr = tempTimer(sys.wait + syncdelay(), function () sys.blockoutr = nil; debugf("sys.blockoutr expired") make_gnomes_work() end)
          debugf("sys.blockoutr setup: ", debug.traceback())
        end
      end,

      ontimeout = function ()
        rift.checkprecache()
      end,

      onstart = function ()
        for herb, amount in pairs(rift.precache) do
          if rift.precache[herb] ~= 0 and rift.riftcontents[herb] ~= 0 and (rift.invcontents[herb] < rift.precache[herb]) then
            send(string.format("outr %s%s", (affs.addiction and "" or (rift.precache[herb] - rift.invcontents[herb].." ")), herb), conf.commandecho)
            if sys.sync then return end
          end
        end
      end
    }
  },
  prone = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.prone and (not affs.paralysis or doingaction"paralysis")
#if skills.weaponmastery then
          and (sk.didfootingattack or (bals.balance and bals.equilibrium and bals.leftarm and bals.rightarm))
#else
          and bals.balance and bals.equilibrium and bals.leftarm and bals.rightarm
#end
          and not doingaction("prone") and not affs.sleep
          and not affs.impale
          and not affs.transfixed
          and not affs.webbed and not affs.bound and not affs.roped
          and not affs.crippledleftleg and not affs.crippledrightleg
          and not affs.mangledleftleg and not affs.mangledrightleg
          and not affs.mutilatedleftleg and not affs.mutilatedrightleg) or false
      end,

      oncompleted = function ()
        removeaff("prone")
      end,

#if skills.weaponmastery then
      actions = {"stand", "recover footing"},
#else
      action = "stand",
#end
      onstart = function ()
#if skills.weaponmastery then
        if sk.didfootingattack and conf.recoverfooting then
          send("recover footing", conf.commandecho)
          if affs.blackout then send("recover footing", conf.commandecho) end
        else
          send("stand", conf.commandecho)
          if affs.blackout then send("stand", conf.commandecho) end
        end
#else
        send("stand", conf.commandecho)
        if affs.blackout then send("stand", conf.commandecho) end
#end
      end
    },
    aff = {
      oncompleted = function ()
        if not affs.prone then addaff(dict.prone) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("prone")
      end
    },
    onremoved = function () donext() end,
    onadded = function()
      if affs.prone and affs.seriousconcussion then
        sk.warn "pulpable"
      end
    end
  },
  disrupt = {
    gamename = "disrupted",
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.disrupt and not doingaction("disrupt")
          and not affs.confusion and not affs.sleep) or false
      end,

      oncompleted = function ()
        removeaff("disrupt")
      end,

      oncured = function ()
        removeaff("disrupt")
      end,

      action = "concentrate",
      onstart = function ()
        send("concentrate", conf.commandecho)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.disrupt)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("disrupt")
      end
    }
  },
  lightpipes = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return ((not pipes.valerian.arty and not pipes.valerian.lit and pipes.valerian.puffs > 0 and not (pipes.valerian.id == 0)
          or (not pipes.elm.arty and not pipes.elm.lit and pipes.elm.puffs > 0 and not (pipes.elm.id == 0))
          or (not pipes.skullcap.arty and not pipes.skullcap.lit and pipes.skullcap.puffs > 0 and not (pipes.skullcap.id == 0))
          or (not pipes.elm.arty2 and not pipes.elm.lit2 and pipes.elm.puffs2 > 0 and not (pipes.elm.id2 == 0))
          or (not pipes.valerian.arty2 and not pipes.valerian.lit2 and pipes.valerian.puffs2 > 0 and not (pipes.valerian.id2 == 0))
          or (not pipes.skullcap.arty2 and not pipes.skullcap.lit2 and pipes.skullcap.puffs2 > 0 and not (pipes.skullcap.id2 == 0))
          )
        and (conf.relight or sk.forcelight_valerian or sk.forcelight_skullcap or sk.forcelight_elm)
        and not (doingaction("lightskullcap") or doingaction("lightelm") or doingaction("lightvalerian") or doingaction("lightpipes"))) or false
      end,

      oncompleted = function ()
        pipes.valerian.lit = true
        pipes.valerian.lit2 = true
        sk.forcelight_valerian = false
        pipes.elm.lit = true
        pipes.elm.lit2 = true
        sk.forcelight_elm = false
        pipes.skullcap.lit = true
        pipes.skullcap.lit2 = true
        sk.forcelight_skullcap = false

        lastlit("valerian")
      end,

      actions = {"light pipes"},
      onstart = function ()
        if conf.gagrelight then
          send("light pipes", false)
        else
          send("light pipes", conf.commandecho) end
      end
    }
  },
  fillskullcap = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      herb = "skullcap",
      uncurable = true,
      fillingid = 0,

      mainpipeout = function()
        return (pipes.skullcap.puffs <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.skullcap.id == 0)
      end,

      secondarypipeout = function()
        return (pipes.skullcap.puffs2 <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.skullcap.id2 == 0)
      end,

      isadvisable = function ()
        return ((dict.fillskullcap.physical.mainpipeout() or dict.fillskullcap.physical.secondarypipeout()) and not doingaction("fillskullcap") and not doingaction("fillelm") and not doingaction("fillvalerian") and not will_take_balance() and not (affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm or affs.paralysis or affs.transfixed)) or false
      end,

      oncompleted = function ()
        if dict.fillskullcap.fillingid == pipes.skullcap.id then
          pipes.skullcap.puffs = pipes.skullcap.maxpuffs or 10
          pipes.skullcap.lit = false
          rift.invcontents.skullcap = rift.invcontents.skullcap - 1
          if rift.invcontents.skullcap < 0 then rift.invcontents.skullcap = 0 end
        else
          pipes.skullcap.puffs2 = pipes.skullcap.maxpuffs2 or 10
          pipes.skullcap.lit2 = false
          rift.invcontents.skullcap = rift.invcontents.skullcap - 1
          if rift.invcontents.skullcap < 0 then rift.invcontents.skullcap = 0 end
        end
      end,

      onstart = function ()
        if dict.fillskullcap.physical.mainpipeout() then
          fillpipe("skullcap", pipes.skullcap.id)
          dict.fillskullcap.fillingid = pipes.skullcap.id
        else
          fillpipe("skullcap", pipes.skullcap.id2)
          dict.fillskullcap.fillingid = pipes.skullcap.id2
        end
      end
    }
  },
  fillelm = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      herb = "elm",
      uncurable = true,
      fillingid = 0,

      mainpipeout = function()
        return (pipes.elm.puffs <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.elm.id == 0)
      end,

      secondarypipeout = function()
        return (pipes.elm.puffs2 <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.elm.id2 == 0)
      end,

      isadvisable = function ()
        return ((dict.fillelm.physical.mainpipeout() or dict.fillelm.physical.secondarypipeout()) and not doingaction("fillskullcap") and not doingaction("fillelm") and not doingaction("fillvalerian") and not will_take_balance()  and not (affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm or affs.paralysis or affs.transfixed)) or false
      end,

      oncompleted = function ()
        if dict.fillelm.fillingid == pipes.elm.id then
          pipes.elm.puffs = pipes.elm.maxpuffs or 10
          pipes.elm.lit = false
          rift.invcontents.elm = rift.invcontents.elm - 1
          if rift.invcontents.elm < 0 then rift.invcontents.elm = 0 end
        else
          pipes.elm.puffs2 = pipes.elm.maxpuffs2 or 10
          pipes.elm.lit2 = false
          rift.invcontents.elm = rift.invcontents.elm - 1
          if rift.invcontents.elm < 0 then rift.invcontents.elm = 0 end
        end
      end,

      onstart = function ()
        if dict.fillelm.physical.mainpipeout() then
          fillpipe("elm", pipes.elm.id)
          dict.fillelm.fillingid = pipes.elm.id
        else
          fillpipe("elm", pipes.elm.id2)
          dict.fillelm.fillingid = pipes.elm.id2
        end
      end
    }
  },
  fillvalerian = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      herb = "valerian",
      uncurable = true,
      fillingid = 0,

      mainpipeout = function()
        return (pipes.valerian.puffs <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.valerian.id == 0)
      end,

      secondarypipeout = function()
        return (pipes.valerian.puffs2 <= ((sys.sync or defc.selfishness) and 0 or conf.refillat)) and not (pipes.valerian.id2 == 0)
      end,

      isadvisable = function ()
        if (dict.fillvalerian.physical.mainpipeout() or dict.fillvalerian.physical.secondarypipeout()) and not doingaction("fillskullcap") and not doingaction("fillelm") and not doingaction("fillvalerian") and not will_take_balance() then

          if (affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm or affs.paralysis or affs.transfixed) then
            sk.warn "emptyvalerianpipenorefill"
            return false
          else
            return true
          end
        end
      end,

      oncompleted = function ()
        if dict.fillvalerian.fillingid == pipes.valerian.id then
          pipes.valerian.puffs = pipes.valerian.maxpuffs or 10
          pipes.valerian.lit = false
          rift.invcontents.valerian = rift.invcontents.valerian - 1
          if rift.invcontents.valerian < 0 then rift.invcontents.valerian = 0 end
        else
          pipes.valerian.puffs2 = pipes.valerian.maxpuffs2 or 10
          pipes.valerian.lit2 = false
          rift.invcontents.valerian = rift.invcontents.valerian - 1
          if rift.invcontents.valerian < 0 then rift.invcontents.valerian = 0 end
        end
      end,

      onstart = function ()
        if dict.fillvalerian.physical.mainpipeout() then
          fillpipe("valerian", pipes.valerian.id)
          dict.fillvalerian.fillingid = pipes.valerian.id
        else
          fillpipe("valerian", pipes.valerian.id2)
          dict.fillvalerian.fillingid = pipes.valerian.id2
        end
      end
    }
  },
  rewield = {
    rewieldables = false,
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (conf.autorewield and dict.rewield.rewieldables and not doingaction"rewield" and not affs.impale and not affs.webbed and not affs.transfixed and not affs.roped and not affs.transfixed and sys.canoutr and not affs.mutilatedleftarm and not affs.mutilatedrightarm and not affs.mangledrightarm and not affs.mangledleftarm and not affs.crippledrightarm and not affs.crippledleftarm) or false
      end,

      oncompleted = function (id)
        if not dict.rewield.rewieldables then return end

        for count, item in ipairs(dict.rewield.rewieldables) do
          if item.id == id then
            table.remove(dict.rewield.rewieldables, count)
            break
          end
        end

        if #dict.rewield.rewieldables == 0 then
          dict.rewield.rewieldables = false
        end
      end,

      failed = function ()
        dict.rewield.rewieldables = false
      end,

      clear = function ()
        dict.rewield.rewieldables = false
      end,

      onstart = function ()
        for _, t in pairs(dict.rewield.rewieldables) do
          send("wield "..t.id, conf.commandecho)
          if sys.sync then return end
        end
      end
    }
  },
  blackout = {
    waitingfor = {
      customwait = 60,

      onstart = function ()
      end,

      oncompleted = function ()
        removeaff("blackout")
      end,

      ontimeout = function ()
        removeaff("blackout")
      end
    },
    aff = {
      oncompleted = function ()
        if affs.blackout then return end

        addaff(dict.blackout)
        check_generics()

        tempTimer(4.5, function() if affs.blackout then addaff(dict.disrupt) make_gnomes_work() end end)

        -- prevent leprosy in blackout
        if svo.enabledskills.necromancy then
          echof("Fighting a Necromancer - going to assume crippled limbs every now and then.")
          tempTimer(3, function() if affs.blackout then addaff(dict.unknowncrippledlimb) make_gnomes_work() end end)
          tempTimer(5, function() if affs.blackout then addaff(dict.unknowncrippledlimb) make_gnomes_work() end end)
        end

        if svo.enabledskills.curses then
          echof("Fighting a Shaman - going to check for asthma/anorexia.")
          tempTimer(3, function() if affs.blackout then affsp.anorexia = true; affsp.asthma = true; make_gnomes_work() end end)
          tempTimer(5, function() if affs.blackout then affsp.anorexia = true; affsp.asthma = true; make_gnomes_work() end end)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("blackout")
      end,
    },
    onremoved = function ()
      check_generics()
      if sk.sylvan_eclipse then
        sys.manualdiag = true
      end

      if not affs.recklessness then
        killaction (dict.nomana.waitingfor)
      end

      if dict.blackout.check_lust then
        echof("Checking allies for potential lust...")
        send("allies", conf.commandecho)
        dict.blackout.check_lust = nil
      end

      tempTimer(0.5, function()
        if not bals.equilibrium and not conf.serverside then addaff(dict.disrupt) end

        if stats.currenthealth == 0 and conf.assumestats ~= 0 then
          reset.affs()
          reset.general()
          reset.defs()
          conf.paused = true
          echo"\n"echof("We died.")
          raiseEvent("svo config changed", "paused")
        end
      end)

      -- if we came out with full health and mana out of blackout, assume we've got recklessness meanwhile. don't do it in serverside curing though, because that doesn't assume the same
      if (not dict.blackout.addedon or dict.blackout.addedon ~= os.time()) and stats.currenthealth == stats.maxhealth and stats.currentmana == stats.maxmana then
        addaff(dict.recklessness)
        echof("suspicious full stats out of blackout - going to assume reckless.")
        if conf.serverside then
          sendcuring("predict recklessness")
        end
      end
    end,
    onadded = function()
      dict.blackout.addedon = os.time()
    end
  },
  unknownany = {
    count = 0,
    reckhp = false, reckmana = false,
    waitingfor = {
      customwait = 999,

      onstart = function ()
      end,

      empty = function ()
      end
    },
    aff = {
      oncompleted = function (number)

        if ((dict.unknownany.reckhp and stats.currenthealth == stats.maxhealth) or
          (dict.unknownany.reckmana and stats.currentmana == stats.maxmana)) then
            addaff(dict.recklessness)

            if conf.serverside then
              sendcuring("predict recklessness")
            end

            if number and number > 1 then
              -- take one off because one affliction is recklessness
              codepaste.addunknownany(number-1)
            end
        else
          codepaste.addunknownany(number)
        end

        dict.unknownany.reckhp = false; dict.unknownany.reckmana = false
      end,

      wrack = function()
        -- if 3, then it was not hidden, ignore - affliction triggers will watch the aff
        if paragraph_length >= 3 then return end

        if ((dict.unknownany.reckhp and stats.currenthealth == stats.maxhealth) or
          (dict.unknownany.reckmana and stats.currentmana == stats.maxmana)) then
            addaff(dict.recklessness)

            if conf.serverside then
              sendcuring("predict recklessness")
            end
        else
          codepaste.addunknownany()
        end

        dict.unknownany.reckhp = false; dict.unknownany.reckmana = false
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("unknownany")
        dict.unknownany.count = 0
      end,

      -- to be used when you lost one unknown (for example, you saw a symptom for something else)
      lost_level = function()
        if not affs.unknownany then return end
        affs.unknownany.p.count = affs.unknownany.p.count - 1
        if affs.unknownany.p.count <= 0 then
          removeaff("unknownany")
          dict.unknownany.count = 0
        else
          updateaffcount(dict.unknownany)
        end
      end
    }
  },
  unknownmental = {
    count = 0,
    reckhp = false, reckmana = false,
    focus = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknownmental) or false
      end,

      oncompleted = function ()
        -- special: gets called on each focus mind cure, but we most of
        -- the time don't have an unknown aff
        if not affs.unknownmental then return end
        affs.unknownmental.p.count = affs.unknownmental.p.count - 1
        if affs.unknownmental.p.count <= 0 then
          removeaff("unknownmental")
          dict.unknownmental.count = 0
        else
          updateaffcount(dict.unknownmental)
        end

        lostbal_focus()
      end,

      onstart = function ()
        send("focus mind", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        removeaff("unknownmental")
      end
    },
    aff = {
      oncompleted = function (number)
        if ((dict.unknownmental.reckhp and stats.currenthealth == stats.maxhealth) or
          (dict.unknownmental.reckmana and stats.currentmana == stats.maxmana)) then
            addaff(dict.recklessness)

            if conf.serverside then
              sendcuring("predict recklessness")
            end

            if number and number > 1 then
              local count = dict.unknownany.count
              addaff(dict.unknownany)
              -- take one off because one affliction is recklessness
              affs.unknownany.p.count = (count or 0) + (number - 1)
              updateaffcount(dict.unknownany)
            end
        else
          local count = dict.unknownmental.count
          addaff(dict.unknownmental)

          dict.unknownmental.count = (count or 0) + (number or 1)
          updateaffcount(dict.unknownmental)
        end

        dict.unknownmental.reckhp = false; dict.unknownmental.reckmana = false
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("unknownmental")
        dict.unknownmental.count = 0
      end,

      -- to be used when you lost one focusable (for example, you saw a symptom for something else)
      lost_level = function()
        if not affs.unknownmental then return end
        affs.unknownmental.p.count = affs.unknownmental.p.count - 1
        if affs.unknownmental.p.count <= 0 then
          removeaff("unknownmental")
          dict.unknownmental.count = 0
        else
          updateaffcount(dict.unknownmental)
        end
      end
    }
  },
  unknowncrippledlimb = {
    count = 0,
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknowncrippledlimb and not (affs.mutilatedrightarm or affs.mutilatedleftarm or affs.mangledleftarm or affs.mangledrightarm or affs.parestoarms) and not (affs.mutilatedrightleg or affs.mutilatedleftleg or affs.mangledleftleg or affs.mangledrightleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("unknowncrippledlimb")
      end,

      applycure = {"mending", "renewal"},
      actions = {"apply mending", "apply renewal"},
      onstart = function ()
        apply(dict.unknowncrippledlimb.salve)
      end,

      noeffect = function ()
        lostbal_salve()
        empty.apply_mending()
      end,

      fizzled = function ()
        lostbal_salve()
        -- if it fizzled, then it means we've got a resto break on arms or legs
        -- applying resto without targetting a limb doesn't work, so try mending on both, see what happens
        removeaff("unknowncrippledlimb")
        addaff(dict.unknowncrippledarm)
        addaff(dict.unknowncrippledleg)
        tempTimer(0, function() show_info("some limb broken?", "It would seem an arm or a leg of yours is broken (the salve fizzled), not just crippled - going to work out which is it and fix it") end)
      end,
    },
    aff = {
      oncompleted = function (amount)
        dict.unknowncrippledlimb.count = dict.unknowncrippledlimb.count + (amount or 1)
        if dict.unknowncrippledlimb.count > 4 then dict.unknowncrippledlimb.count = 4 end
        addaff(dict.unknowncrippledlimb)
        updateaffcount(dict.unknowncrippledlimb)
      end
    },
    gone = {
      oncompleted = function ()
        dict.unknowncrippledlimb.count = 0
        removeaff("unknowncrippledlimb")
      end,
    },
    onremoved = function ()
      if dict.unknowncrippledlimb.count <= 0 then return end

      dict.unknowncrippledlimb.count = dict.unknowncrippledlimb.count - 1
      if dict.unknowncrippledlimb.count <= 0 then return end
      addaff (dict.unknowncrippledlimb)
      updateaffcount(dict.unknowncrippledlimb)
    end,
  },
  unknowncrippledarm = {
    count = 0,
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknowncrippledarm and not (affs.mutilatedrightarm or affs.mutilatedleftarm or affs.mangledleftarm or affs.mangledrightarm or affs.parestoarms)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("unknowncrippledarm")
      end,

      actions = {"apply mending to arms", "apply mending", "apply renewal to arms", "apply renewal"},
      applycure = {"mending", "renewal"},
      onstart = function ()
        apply(dict.unknowncrippledarm.salve, " to arms")
      end,

      noeffect = function ()
        lostbal_salve()
        empty.noeffect_mending_arms()
      end,

      fizzled = function (limb)
        lostbal_salve()
        if limb and dict["mangled"..limb] then addaff(dict["mangled"..limb]) end
      end,
    },
    aff = {
      oncompleted = function (amount)
        dict.unknowncrippledarm.count = dict.unknowncrippledarm.count + (amount or 1)
        if dict.unknowncrippledarm.count > 2 then dict.unknowncrippledarm.count = 2 end
        addaff(dict.unknowncrippledarm)
        updateaffcount(dict.unknowncrippledarm)
      end,
    },
    gone = {
      oncompleted = function ()
        dict.unknowncrippledarm.count = 0
        removeaff("unknowncrippledarm")
      end,
    },
    onremoved = function ()
      if dict.unknowncrippledarm.count <= 0 then return end

      dict.unknowncrippledarm.count = dict.unknowncrippledarm.count - 1
      if dict.unknowncrippledarm.count <= 0 then return end
      addaff (dict.unknowncrippledarm)
      updateaffcount(dict.unknowncrippledarm)
    end,
  },
  unknowncrippledleg = {
    count = 0,
    salve = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.unknowncrippledleg and not (affs.mutilatedrightleg or affs.mutilatedleftleg or affs.mangledleftleg or affs.mangledrightleg or affs.parestolegs)) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        removeaff("unknowncrippledleg")
      end,

      actions = {"apply mending to legs", "apply mending", "apply renewal to legs", "apply renewal"},
      applycure = {"mending", "renewal"},
      onstart = function ()
        apply(dict.unknowncrippledleg.salve, " to legs")
      end,

      noeffect = function ()
        lostbal_salve()
        empty.noeffect_mending_legs()
      end,

      fizzled = function (limb)
        lostbal_salve()
        if limb and dict["mangled"..limb] then addaff(dict["mangled"..limb]) end
      end,
    },
    aff = {
      oncompleted = function (amount)
        dict.unknowncrippledleg.count = dict.unknowncrippledleg.count + (amount or 1)
        if dict.unknowncrippledleg.count > 2 then dict.unknowncrippledleg.count = 2 end
        addaff(dict.unknowncrippledleg)
        updateaffcount(dict.unknowncrippledleg)
      end
    },
    gone = {
      oncompleted = function ()
        dict.unknowncrippledleg.count = 0
        removeaff("unknowncrippledleg")
      end,
    },
    onremoved = function ()
      if dict.unknowncrippledleg.count <= 0 then return end

      dict.unknowncrippledleg.count = dict.unknowncrippledleg.count - 1
      if dict.unknowncrippledleg.count <= 0 then return end
      addaff (dict.unknowncrippledleg)
      updateaffcount(dict.unknowncrippledleg)
    end,
  },
  unknowncure = {
    count = 0,
    waitingfor = {
      customwait = 999,

      onstart = function ()
      end,

      empty = function ()
      end
    },
    aff = {
      oncompleted = function (number)
        local count = dict.unknowncure.count
        addaff(dict.unknowncure)

        dict.unknowncure.count = (count or 0) + (number or 1)
        updateaffcount(dict.unknowncure)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("unknowncure")
        dict.unknowncure.count = 0
      end
    }
  },


-- writhes
  bound = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.bound and codepaste.writhe()) or false
      end,

      oncompleted = function ()
        doaction(dict.curingbound.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        doaction(dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.bound)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("bound")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingbound = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("bound")
      end,

      onstart = function ()
      end
    }
  },
  webbed = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.webbed and codepaste.writhe() and not (bals.balance and bals.rightarm and bals.leftarm and dict.dragonflex.misc.isadvisable())
#if skills.voicecraft then
          and (not conf.dwinnu or not dict.dwinnu.misc.isadvisable())
#end
        ) or false
      end,

      oncompleted = function ()
        doaction(dict.curingwebbed.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        if math.random(1, 30) == 1 then
          send("writhe wiggle wiggle", conf.commandecho)
        else
          send("writhe", conf.commandecho)
        end
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        doaction(dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        affs.webbed = nil
        addaff(dict.webbed)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("webbed")
      end,
    },
    onremoved = function () signals.canoutr:emit() donext() end
  },
  curingwebbed = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("webbed")
      end,

      onstart = function ()
      end
    }
  },
  roped = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.roped and codepaste.writhe() and not (bals.balance and bals.rightarm and bals.leftarm and dict.dragonflex.misc.isadvisable())
#if skills.voicecraft then
          and (not conf.dwinnu or not dict.dwinnu.misc.isadvisable())
#end
        ) or false
      end,

      oncompleted = function ()
        doaction(dict.curingroped.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        doaction(dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.roped)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("roped")
      end,
    },
    onremoved = function () signals.canoutr:emit() donext() end
  },
  curingroped = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("roped")
      end,

      onstart = function ()
      end
    }
  },
  hoisted = {
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,
      uncurable = true,

      isadvisable = function ()
        return (affs.hoisted and codepaste.writhe() and bals.balance and bals.rightarm and bals.leftarm) or false
      end,

      oncompleted = function ()
        doaction(dict.curinghoisted.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        doaction(dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hoisted)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hoisted")
      end,
    }
  },
  curinghoisted = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("hoisted")
      end,

      onstart = function ()
      end
    }
  },
  transfixed = {
    gamename = "transfixation",
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,

      isadvisable = function ()
        return (affs.transfixed and codepaste.writhe()) or false
      end,

      oncompleted = function ()
        doaction(dict.curingtransfixed.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      impale = function ()
        doaction(dict.curingimpale.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        if not conf.aillusion or ((not affs.blindaff and not defc.blind) or lifevision.l.blindaff_aff or lifevision.l.blind_herb or lifevision.l.blind_misc) then
          affsp.transfixed = nil
          addaff(dict.transfixed)
        end

        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("transfixed")
      end,
    },
    onremoved = function () signals.canoutr:emit() donext() end
  },
  curingtransfixed = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("transfixed")
      end,

      onstart = function ()
      end
    }
  },
  impale = {
    gamename = "impaled",
    misc = {
      aspriority = 0,
      spriority = 0,
      dontbatch = true,


      isadvisable = function ()
        return (affs.impale and not doingaction("curingimpale") and not doingaction("impale") and bals.balance and bals.rightarm and bals.leftarm) or false
      end,

      oncompleted = function ()
        doaction(dict.curingimpale.waitingfor)
      end,

      action = "writhe",
      onstart = function ()
        send("writhe", conf.commandecho)
      end,

      helpless = function ()
        empty.writhe()
      end,

      dragged = function()
        removeaff("impale")
      end,
    },
    aff = {
      oncompleted = function ()
        addaff(dict.impale)
        signals.canoutr:emit()
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("impale")
      end,
    },
    onremoved = function () signals.canoutr:emit() end
  },
  curingimpale = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        removeaff("impale")
      end,

      withdrew = function ()
        removeaff("impale")
      end,

      dragged = function()
        removeaff("impale")
      end,

      onstart = function ()
      end
    }
  },
  dragonflex = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (conf.dragonflex and ((affs.webbed and not ignore.webbed) or (affs.roped and not ignore.roped)) and codepaste.writhe() and not affs.paralysis and defc.dragonform and bals.balance and not doingaction"impale") or false
      end,

      oncompleted = function ()
        removeaff{"webbed", "roped"}
      end,

      action = "dragonflex",
      onstart = function ()
        send("dragonflex", conf.commandecho)
      end
    },
  },
#if skills.voicecraft then
  dwinnu = {
    misc = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (conf.dwinnu and bals.voice and (affs.webbed or affs.roped) and codepaste.writhe() and not affs.paralysis and not defc.dragonform) or false
      end,

      oncompleted = function ()
        removeaff{"webbed", "roped"}
        lostbal_voice()
      end,

      action = "chant dwinnu",
      onstart = function ()
        send("chant dwinnu", conf.commandecho)
      end
    },
  },
#end

#if skills.chivalry then
  rage = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        if not (conf.rage and bals.rage and (affs.inlove or affs.justice or affs.generosity or affs.pacifism or affs.peace) and not defc.dragonform and can_usemana()) then return false end

        for name, func in pairs(rage) do
          if not me.disabledragefunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function ()
        lostbal_rage()
      end,

      empty = function ()
        removeaff{"inlove", "justice", "generosity", "pacifism", "peace"}
        lostbal_rage()
      end,

      action = "rage",
      onstart = function ()
        send("rage", conf.commandecho)
      end
    },
  },
#end

  -- anti-illusion checks, grouped by symptom similarity
  checkslows = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (next(affsp) and (affsp.retardation or affsp.aeon or affsp.truename)) or false
      end,

      oncompleted = function () end,

      sluggish = function ()
        if affsp.retardation then
          affsp.retardation = nil
          addaff (dict.retardation)
          signals.newroom:unblock(sk.check_retardation)
        elseif affsp.aeon then
          affsp.aeon = nil

          addaff(dict.aeon)
          defences.lost("speed")
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        elseif affsp.truename then
          affsp.truename = nil

          addaff(dict.aeon)
          defences.lost("speed")
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        end

        sk.checkaeony()
        signals.aeony:emit()
        codepaste.badaeon()
      end,

      onclear = function ()
        if affsp.retardation then
          affsp.retardation = nil
        elseif affsp.aeon then
          affsp.aeon = nil
        elseif affsp.truename then
          affsp.truename = nil
        end
      end,

      onstart = function ()
        send("say", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (which)
      if paragraph_length > 2 or ignore.checkslows then
          if which == "truename" then which = "aeon" end

          addaff(dict[which])
          killaction (dict.checkslows.misc)

          if which == "aeon" then defences.lost("speed") end
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)

          sk.checkaeony()
          signals.aeony:emit()
          codepaste.badaeon()

          if which == 'retardation' then
            signals.newroom:unblock(sk.check_retardation)
          end
        else
          affsp[which] = true
        end
      end,

      truename = function()
        affsp.truename = true
      end,
    },
  },

  checkanorexia = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affsp.anorexia) or false
      end,

      oncompleted = function () end,

      blehfood = function ()
        addaff(dict.anorexia)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        affsp.anorexia = nil
      end,

      onclear = function ()
        affsp.anorexia = nil
      end,

      onstart = function ()
        send("eat something", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function ()
        if paragraph_length > 2 then
          addaff(dict.anorexia)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          killaction (dict.checkanorexia.misc)
        else
          affsp.anorexia = true
        end

        -- register it as a possible hypochondria symptom
        if paragraph_length == 1 then
          sk.hypochondria_symptom()
        end
      end
    },
  },

  checkparalysis = {
    description = "anti-illusion check for paralysis",
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return false -- hardcoded to be off, as there's no known solution currently that works
        --return (affsp.paralysis and not affs.sleep and (not conf.waitparalysisai or (bals.balance and bals.equilibrium)) and not affs.roped) or false
      end,

      oncompleted = function () end,

      paralysed = function ()
        addaff(dict.paralysis)

        if dict.relapsing.saw_with_checkable == "paralysis" then
          dict.relapsing.saw_with_checkable = nil
          addaff(dict.relapsing)
        end

        if type(affsp.paralysis) == "string" then
          addaff(dict[affsp.paralysis])
        end
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        affsp.paralysis = nil
      end,

      onclear = function ()
        affsp.paralysis = nil
      end,

      onstart = function ()
        send("fling paralysis", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (withaff) -- ie, "darkshade" - add the additional aff if we have paralysis
        -- disabled, as fling no longer works and illusions are not so prevalent
        if true then
        -- if paragraph_length > 2 or (not (bals.balance and bals.equilibrium) and not conf.waitparalysisai) then -- if it's not an illusion for sure, or if we have waitparalysisai off and don't have both balance/eq, accept it as paralysis right now
          addaff(dict.paralysis)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          killaction(dict.checkparalysis.misc)
          if withaff then addaff(dict[withaff]) end
        else -- else, it gets added to be checked later if we have waitparalysisai on and don't have balance or eq
          affsp.paralysis = withaff or true
        end
      end
    },
  },

  checkimpatience = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affsp.impatience and not affs.sleep and bals.focus and conf.focus) or false
      end,

      oncompleted = function () end,

      impatient = function ()
        if not affs.impatience then
          addaff(dict.impatience)
          echof("Looks like the impatience is real.")
        end

        affsp.impatience = nil
      end,

      -- if serverside cures impatience before we can even validate it, cancel it
      oncancel = function ()
        affsp.impatience = nil
        killaction (dict.checkimpatience.misc)
      end,

      onclear = function ()
        if affsp.impatience then
          lostbal_focus()
          if affsp.impatience ~= "quiet" then
            echof("The impatience earlier was actually an illusion, ignoring it.")
          end
          affsp.impatience = nil
        end
      end,

      onstart = function ()
        send("focus", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (option)
        if paragraph_length > 2 then
          addaff(dict.impatience)
          killaction (dict.checkimpatience.misc)
        else
          affsp.impatience = option and option or true
        end
      end
    },
  },

  checkasthma = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affsp.asthma and conf.breath and bals.balance and bals.equilibrium) or false
      end,

      oncompleted = function () end,

      weakbreath = function ()
        addaff(dict.asthma)
        local r = findbybal("smoke")
        if r then
          killaction(dict[r.action_name].smoke)
        end

        if dict.relapsing.saw_with_checkable == "asthma" then
          dict.relapsing.saw_with_checkable = nil
          addaff(dict.relapsing)
        end

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        affsp.asthma = nil
        codepaste.badaeon()
      end,

      onclear = function ()
        affsp.asthma = nil
      end,

      onstart = function ()
        send("hold breath", conf.commandecho)
      end
    },
    smoke = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affsp.asthma and not dict.checkasthma.misc.isadvisable() and codepaste.smoke_valerian_pipe()) or false
      end,

      oncompleted = function ()
        lostbal_smoke()
      end,

      badlungs = function ()
        addaff(dict.asthma)
        local r = findbybal("smoke")
        if r then
          killaction(dict[r.action_name].smoke)
        end

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        affsp.asthma = nil
      end,

      -- mucous can hit when we aren't even afflicted, so it's moot. Have to wait for it to clear up
      mucous = function()
      end,

      onclear = function ()
        affsp.asthma = nil
        lostbal_smoke()
      end,

      empty = function()
        affsp.asthma = nil
        lostbal_smoke()
      end,

      smokecure = {"valerian", "realgar"},
      onstart = function ()
        send("smoke " .. pipes.valerian.id, conf.commandecho)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (oldhp)
      if paragraph_length > 2 or (oldhp and stats.currenthealth < oldhp) or (paragraph_length == 2 and find_until_last_paragraph("aura of weapons rebounding disappears", "substring")) then
          addaff(dict.asthma)
          local r = findbybal("smoke")
          if r then
            killaction(dict[r.action_name].smoke)
          end

          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          killaction (dict.checkasthma.misc)

          -- if we were checking and we got a verified aff, kill verification
          if actions.checkasthma_smoke then
            killaction (dict.checkasthma.smoke)
          end
        else
          affsp.asthma = true
        end
      end
    },
  },

  checkhypersomnia = {
    description = "anti-illusion check for hypersomnia",
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affsp.hypersomnia and not affs.sleep) or false
      end,

      oncompleted = function () end,

      hypersomnia = function ()
        addaff(dict.hypersomnia)

        affsp.hypersomnia = nil
      end,

      onclear = function ()
        affsp.hypersomnia = nil
      end,

      onstart = function ()
        send("insomnia", conf.commandecho)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function ()
        -- can't check hypersomnia with insomina up - it'll give the insomnia
        -- def line
        if paragraph_length > 2 or defc.insomnia then
          addaff(dict.hypersomnia)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          killaction(dict.checkhypersomnia.misc)
        else
          affsp.hypersomnia = true
        end
      end
    },
  },

  checkstun = {
    templifevision = false, -- stores the lifevision actions that will be wiped until confirmed
    tempactions = false, -- stores the actions queue items that will be wiped until confirmed
    time = 0,
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affsp.stun) or false
      end,

      oncompleted = function (data)
        -- 'fromstun' is given to us if we just had started checking for stun with checkstun_misc, and stun wore off before we could finish - for this rare scenario, we complete checkstun
        if data ~= "fromstun" then dict.stun.aff.oncompleted(dict.checkstun.time) end
        dict.checkstun.time = 0
        affsp.stun = nil
        tempTimer(0, function ()
          if not dict.checkstun.templifevision then return end

          lifevision.l = deepcopy(dict.checkstun.templifevision)
          dict.checkstun.templifevision = nil

          if lifevision.l.checkstun_aff then
            lifevision.l:set("checkstun_aff", nil)
          end

          for k,v in dict.checkstun.tempactions:iter() do
            if actions[k] then
              debugf("%s already exists, overwriting it", k)
            else
              debugf("re-added %s", k)
            end

            actions[k] = v
          end

          dict.checkstun.tempactions = nil
          send_in_the_gnomes()
        end)
      end,

      onclear = function ()
        affsp.stun = nil
        dict.checkstun.templifevision = nil
        dict.checkstun.tempactions = nil
      end,

      onstart = function ()
        send("eat something", false)
      end
    },
    aff = {
      -- this is an affliction for svo's purposes, but not in the game. Although it would be best if the 'aff' balance was replaced with something else
      notagameaff = true,
      oncompleted = function (num)
      if paragraph_length > 2 then
          dict.stun.aff.oncompleted()
          killaction (dict.checkstun.misc)
        elseif not affs.sleep and not conf.paused then -- let autodetection take care of after we wake up. otherwise, a well timed stun & stun symptom on awake can trick us. if paused, let it through as well, because we don't want to kill affs
          affsp.stun = true
          dict.checkstun.time = num
          dict.checkstun.templifevision = deepcopy(lifevision.l)
          dict.checkstun.tempactions = deepcopy(actions)
          sk.stopprocessing = true
        end
      end
    },
  },

  checkwrithes = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (next(affsp) and ((affsp.impale and not affs.transfixed and not affs.webbed and not affs.roped) or (affsp.webbed and not affs.transfixed and not affs.roped) or affsp.transfixed)) or false
      end,

      oncompleted = function () end,

      webbily = function ()
        affsp.webbed = nil
        addaff(dict.webbed)
        signals.canoutr:emit()
      end,

      impaly = function ()
        affsp.impale = nil
        addaff(dict.impale)
        signals.canoutr:emit()
      end,

      transfixily = function ()
        affsp.transfixed = nil
        addaff(dict.transfixed)
        signals.canoutr:emit()
      end,

      onclear = function ()
        affsp.impale = nil
        affsp.webbed = nil
        affsp.transfixed = nil
      end,

      onstart = function ()
        send("outr", false)
      end
    },
    aff = {
      notagameaff = true,
      oncompleted = function (which)
        if paragraph_length > 2 then
          addaff(dict[which])
          killaction (dict.checkwrithes.misc)
        else
          affsp[which] = true
        end
      end,

      impale = function (oldhp)
        if (oldhp and stats.currenthealth < oldhp) then
          addaff(dict.impale)
          signals.canoutr:emit()
        else
          affsp.impale = true
        end
      end
    }
  },
  amnesia = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (affs.amnesia) or false
      end,

      oncompleted = function ()
      end,

      onstart = function ()
        send("touch stuff", conf.commandecho)
        removeaff("amnesia")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.amnesia)

        -- cancel what we were doing, do it again
        if sys.sync then
          local result
          for balance,actions in pairs(bals_in_use) do
            if balance ~= "waitingfor" and balance ~= "gone" and balance ~= "aff" and next(actions) then result = select(2, next(actions)) break end
          end
          if result then
            killaction(dict[result.action_name][result.balance])
          end

          svo.conf.send_bypass = true
          send("touch stuff", conf.commandecho)
          svo.conf.send_bypass = false
        end
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("amnesia")
      end,
    }
  },

  -- uncurable
  stun = {
    waitingfor = {
      customwait = 1,

      isadvisable = function ()
        return false
      end,

      ontimeout = function ()
        removeaff("stun")

        if dict.checkstun.templifevision then
#if DEBUG then
          debugf("stun timed out = restoring checkstun lifevisions")
#end
          dict.checkstun.misc.oncompleted("fromstun")
          make_gnomes_work()
        end

      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("stun")

        if dict.checkstun.templifevision then
#if DEBUG then
          debugf("stun finished = restoring checkstun lifevisions")
#end
          dict.checkstun.misc.oncompleted("fromstun")
        end
      end
    },
    aff = {
      oncompleted = function (num)
        if affs.stun then return end

        dict.stun.waitingfor.customwait = (num and num ~= 0) and num or 1
        addaff(dict.stun)
        doaction(dict.stun.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("stun")
        killaction (dict.stun.waitingfor)
      end,
    },
    onremoved = function () donext() end
  },
  unconsciousness = {
    waitingfor = {
      customwait = 7,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        removeaff("unconsciousness")
        make_gnomes_work()
      end,

      oncompleted = function ()
        removeaff("unconsciousness")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.unconsciousness)
        if not actions.unconsciousness_waitingfor then doaction(dict.unconsciousness.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("unconsciousness")
        killaction (dict.unconsciousness.waitingfor)
      end,
    },
    onremoved = function () donext() end
  },
  swellskin = { -- eating any herb cures it
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("swellskin")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.swellskin)
        if not actions.swellskin_waitingfor then doaction(dict.swellskin.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("swellskin")
        killaction (dict.swellskin.waitingfor)
      end,
    }
  },
  pinshot = {
    waitingfor = {
      customwait = 20, -- lasts 18s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        removeaff("pinshot")
        make_gnomes_work()
      end,

      oncompleted = function ()
        removeaff("pinshot")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.pinshot)
        if not actions.pinshot_waitingfor then doaction(dict.pinshot.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("pinshot")
        killaction (dict.pinshot.waitingfor)
      end,
    }
  },
  dehydrated = {
    waitingfor = {
      customwait = 45, -- lasts 45s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        removeaff("dehydrated")
        make_gnomes_work()
      end,

      oncompleted = function ()
        removeaff("dehydrated")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.dehydrated)
        if not actions.dehydrated_waitingfor then doaction(dict.dehydrated.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("dehydrated")
        killaction (dict.dehydrated.waitingfor)
      end,
    }
  },
  timeflux = {
    waitingfor = {
      customwait = 50, -- lasts 50s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        removeaff("timeflux")
        make_gnomes_work()
      end,

      oncompleted = function ()
        removeaff("timeflux")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.timeflux)
        if not actions.timeflux_waitingfor then doaction(dict.timeflux.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("timeflux")
        killaction (dict.timeflux.waitingfor)
      end,
    }
  },
  inquisition = {
    waitingfor = {
      customwait = 30, -- ??

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("inquisition")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.inquisition)
        if not actions.inquisition_waitingfor then doaction(dict.inquisition.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("inquisition")
        killaction (dict.inquisition.waitingfor)
      end,
    }
  },
  lullaby = {
    waitingfor = {
      customwait = 45, -- takes 45s

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("lullaby")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.lullaby)
        if not actions.lullaby_waitingfor then doaction(dict.lullaby.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("lullaby")
        killaction (dict.lullaby.waitingfor)
      end,
    }
  },
  corrupted = {
    waitingfor = {
      customwait = 999, -- time increases

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("corrupted")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.corrupted)
        if not actions.corrupted_waitingfor then doaction(dict.corrupted.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("corrupted")
        killaction (dict.corrupted.waitingfor)
      end,
    }
  },
  mucous = {
    waitingfor = {
      customwait = 6,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("mucous")
      end,

      ontimeout = function()
        removeaff("mucous")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.mucous)
        if not actions.mucous_waitingfor then doaction(dict.mucous.waitingfor) end

        local r = findbybal("smoke")
        if r then
          killaction(dict[r.action_name].smoke)
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("mucous")
        killaction (dict.mucous.waitingfor)
      end,
    }
  },
  phlogistication = {
    waitingfor = {
      customwait = 999, -- time increases

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("phlogistication")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.phlogistication)
        if not actions.phlogistication_waitingfor then doaction(dict.phlogistication.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("phlogistication")
        killaction (dict.phlogistication.waitingfor)
      end,
    }
  },
  vitrification = {
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("vitrification")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.vitrification)
        if not actions.vitrification_waitingfor then doaction(dict.vitrification.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("vitrification")
        killaction (dict.vitrification.waitingfor)
      end,
    }
  },

  icing = {
    waitingfor = {
      customwait = 30, -- ??

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("icing")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.icing)
        if not actions.icing_waitingfor then doaction(dict.icing.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("icing")
        killaction (dict.icing.waitingfor)
      end,
    }
  },
  burning = {
    waitingfor = {
      customwait = 30, -- ??

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("burning")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.burning)
        if not actions.burning_waitingfor then doaction(dict.burning.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("burning")
        killaction (dict.burning.waitingfor)
      end,
    }
  },
  voided = {
    waitingfor = {
      customwait = 20, -- lasts 20s tops, 15s in some stances. out-times multiple pommelstrikes

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("voided")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.voided)
        codepaste.badaeon()
        if not actions.voided_waitingfor then doaction(dict.voided.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("voided")
        killaction (dict.voided.waitingfor)
      end,
    }
  },
  hamstring = {
    waitingfor = {
      customwait = 10,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      ontimeout = function()
        if affs.hamstring then
          removeaff("hamstring")
          echof("Hamstring should have worn off by now, removing it.")
        end
      end,

      oncompleted = function ()
        removeaff("hamstring")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hamstring)
        if not actions.hamstring_waitingfor then doaction(dict.hamstring.waitingfor) end
      end,

      renew = function ()
        addaff(dict.hamstring)

        -- hamstrings timer gets renewed on hit
        if actions.hamstring_waitingfor then
          killaction (dict.hamstring.waitingfor)
        end
        doaction(dict.hamstring.waitingfor)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("hamstring")
        killaction (dict.hamstring.waitingfor)
      end,
    }
  },
  galed = {
    waitingfor = {
      customwait = 10,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("galed")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.galed)
        if not actions.galed_waitingfor then doaction(dict.galed.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("galed")
        killaction (dict.galed.waitingfor)
      end,
    }
  },
  rixil = {
    -- will double the cooldown period of the next focus ability.
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("rixil")
        killaction (dict.rixil.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.rixil)
        if actions.rixil_waitingfor then killaction(dict.rixil.waitingfor) end
        doaction(dict.rixil.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("rixil")
        killaction (dict.rixil.waitingfor)
      end,
    }
  },
  hecate = {
    waitingfor = {
      customwait = 22, -- seems to last at least 18s per log

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
        removeaff("hecate")
        killaction (dict.hecate.waitingfor)
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("hecate")
        killaction (dict.hecate.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hecate)
        if actions.hecate_waitingfor then killaction(dict.hecate.waitingfor) end
        doaction(dict.hecate.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("hecate")
        killaction (dict.hecate.waitingfor)
      end,
    }
  },
  palpatar = {
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("palpatar")
        killaction (dict.palpatar.waitingfor)
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.palpatar)
        if actions.palpatar_waitingfor then killaction(dict.palpatar.waitingfor) end
        doaction(dict.palpatar.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("palpatar")
        killaction (dict.palpatar.waitingfor)
      end,
    }
  },
  -- extends tree balance by 10s now
  ninkharsag = {
    waitingfor = {
      customwait = 60, -- it lasts a minute

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
        removeaff("ninkharsag")
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("ninkharsag")
        killaction (dict.ninkharsag.waitingfor)
      end,

    },
    aff = {
      oncompleted = function ()
        addaff(dict.ninkharsag)
        if actions.ninkharsag_waitingfor then killaction(dict.ninkharsag.waitingfor) end
        doaction(dict.ninkharsag.waitingfor)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("ninkharsag")
        killaction (dict.ninkharsag.waitingfor)
      end,

      -- anti-illusion-checked aff hiding. in 'gone' because 'aff' resets the timer with checkaction, waitingfor has some other effect
      hiddencures = function (amount)
        local curableaffs = svo.gettreeableaffs()

        -- if we saw more ninkharsag lines than affs we've got, we can remove the affs safely
        if amount >= #curableaffs then
          removeaff(curableaffs)
        else
          -- otherwise add an unknown aff - so we eventually diagnose to see what is our actual aff status like.
          -- this does mess with the aff counts, but it is better than not diagnosing ever.
          codepaste.addunknownany()
        end
      end
    }
  },
  cadmus = {
    -- focusing will give one of: lethargy, clumsiness, haemophilia, healthleech, sensitivity, darkshade
    waitingfor = {
      customwait = 999,

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("cadmus")
        killaction (dict.cadmus.waitingfor)
      end
    },
    aff = {
      oncompleted = function (oldmaxhp)
        addaff(dict.cadmus)
        if actions.cadmus_waitingfor then killaction(dict.cadmus.waitingfor) end
        doaction(dict.cadmus.waitingfor)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("cadmus")
        killaction (dict.cadmus.waitingfor)
      end,
    }
  },
  spiritdisrupt = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.spiritdisrupt and not affs.madness and
          not doingaction("spiritdisrupt")) or false
      end,

      oncompleted = function ()
        removeaff("spiritdisrupt")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.spiritdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.spiritdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("spiritdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  airdisrupt = {
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.airdisrupt and not affs.spiritdisrupt) or false
      end,

      oncompleted = function ()
        removeaff("airdisrupt")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.airdisrupt and not doingaction("airdisrupt")) or false
      end,

      oncompleted = function ()
        removeaff("airdisrupt")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.airdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.airdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("airdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  earthdisrupt = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.earthdisrupt and not doingaction("earthdisrupt")) or false
      end,

      oncompleted = function ()
        removeaff("earthdisrupt")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.earthdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.earthdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("earthdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  waterdisrupt = {
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.waterdisrupt and not affs.spiritdisrupt) or false
      end,

      oncompleted = function ()
        removeaff("waterdisrupt")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.waterdisrupt and not doingaction("waterdisrupt")) or false
      end,

      oncompleted = function ()
        removeaff("waterdisrupt")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.waterdisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.waterdisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("waterdisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  firedisrupt = {
    focus = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.firedisrupt and not affs.spiritdisrupt) or false
      end,

      oncompleted = function ()
        removeaff("firedisrupt")
        lostbal_focus()
      end,

      action = "focus",
      onstart = function ()
        send("focus", conf.commandecho)
      end,

      empty = function ()
        lostbal_focus()

        empty.focus()
      end
    },
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return (affs.firedisrupt and not doingaction("firedisrupt")) or false
      end,

      oncompleted = function ()
        removeaff("firedisrupt")
        lostbal_herb()
      end,

      eatcure = {"lobelia", "argentum"},
      onstart = function ()
        eat(dict.firedisrupt.herb)
      end,

      empty = function()
        empty.eat_lobelia()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.firedisrupt)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("firedisrupt")
        codepaste.remove_focusable()
      end,
    }
  },
  stain = {
    waitingfor = {
      customwait = 60*2+20, -- lasts 2min, but varies, so let's go with 140s

      isadvisable = function ()
        return false
      end,

      ontimeout = function()
        removeaff("stain")
        echof("Taking a guess, I think stain expired by now.")
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("stain")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function (oldmaxhp)
        -- oldmaxhp doesn't come from diag, it is optional
        if (not conf.aillusion) or (oldmaxhp and (stats.maxhealth < oldmaxhp)) then
          addaff(dict.stain)
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          codepaste.badaeon()
          if actions.stain_waitingfor then killaction(dict.stain.waitingfor) end
          doaction(dict.stain.waitingfor)
        end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("stain")
        killaction (dict.stain.waitingfor)
      end,
    }
  },
  depression = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.depression or false
      end,

      oncompleted = function ()
        removeaff("depression")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.depression.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.depression)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("depression")
      end,
    }
  },
  parasite = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.parasite or false
      end,

      oncompleted = function ()
        removeaff("parasite")
        lostbal_herb()
      end,

      eatcure = {"kelp", "aurum"},
      onstart = function ()
        eat(dict.parasite.herb)
      end,

      empty = function()
        empty.eat_kelp()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.parasite)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("parasite")
      end,
    }
  },
  retribution = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.retribution or false
      end,

      oncompleted = function ()
        removeaff("retribution")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.retribution.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.retribution)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("retribution")
      end,
    }
  },
  shadowmadness = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.shadowmadness or false
      end,

      oncompleted = function ()
        removeaff("shadowmadness")
        lostbal_herb()
      end,

      eatcure = {"goldenseal", "plumbum"},
      onstart = function ()
        eat(dict.shadowmadness.herb)
      end,

      empty = function()
        empty.eat_goldenseal()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.shadowmadness)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("shadowmadness")
      end,
    }
  },
  timeloop = {
    herb = {
      aspriority = 0,
      spriority = 0,

      isadvisable = function ()
        return affs.timeloop or false
      end,

      oncompleted = function ()
        removeaff("timeloop")
        lostbal_herb()
      end,

      eatcure = {"bellwort", "cuprum"},
      onstart = function ()
        eat(dict.timeloop.herb)
      end,

      empty = function()
        empty.eat_bellwort()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.timeloop)
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("timeloop")
      end,
    }
  },
  degenerate = {
    waitingfor = {
      customwait = 0, -- seems to last 6 seconds per degenerate affliction when boosted, set below

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("degenerate")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        local timeout = 0
        for _, aff in ipairs(empty.degenerateaffs) do
          timeout = timeout + (affs[aff] and 7 or 0)
        end
        dict.degenerate.waitingfor.customwait = timeout
        addaff(dict.degenerate)
        if not actions.degenerate_waitingfor then doaction(dict.degenerate.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("degenerate")
        killaction (dict.degenerate.waitingfor)
      end,
    }
  },
  deteriorate = {
    waitingfor = {
      customwait = 0, -- seems to last 6 seconds per deteriorate affliction when boosted, set below

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("deteriorate")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        local timeout = 0
        for _, aff in ipairs(empty.deteriorateaffs) do
          timeout = timeout + (affs[aff] and 7 or 0)
        end
        dict.deteriorate.waitingfor.customwait = timeout
        addaff(dict.deteriorate)
        if not actions.deteriorate_waitingfor then doaction(dict.deteriorate.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("deteriorate")
        killaction (dict.deteriorate.waitingfor)
      end,
    }
  },
  hatred = {
    waitingfor = {
      customwait = 15,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("hatred")
        make_gnomes_work()
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.hatred)
        if not actions.hatred_waitingfor then doaction(dict.hatred.waitingfor) end
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("hatred")
        killaction (dict.hatred.waitingfor)
      end,
    }
  },
  paradox = {
    count = 0,
    blocked_herb = "",
    boosted = {
      oncompleted = function ()
        dict.paradox.aff.count = 10
        updateaffcount(dict.paradox)
      end
    },
    weakened = {
      oncompleted = function ()
        codepaste.remove_stackableaff("paradox", true)
      end
    },
    aff = {
      oncompleted = function (herb)
        dict.paradox.count = 5
        dict.paradox.blocked_herb = herb
        addaff(dict.paradox)  
        affl["paradox"].herb = herb
        updateaffcount(dict.paradox)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("paradox")
        dict.paradox.count = 0
        dict.paradox.blocked_herb = ""
      end,
    }
  },
  retardation = {
    waitingfor = {
      isadvisable = function ()
        return false
      end,

      onstart = function () end,

      oncompleted = function ()
        removeaff("retardation")
      end
    },
    aff = {
      oncompleted = function ()
        if not affs.retardation then
          addaff(dict.retardation)
          sk.checkaeony()
          signals.aeony:emit()
          signals.newroom:unblock(sk.check_retardation)
        end
      end,
    },
    gone = {
      oncompleted = function ()
        removeaff("retardation")
      end,
    },
    onremoved = function ()
      affsp.retardation = nil
      sk.checkaeony()
      signals.aeony:emit()
      signals.newroom:block(sk.check_retardation)
    end,
    onadded = function()
      signals.newroom:unblock(sk.check_retardation)
    end
  },
  nomana = {
    waitingfor = {
      customwait = 30,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,
      ontimeout = function ()
        echo"\n"echof("Hm, maybe we have enough mana for mana skills now...")
        killaction (dict.nomana.waitingfor)
        make_gnomes_work()
      end
    }
  },
#if skills.metamorphosis then
  cantmorph = {
    waitingfor = {
      customwait = 30,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,
      ontimeout = function ()
        removeaff("cantmorph")
        echo"\n"echof("We can probably morph again now.")
      end,

      oncompleted = function ()
        removeaff("cantmorph")
      end
    },
    aff = {
      oncompleted = function ()
        addaff(dict.cantmorph)
      end
    },
    gone = {
      oncompleted = function ()
        removeaff("cantmorph")
      end,
    }
  },
#end
#if skills.metamorphosis or skills.kaido then
  cantvitality = {
    waitingfor = {
      customwait = 122,

      isadvisable = function ()
        return false
      end,

      onstart = function () end,
      ontimeout = function ()
        if not defc.vitality then
          echo"\n"echof("We can vitality again now.")
          make_gnomes_work()
        end
      end,

      oncompleted = function ()
        dict.cantvitality.waitingfor.ontimeout()
      end
    },
    gone = {
      oncompleted = function ()
        killaction (dict.cantvitality.waitingfor)
      end
    }
  },
#end

-- random actions that should be protected by AI
  givewarning = {
    happened = {
      oncompleted = function (tbl)
        if tbl and tbl.initialmsg then
          echo"\n\n"
          echof("Careful: %s", tbl.initialmsg)
          echo"\n"
        end

        if tbl and tbl.prefixwarning then
          local duration = tbl.duration or 4
          local startin = tbl.startin or 0
          cnrl.warning = tbl.prefixwarning or ""

          -- timer for starting
          if not conf.warningtype then return end

          tempTimer(startin, function ()

            if cnrl.warnids[tbl.prefixwarning] then killTrigger(cnrl.warnids[tbl.prefixwarning]) end

              cnrl.warnids[tbl.prefixwarning] = tempRegexTrigger('^', [[
                if (($(sys).conf.warningtype == "prompt" and isPrompt()) or $(sys).conf.warningtype == "all" or $(sys).conf.warningtype == "right") and getCurrentLine() ~= "" and not $(sys).gagline then
                  svo.prefixwarning()
                end
              ]])
            end)

          -- timer for ending
          tempTimer(startin+duration, function () killTrigger(cnrl.warnids[tbl.prefixwarning]) end)
        end
      end
    }
  },
  stolebalance = {
    happened = {
      oncompleted = function (balance)
        $(sys)["lostbal_"..balance]()
      end
    }
  },
#if skills.weaponmastery then
  footingattack = {
    description = "Tracks attacks suitable for use with balanceless recover footing",
    happened = {
      oncompleted = function ()
        sk.didfootingattack = true
      end
    }
  },
#end
  gotbalance = {
    happened = {
      tempmap = {},
      oncompleted = function ()
        for _, balance in ipairs(dict.gotbalance.happened.tempmap) do
          if not bals[balance] then
            bals[balance] = true

            raiseEvent("svo got balance", balance)

            endbalancewatch(balance)

            -- this concern should be separated into its own
            if balance == "tree" then
              killTimer(sys.treetimer)
            end
          end
        end
        dict.gotbalance.happened.tempmap = {}
      end,

      oncancel = function ()
        dict.gotbalance.happened.tempmap = {}
      end
    }
  },
  gothit = {
    happened = {
      tempmap = {},
      oncompleted = function ()
        for name, class in pairs(dict.gothit.happened.tempmap) do
          if name == '?' then
            raiseEvent("svo got hit by", class)
          else
            raiseEvent("svo got hit by", class, name)
          end
        end
        dict.gothit.happened.tempmap = {}
      end,

      oncancel = function ()
        dict.gothit.happened.tempmap = {}
      end
    }
  },
#if skills.aeonics then
  age = {
    happened = {
      onstart = function () end,

      oncompleted = function(amount)
        if amount > 1400 then
          ignore_illusion("Age went over the possible max")
          stats.age = 0
        elseif amount == 0 then
          if dict.age.happened.timer then killTimer(dict.age.happened.timer) end
          stats.age = 0
          dict.age.happened.timer = nil
        else
          if dict.age.happened.timer then killTimer(dict.age.happened.timer) end
          dict.age.happened.timer = tempTimer(6 + getping(), function()
            ignore_illusion("Age tick timed out")
            stats.age = 0
          end)
          stats.age = amount
        end
      end
    }
  },
#end

-- general defences
  rebounding = {
    blocked = false, -- we need to block off in blackout, because otherwise we waste sips
    smoke = {
      aspriority = 137,
      spriority = 261,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].rebounding and not defc.rebounding) or (conf.keepup and defkeepup[defs.mode].rebounding and not defc.rebounding)) and codepaste.smoke_skullcap_pipe() and not doingaction("waitingonrebounding") and not dict.rebounding.blocked) or false
      end,

      oncompleted = function ()
        doaction(dict.waitingonrebounding.waitingfor)
        sk.skullcap_smokepuff()
        lostbal_smoke()
      end,

      alreadygot = function ()
        defences.got("rebounding")
        sk.skullcap_smokepuff()
        lostbal_smoke()
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        dict.rebounding.blocked = true
        tempTimer(3, function () dict.rebounding.blocked = false; make_gnomes_work() end)
      end,

      smokecure = {"skullcap", "malachite"},
      onstart = function ()
        send("smoke " .. pipes.skullcap.id, conf.commandecho)
      end,

      empty = function ()
        dict.rebounding.smoke.oncompleted()
      end
    }
  },
  waitingonrebounding = {
    spriority = 0,
    waitingfor = {
      customwait = 9,

      onstart = function () raiseEvent("svo rebounding start") end,

      oncompleted = function ()
        defences.got("rebounding")
      end,

      deathtarot = function () -- nothing happens! It just doesn't come up :/
      end,

      -- expend torso cancels rebounding coming up
      expend = function()
        if actions.waitingonrebounding_waitingfor then
          killaction(dict.waitingonrebounding.waitingfor)
        end
      end,
    }
  },
  frost = {
    purgative = {
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].frost and not defc.frost) or (conf.keepup and defkeepup[defs.mode].frost and not defc.frost)) or false
      end,

      oncompleted = function ()
        defences.got("frost")
#if skills.metamorphosis then
        defences.got("temperance")
#end
      end,

      sipcure = {"frost", "endothermia"},

      onstart = function ()
        sip(dict.frost.purgative)
      end,

      empty = function ()
        defences.got("frost")
      end,

      noeffect = function()
        defences.got("frost")
      end
    },
    gone = {
      oncompleted = function ()
#if skills.metamorphosis then
        defences.lost("temperance")
#end
      end
    }
  },
  venom = {
    gamename = "poisonresist",
    purgative = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].venom and not defc.venom) or (conf.keepup and defkeepup[defs.mode].venom and not defc.venom)) or false
      end,

      oncompleted = function ()
        defences.got("venom")
      end,

      noeffect = function()
        defences.got("venom")
      end,

      sipcure = {"venom", "toxin"},

      onstart = function ()
        sip(dict.venom.purgative)
      end,

      empty = function ()
        defences.got("venom")
      end
    }
  },
  levitation = {
    gamename = "levitating",
    purgative = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].levitation and not defc.levitation) or (conf.keepup and defkeepup[defs.mode].levitation and not defc.levitation)) or false
      end,

      oncompleted = function ()
        defences.got("levitation")
      end,

      noeffect = function()
        defences.got("levitation")
      end,

      sipcure = {"levitation", "hovering"},

      onstart = function ()
        sip(dict.levitation.purgative)
      end,

      empty = function ()
        defences.got("levitation")
      end
    }
  },
  speed = {
    blocked = false, -- we need to block off in blackout, because otherwise we waste sips
    purgative = {
      aspriority = 8,
      spriority = 265,
      def = true,

      isadvisable = function ()
        return (not defc.speed and ((sys.deffing and defdefup[defs.mode].speed) or (conf.keepup and defkeepup[defs.mode].speed)) and not doingaction("curingspeed") and not doingaction("speed") and not dict.speed.blocked and not me.manualdefcheck) or false
      end,

      oncompleted = function (def)
        if def then defences.got("speed")
        else
          if affs.palpatar then
            dict.curingspeed.waitingfor.customwait = 10
          else
            dict.curingspeed.waitingfor.customwait = 7
          end

          doaction(dict.curingspeed.waitingfor)
        end
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        dict.speed.blocked = true
        tempTimer(3, function () dict.speed.blocked = false; make_gnomes_work() end)
      end,

      noeffect = function()
        defences.got("speed")
      end,

      sipcure = {"speed", "haste"},

      onstart = function ()
        sip(dict.speed.purgative)
      end,

      empty = function ()
        dict.speed.purgative.oncompleted ()
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("speed")
      end
    }
  },
  curingspeed = {
    spriority = 0,
    waitingfor = {
      customwait = 7,

      oncompleted = function ()
        defences.got("speed")
      end,

      ontimeout = function ()
        if defc.speed then return end

        if (sys.deffing and defdefup[defs.mode].speed) or (conf.keepup and defkeepup[defs.mode].speed) then
          echof("Warning - speed didn't come up in 7s, checking 'def'.")
          me.manualdefcheck = true
        end
      end,

      onstart = function () end
    }
  },
  sileris = {
    gamename = "fangbarrier",
    applying = "",
    misc = {
      aspriority = 8,
      spriority = 265,
      def = true,

      isadvisable = function ()
        return (not defc.sileris and ((sys.deffing and defdefup[defs.mode].sileris) or (conf.keepup and defkeepup[defs.mode].sileris)) and not doingaction("waitingforsileris") and not doingaction("sileris") and not affs.paralysis and not affs.slickness and not me.manualdefcheck) or false
      end,

      oncompleted = function (def)
        if def and not defc.sileris then defences.got("sileris")
        else doaction(dict.waitingforsileris.waitingfor) end
      end,

      slick = function()
        addaff(dict.slickness)
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        dict.sileris.blocked = true
        tempTimer(3, function () dict.sileris.blocked = false; make_gnomes_work() end)
      end,

      -- special case for 'missing herb' trig
      eatcure = {"sileris", "quicksilver"},
      applycure = {"sileris", "quicksilver"},
      actions = {"apply sileris", "apply quicksilver"},
      onstart = function ()
        local use = "sileris"

        if conf.curemethod and conf.curemethod ~= "conconly" and (

          conf.curemethod == "transonly" or

          (conf.curemethod == "preferconc" and
            -- we don't have in inventory, but do have alchemy in inventory, use alchemy
             (not (rift.invcontents.sileris > 0) and (rift.invcontents.quicksilver > 0)) or
              -- or if we don't have the conc cure in rift either, use alchemy
             (not (rift.riftcontents.sileris > 0))) or

          (conf.curemethod == "prefertrans" and
            (rift.invcontents.quicksilver > 0
              or (not (rift.invcontents.sileris > 0) and (rift.riftcontents.quicksilver > 0)))) or

          -- prefercustom, and we either prefer alchy and have it, or prefer conc and don't have it
          (conf.curemethod == "prefercustom" and (
            (me.curelist[use] == use and rift.riftcontents[use] <= 0)
              or
            (me.curelist[use] == "quicksilver" and rift.riftcontents["quicksilver"] > 0)
          ))

          ) then
            use = "quicksilver"
        end

        sys.last_used["sileris_misc"] = use

        dict.sileris.applying = use
        if rift.invcontents[use] > 0 then
          send("outr "..use, conf.commandecho)
          send("apply "..use, conf.commandecho)
        else
          send("outr "..use, conf.commandecho)
          send("apply "..use, conf.commandecho)
        end
      end,

      empty = function ()
        dict.sileris.misc.oncompleted()
      end
    },
    gone = {
      oncompleted = function (line_spotted_on)
        if not conf.aillusion or not line_spotted_on or (line_spotted_on+1 == getLastLineNumber("main")) then
          defences.lost("sileris")
        end
      end,

      camusbite = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          defences.lost("sileris")
        end
      end,

      sumacbite = function (oldhp)
        if not conf.aillusion or (not affs.recklessness and stats.currenthealth < oldhp) then
          defences.lost("sileris")
        end
      end,
    }
  },
  waitingforsileris = {
    spriority = 0,
    waitingfor = {
      customwait = 8,

      oncompleted = function ()
        defences.got("sileris")
      end,

      ontimeout = function ()
        if defc.sileris then return end

        if (sys.deffing and defdefup[defs.mode].sileris) or (conf.keepup and defkeepup[defs.mode].sileris) then
          echof("Warning - sileris isn't back yet, we might've been tricked. Going to see if we get bitten.")
          local oldsileris = defc.sileris
          defc.sileris = "unsure"
          if oldsileris ~= defc.sileris then raiseEvent("svo got def", "sileris") end
        end
      end,

      onstart = function () end
    }
  },
  deathsight = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.deathsight and (not conf.deathsight or not can_usemana()) and ((sys.deffing and defdefup[defs.mode].deathsight) or (conf.keepup and defkeepup[defs.mode].deathsight)) and not doingaction("deathsight")) or false
      end,

      oncompleted = function ()
        defences.got("deathsight")
      end,

      eatcure = {"skullcap", "azurite"},
      onstart = function ()
        eat(dict.deathsight.herb)
      end,

      empty = function()
        defences.got("deathsight")
      end
    },
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (not defc.deathsight and conf.deathsight and can_usemana() and not doingaction("deathsight") and ((sys.deffing and defdefup[defs.mode].deathsight) or (conf.keepup and defkeepup[defs.mode].deathsight)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("deathsight")
      end,

      action = "deathsight",
      onstart = function ()
        send("deathsight", conf.commandecho)
      end
    },
  },
  thirdeye = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].thirdeye and not defc.thirdeye) or (conf.keepup and defkeepup[defs.mode].thirdeye and not defc.thirdeye)) and not doingaction("thirdeye") and not (conf.thirdeye and can_usemana())) or false
      end,

      oncompleted = function ()
        defences.got("thirdeye")
      end,

      eatcure = {"echinacea", "dolomite"},
      onstart = function ()
        eat(dict.thirdeye.herb)
      end,

      empty = function()
        defences.got("thirdeye")
      end
    },
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.thirdeye and can_usemana() and not doingaction("thirdeye") and ((sys.deffing and defdefup[defs.mode].thirdeye and not defc.thirdeye) or (conf.keepup and defkeepup[defs.mode].thirdeye and not defc.thirdeye))) or false
      end,

      -- by default, oncompleted means a clot went through okay
      oncompleted = function ()
        defences.got("thirdeye")
      end,

      action = "thirdeye",
      onstart = function ()
        send("thirdeye", conf.commandecho)
      end
    },
  },
  insomnia = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].insomnia and not defc.insomnia) or (conf.keepup and defkeepup[defs.mode].insomnia and not defc.insomnia)) and not doingaction("insomnia") and not (conf.insomnia and can_usemana()) and not affs.hypersomnia) or false
      end,

      oncompleted = function ()
        defences.got("insomnia")
      end,

      eatcure = {"cohosh", "gypsum"},
      onstart = function ()
        eat(dict.insomnia.herb)
      end,

      empty = function()
        defences.got("insomnia")
      end,

      hypersomnia = function ()
        addaff(dict.hypersomnia)
      end
    },
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.insomnia and can_usemana() and not doingaction("insomnia") and ((sys.deffing and defdefup[defs.mode].insomnia and not defc.insomnia) or (conf.keepup and defkeepup[defs.mode].insomnia and not defc.insomnia)) and not affs.hypersomnia) or false
      end,

      oncompleted = function ()
        defences.got("insomnia")
      end,

      hypersomnia = function ()
        addaff(dict.hypersomnia)
      end,

      action = "insomnia",
      onstart = function ()
        send("insomnia", conf.commandecho)
      end
    },
    -- small cheat for insomnia being on diagnose
    aff = {
      oncompleted = function ()
        defences.got("insomnia")
      end
    },
    gone = {
      oncompleted = function(aff)
        defences.lost("insomnia")

        if aff and aff == "unknownany" then
          dict.unknownany.count = dict.unknownany.count - 1
          if dict.unknownany.count <= 0 then
            removeaff("unknownany")
            dict.unknownany.count = 0
          else
            updateaffcount(dict.unknownany)
          end
        elseif aff and aff == "unknownmental" then
          dict.unknownmental.count = dict.unknownmental.count - 1
          if dict.unknownmental.count <= 0 then
            removeaff("unknownmental")
            dict.unknownmental.count = 0
          else
            updateaffcount(dict.unknownmental)
          end
        end
      end,

      relaxed = function (line_spotted_on)
        if not conf.aillusion or not line_spotted_on or (line_spotted_on+1 == getLastLineNumber("main")) then
          defences.lost("insomnia")
        end
      end,
    }
  },
#if skills.chivalry or skills.striking or skills.kaido then
  fitness = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      uncurable = true,

      isadvisable = function ()
        if not (not affs.weakness and not defc.dragonform and bals.fitness and not codepaste.balanceful_defs_codepaste()) then
          return false
        end

        for name, func in pairs(fitness) do
          if not me.disabledfitnessfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function ()
        removeaff("asthma")
        lostbal_fitness()
      end,

      curedasthma = function ()
        removeaff("asthma")
        lostbal_fitness()
      end,

      weakness = function ()
        addaff(dict.weakness)

      end,

      allgood = function()
        removeaff("asthma")
      end,

      actions = {"fitness"},
      onstart = function ()
        send("fitness", conf.commandecho)
      end
    },
  },
#end
  myrrh = {
    gamename = "scholasticism",
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].myrrh and not defc.myrrh) or (conf.keepup and defkeepup[defs.mode].myrrh and not defc.myrrh))) or false
      end,

      oncompleted = function ()
        defences.got("myrrh")
      end,

      noeffect = function ()
        dict.myrrh.herb.oncompleted ()
      end,

      eatcure = {"myrrh", "bisemutum"},
      onstart = function ()
        eat(dict.myrrh.herb)
      end,

      empty = function()
        defences.got("myrrh")
      end
    },
  },
  kola = {
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].kola and not defc.kola) or (conf.keepup and defkeepup[defs.mode].kola and not defc.kola))) or false
      end,

      oncompleted = function ()
        defences.got("kola")
      end,

      noeffect = function ()
        dict.kola.herb.oncompleted ()
      end,

      eatcure = {"kola", "quartz"},
      onstart = function ()
        eat(dict.kola.herb)
      end,

      empty = function()
        defences.got("kola")
      end
    },
    gone = {
      oncompleted = function()
        if not conf.aillusion or not pflags.k then
          defences.lost("kola")
        end
      end
    }
  },
  mass = {
    gamename = "density",
    salve = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].mass and not defc.mass) or (conf.keepup and defkeepup[defs.mode].mass and not defc.mass))) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        defences.got("mass")
      end,

      -- sometimes a salve cure can get misgiagnosed on a death (from a previous apply)
      noeffect = function() end,
      empty = function() end,

      applycure = {"mass", "density"},
      actions = {"apply mass to body", "apply mass", "apply density to body", "apply density"},
      onstart = function ()
        apply(dict.mass.salve, " to body")
      end,
    },
  },
  caloric = {
    salve = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].caloric and not defc.caloric) or (conf.keepup and defkeepup[defs.mode].caloric and not defc.caloric))) or false
      end,

      oncompleted = function ()
        lostbal_salve()
        defences.got("caloric")
      end,

      noeffect = function ()
        lostbal_salve()
      end,

      -- called from shivering or frozen cure
      gotcaloricdef = function (hypothermia)
        if not hypothermia then removeaff({"frozen", "shivering"}) end
        dict.caloric.salve.oncompleted ()
      end,

      applycure = {"caloric", "exothermic"},
      actions = {"apply caloric to body", "apply caloric", "apply exothermic to body", "apply exothermic"},
      onstart = function ()
        apply(dict.caloric.salve, " to body")
      end,
    },
    gone = {
      oncompleted = function(aff)
        defences.lost("caloric")

        if aff and aff == "unknownany" then
          dict.unknownany.count = dict.unknownany.count - 1
          if dict.unknownany.count <= 0 then
            removeaff("unknownany")
            dict.unknownany.count = 0
          end
        elseif aff and aff == "unknownmental" then
          dict.unknownmental.count = dict.unknownmental.count - 1
          if dict.unknownmental.count <= 0 then
            removeaff("unknownmental")
            dict.unknownmental.count = 0
          end
        end
      end
    }
  },
  blind = {
    gamename = "blindness",
    onservereignore = function()
      -- no blind skill: ignore serverside if it's not to be deffed up atm
      -- with blind skill: ignore serverside can use skill, or if it's not to be deffed up atm
      return
#if skills.shindo then
        (conf.shindoblind and not defc.dragonform) or
#end
#if skills.kaido then
        (conf.kaidoblind and not defc.dragonform) or
#end
        not ((sys.deffing and defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind))
    end,
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not affs.scalded and
#if skills.shindo then
          (defc.dragonform or (not conf.shindoblind)) and
#end
#if skills.kaido then
          (defc.dragonform or (not conf.kaidoblind)) and
#end
        ((sys.deffing and defdefup[defs.mode].blind and not defc.blind) or (conf.keepup and defkeepup[defs.mode].blind and not defc.blind)) and not doingaction"waitingonblind") or false
      end,

      oncompleted = function ()
        defences.got("blind")
        lostbal_herb()
      end,

      noeffect = function ()
        dict.blind.herb.oncompleted()
      end,

      eatcure = {"bayberry", "arsenic"},
      onstart = function ()
        eat(dict.blind.herb)
      end,

      empty = function()
        defences.got("blind")
        lostbal_herb()
      end
    },
#if skills.shindo then
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.shindoblind and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].blind and not defc.blind) or (conf.keepup and defkeepup[defs.mode].blind and not defc.blind)) and not doingaction"waitingonblind") or false
      end,

      oncompleted = function ()
        doaction(dict.waitingonblind.waitingfor)
      end,

      action = "blind",
      onstart = function ()
        send("blind", conf.commandecho)
      end
    },
#end
#if skills.kaido then
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (conf.kaidoblind and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].blind and not defc.blind) or (conf.keepup and defkeepup[defs.mode].blind and not defc.blind)) and not doingaction"waitingonblind") or false
      end,

      oncompleted = function ()
        doaction(dict.waitingonblind.waitingfor)
      end,

      action = "blind",
      onstart = function ()
        send("blind", conf.commandecho)
      end
    },
#end
    gone = {
      oncompleted = function()
        if not conf.aillusion or not pflags.b then
          defences.lost("blind")
        end
      end
    }
  },
  waitingonblind = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        defences.got("blind")
      end,

      onstart = function ()
      end
    }
  },
  deaf = {
    gamename = "deafness",
    onservereignore = function()
      -- no deaf skill: ignore serverside if it's not to be deffed up atm
      -- with deaf skill: ignore serverside can use skill, or if it's not to be deffed up atm
      return
#if skills.shindo then
        (conf.shindodeaf and not defc.dragonform) or
#end
#if skills.kaido then
        (conf.kaidodeaf and not defc.dragonform) or
#end
        not ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf))
    end,
    herb = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.deaf and
#if skills.shindo then
         (defc.dragonform or not conf.shindodeaf) and
#end
#if skills.kaido then
         (defc.dragonform or not conf.kaidodeaf) and
#end
         ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf)) and not doingaction("waitingondeaf")) or false
      end,

      oncompleted = function ()
        doaction(dict.waitingondeaf.waitingfor)
        lostbal_herb()
      end,

      eatcure = {"hawthorn", "calamine"},
      onstart = function ()
        eat(dict.deaf.herb)
      end,

      empty = function()
        dict.deaf.herb.oncompleted()
      end
    },
#if skills.shindo then
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.deaf and conf.shindodeaf and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf)) and not doingaction("waitingondeaf")) or false
      end,

      oncompleted = function ()
        doaction(dict.waitingondeaf.waitingfor)
      end,

      action = "deaf",
      onstart = function ()
        send("deaf", conf.commandecho)
      end
    },
#end
#if skills.kaido then
    misc = {
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.deaf and conf.kaidodeaf and not defc.dragonform and ((sys.deffing and defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf)) and not doingaction("waitingondeaf")) or false
      end,

      oncompleted = function ()
        doaction(dict.waitingondeaf.waitingfor)
      end,

      action = "deaf",
      onstart = function ()
        send("deaf", conf.commandecho)
      end
    },
#end
    gone = {
      oncompleted = function()
        if not conf.aillusion or not pflags.d then
          defences.lost("deaf")
        end
      end
    }
  },
  waitingondeaf = {
    spriority = 0,
    waitingfor = {
      customwait = 6,

      oncompleted = function ()
        defences.got("deaf")
      end,

      onstart = function ()
      end
    }
  },


-- balance-related defences
#if skills.devotion then
  bloodsworntoggle = {
    misc = {
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return (defc.bloodsworn and conf.bloodswornoff and stats.currenthealth <= sys.bloodswornoff and not doingaction"bloodsworntoggle" and not defc.dragonform) or false
      end,

      oncompleted = function ()
        defences.lost("bloodsworn")
      end,

      action = "bloodsworn off",
      onstart = function ()
        send("bloodsworn off", conf.commandecho)
      end
    }
  },
#end
  lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not will_take_balance() and not conf.lyre_step and not doingaction("lyre") and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre and not conf.paused then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "strum lyre",
      onstart = function ()
        sys.sendonceonly = true
        -- small fix to make 'lyc' work and be in-order (as well as use batching)
        local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) sendc(what, ...) sk.systemscommands[what] = true end end

        if not conf.lyrecmd then
          send("strum lyre", conf.commandecho)
        else
          send(tostring(conf.lyrecmd), conf.commandecho)
        end
        sys.sendonceonly = false

        if conf.lyre and not conf.paused then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and actions.lyre_physical and not lifevision.l.lyre_physical then killaction(dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  },
  breath = {
    gamename = "heldbreath",
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceless_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].breath and not defc.breath) or (conf.keepup and defkeepup[defs.mode].breath and not defc.breath)) and not doingaction("breath") and not codepaste.balanceful_defs_codepaste() and not affs.aeon and not affs.asthma) or false
      end,

      oncompleted = function ()
        defences.got("breath")
      end,

      action = "hold breath",
      onstart = function ()
        if conf.gagbreath and not sys.sync then
          send("hold breath", false)
        else
          send("hold breath", conf.commandecho) end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("breath")
      end,
    }
  },
  dragonform = {
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragonform and not defc.dragonform) or (conf.keepup and defkeepup[defs.mode].dragonform and not defc.dragonform)) and not doingaction("waitingfordragonform") and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        doaction(dict.waitingfordragonform.waitingfor)
      end,

      alreadyhave = function ()
        dict.waitingfordragonform.waitingfor.oncompleted()
      end,

      actions = {"dragonform", "dragonform red", "dragonform black", "dragonform silver", "dragonform gold", "dragonform blue", "dragonform green"},
      onstart = function ()
      -- user commands catching needs this check
        if not (bals.balance and bals.equilibrium) then return end

#if skills.metamorphosis then
        if defc.flame then send("relax flame", conf.commandecho) end
#end
        send("dragonform", conf.commandecho)

        if not conf.paused then
          dict.dragonform.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Temporarily pausing for dragonform.")
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("dragonform")
        dict.dragonbreath.gone.oncompleted()
        dict.dragonarmour.gone.oncompleted()
        signals.dragonform:emit()
      end,
    }
  },
  waitingfordragonform = {
    spriority = 0,
    waitingfor = {
      customwait = 20,

      oncompleted = function ()
        defences.got("dragonform")
        dict.riding.gone.oncompleted()

        -- strip class defences that don't stay through dragon
        for def, deft in defs_data:iter() do
          local skillset = deft.type
          if skillset ~= "general" and skillset ~= "enchantment" and skillset ~= "dragoncraft" and not deft.staysindragon and defc[def] then
            defences.lost(def)
          end
        end

        -- lifevision, via artefact, has to be removed as well
#if not skills.necromancy then
        if defc.lifevision then defences.lost("lifevision") end
#end

        signals.dragonform:emit()

        if conf.paused and dict.dragonform.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          echo"\n"
          if math.random(1, 20) == 1 then
            echof("ROOOAR!")
          else
            echof("Obtained dragonform, unpausing.")
          end
        end
        dict.dragonform.physical.unpauselater = false
      end,

      cancelled = function ()
        signals.dragonform:emit()
        if conf.paused and dict.dragonform.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Unpausing.")
        end
        dict.dragonform.physical.unpauselater = false
      end,

      ontimeout = function()
        dict.waitingfordragonform.waitingfor.cancelled()
      end,

      onstart = function() end
    }
  },
  dragonbreath = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceless_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragonbreath and not defc.dragonbreath) or (conf.keepup and defkeepup[defs.mode].dragonbreath and not defc.dragonbreath)) and not codepaste.balanceful_defs_codepaste() and not doingaction("dragonbreath") and not doingaction("waitingfordragonbreath") and defc.dragonform and not dict.dragonbreath.blocked and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function (def)
        if def then defences.got("dragonbreath")
        else doaction(dict.waitingfordragonbreath.waitingfor) end
      end,

      ontimeout = function ()
        if not affs.blackout then return end

        dict.dragonbreath.blocked = true
        tempTimer(3, function () dict.dragonbreath.blocked = false; make_gnomes_work() end)
      end,

      alreadygot = function ()
        defences.got("dragonbreath")
      end,

      onstart = function ()
        send("summon "..(conf.dragonbreath and conf.dragonbreath or "unknown"), conf.commandecho)
      end
    },
    gone = {
      oncompleted = function()
        defences.lost("dragonbreath")
      end
    }
  },
  waitingfordragonbreath = {
    spriority = 0,
    waitingfor = {
      customwait = 2,

      onstart = function() end,

      oncompleted = function ()
        defences.got("dragonbreath")
      end
    }
  },
  dragonarmour = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragonarmour and not defc.dragonarmour) or (conf.keepup and defkeepup[defs.mode].dragonarmour and not defc.dragonarmour)) and not codepaste.balanceful_defs_codepaste() and defc.dragonform) or false
      end,

      oncompleted = function ()
        defences.got("dragonarmour")
      end,

      action = "dragonarmour on",
      onstart = function ()
        send("dragonarmour on", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function()
        defences.lost("dragonarmour")
      end
    }
  },
  selfishness = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (
          ((sys.deffing and defdefup[defs.mode].selfishness and not defc.selfishness)
            or (not sys.deffing and conf.keepup and ((defkeepup[defs.mode].selfishness and not defc.selfishness) or (not defkeepup[defs.mode].selfishness and defc.selfishness))))
          and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("selfishness")
      end,

      onstart = function ()
        if (sys.deffing and defdefup[defs.mode].selfishness and not defc.selfishness) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].selfishness and not defc.selfishness) then
          send("selfishness", conf.commandecho)
        else
          send("generosity", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("selfishness")

        -- if we've done sl off, _gone gets added, so _physical gets readded by action clear - kill physical here for that not to happen
        if actions.selfishness_physical then
          killaction(dict.selfishness.physical)
        end
      end,
    }
  },
  riding = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (
          ((sys.deffing and defdefup[defs.mode].riding and not defc.riding)
            or (not sys.deffing and conf.keepup and ((defkeepup[defs.mode].riding and not defc.riding) or (not defkeepup[defs.mode].riding and defc.riding))))
          and not codepaste.balanceful_defs_codepaste() and not defc.dragonform and not affs.hamstring and (not affs.prone or doingaction"prone") and not affs.crippledleftarm and not affs.crippledrightarm and not affs.mangledleftarm and not affs.mangledrightarm and not affs.mutilatedleftarm and not affs.mutilatedrightarm and not affs.unknowncrippledleg and not affs.parestolegs and not doingaction"riding" and not affs.pinshot and not affs.paralysis) or false
      end,

      oncompleted = function ()
        if (not sys.deffing and conf.keepup and not defkeepup[defs.mode].riding and (defc.riding == true or defc.riding == nil)) then
          dict.riding.gone.oncompleted()
        else
          defences.got("riding")
        end

        if bals.balance and not conf.freevault then
          config.set("freevault", "yep", true)
        elseif not bals.balance and conf.freevault then
          config.set("freevault", "nope", true)
        end
      end,

      alreadyon = function ()
        defences.got("riding")
      end,

      dragonform = function ()
        defences.got("dragonform")
        signals.dragonform:emit()
      end,

      hastring = function ()
        dict.hamstring.aff.oncompleted()
      end,

      dismount = function ()
        defences.lost("riding")
        dict.block.gone.oncompleted()
      end,

      onstart = function ()
        if (sys.deffing and defdefup[defs.mode].riding and not defc.riding) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].riding and not defc.riding) then
          send(string.format("%s %s", tostring(conf.ridingskill), tostring(conf.ridingsteed)), conf.commandecho)
        else
          send("dismount", conf.commandecho)
          if sys.sync or tostring(conf.ridingsteed) == "giraffe" then return end
          if conf.steedfollow then send(string.format("order %s follow me", tostring(conf.ridingsteed), conf.commandecho)) end
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("riding")
        dict.block.gone.oncompleted()
      end,
    }
  },
  meditate = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].meditate and not defc.meditate) or (conf.keepup and defkeepup[defs.mode].meditate and not defc.meditate)) and not codepaste.balanceful_defs_codepaste() and not doingaction'meditate' and (stats.currentwillpower < stats.maxwillpower or stats.currentmana < stats.maxmana)) or false
      end,

      oncompleted = function ()
        defences.got("meditate")
      end,

      actions = {"med", "meditate"},
      onstart = function ()
        send("meditate", conf.commandecho)
      end
    }
  },

#basicdef("satiation", "satiation")
  mindseye = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.mindseye and ((sys.deffing and defdefup[defs.mode].mindseye) or (conf.keepup and defkeepup[defs.mode].mindseye)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("mindseye")

        -- check if we need to re-classify deaf
        if (defc.deaf or affs.deafaff) and (defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye then
          defences.got("deaf")
          removeaff("deafaff")
        elseif (defc.deaf or affs.deafaff) then
          defences.lost("deaf")
          addaff(dict.deafaff)
        end

        -- check if we need to re-classify blind
        if (defc.blind or affs.blindaff) and (defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)
#if class ~= "apostate" then
         or defc.mindseye
#end
         then
          defences.got("blind")
          removeaff("blindaff")
        elseif (defc.blind or affs.blindaff) then
          defences.lost("blind")
          addaff(dict.blindaff)
        end
      end,

      action = "touch mindseye",
      onstart = function ()
        send("touch mindseye", conf.commandecho)
      end
    }
  },
  metawake = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.metawake and ((sys.deffing and defdefup[defs.mode].metawake) or (conf.keepup and defkeepup[defs.mode].metawake)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not doingaction'metawake' and not affs.lullaby) or false
      end,

      oncompleted = function ()
        defences.got("metawake")
      end,

      action = "metawake on",
      onstart = function ()
        send("metawake on", conf.commandecho)
      end
    }
  },
#basicdef("treewatch", "treewatch on", true)
#basicdef("skywatch", "skywatch on", true)
#basicdef("groundwatch", "groundwatch on", true)
#basicdef("telesense", "telesense on", true)
#basicdef("softfocus", "softfocus on", true, "softfocusing")
#basicdef("vigilance", "vigilance on", true)
#basicdef("magicresist", "activate magic resistance", true)
#basicdef("fireresist", "activate fire resistance", true)
#basicdef("coldresist", "activate cold resistance", true)
#basicdef("electricresist", "activate electric resistance", true)
#basicdef("alertness", "alertness on")
#basicdef("bell", "touch bell", true, "belltattoo")
#basicdef("hypersight", "hypersight on")
  cloak = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.cloak and ((sys.deffing and defdefup[defs.mode].cloak) or (conf.keepup and defkeepup[defs.mode].cloak)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("cloak")
      end,

      action = "touch cloak",
      onstart = function ()
        send("touch cloak", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function()
        if not conf.aillusion or not pflags.c then
          defences.lost("cloak")
        end
      end
    }
  },
#basicdef("curseward", "curseward")
#basicdef("clinging", "cling")

  nightsight = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
#if skills.metamorphosis then
      undeffable = true, -- mark as undeffable since serverside can't morph
#end

      isadvisable = function ()
        return (not defc.nightsight and ((sys.deffing and defdefup[defs.mode].nightsight) or (conf.keepup and defkeepup[defs.mode].nightsight)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone and not doingaction'nightsight'
#if skills.metamorphosis then
           and ((not affs.cantmorph and sk.morphsforskill.nightsight) or defc.dragonform)
#end
        ) or false
      end,

      oncompleted = function ()
        defences.got("nightsight")
      end,

      action = "nightsight on",
      onstart = function ()
#if not skills.metamorphosis then
        send("nightsight on", conf.commandecho)
#else
        if not defc.dragonform and (not conf.transmorph and sk.inamorph() and not sk.inamorphfor"nightsight") then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not defc.dragonform and not sk.inamorphfor"nightsight" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.nightsight[1], conf.commandecho)
        elseif defc.dragonform or sk.inamorphfor"nightsight" then
          send("nightsight on", conf.commandecho)
        end
#end
      end
    },
  },
  shield = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].shield and not defc.shield) or (conf.keepup and defkeepup[defs.mode].shield and not defc.shield)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not (affs.mangledleftarm and affs.mangledlrightarm) and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("shield")
        if defkeepup[defs.mode].shield and conf.oldts then
          defs.keepup("shield", false)
        end
      end,

      actions = {"touch shield", "angel aura"},
      onstart = function ()
#if skills.spirituality then
        if defc.dragonform or not defc.summon or stats.currentwillpower <= 10 then
          send("touch shield", conf.commandecho)
        else
          send("angel aura", conf.commandecho)
        end
#else
        send("touch shield", conf.commandecho)
#end
      end
    },
    gone = {
      oncompleted = function()
        defences.lost("shield")
      end
    }
  },

-- skillset-specific defences

#if skills.necromancy then
#basicdef("putrefaction", "putrefaction")
#basicdef("shroud", "shroud")
#basicdef("vengeance", "vengeance on")
#basicdef("deathaura", "deathaura on")
#basicdef("soulcage", "soulcage activate")
  lifevision = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.lifevision and ((sys.deffing and defdefup[defs.mode].lifevision) or (conf.keepup and defkeepup[defs.mode].lifevision)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone and stats.currentmana >= 600) or false
      end,

      oncompleted = function ()
        defences.got("lifevision")
      end,

      action = "lifevision",
      onstart = function ()
        send("lifevision", conf.commandecho)
      end
    }
  },
#end

#if skills.chivalry then
#basicdef("mastery", "mastery on", true, "blademastery")
#basicdef("sturdiness", "stand firm", false, "standingfirm")
#basicdef("weathering", "weathering", true)
#basicdef("resistance", "resistance", true)
#basicdef("grip", "grip", true, "gripping")
#basicdef("fury", "fury on")
#end

#if skills.devotion then
#basicdef("inspiration", "perform inspiration")
#basicdef("bliss", "perform bliss", nil, nil, true)
  frostblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.frostblessing and ((sys.deffing and defdefup[defs.mode].frostblessing) or (conf.keepup and defkeepup[defs.mode].frostblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.air and defc.water and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("frostblessing")
      end,

      action = "bless me spiritshield frost",
      onstart = function ()
        send("bless me spiritshield frost", conf.commandecho)
      end
    }
  },
  willpowerblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.willpowerblessing and ((sys.deffing and defdefup[defs.mode].willpowerblessing) or (conf.keepup and defkeepup[defs.mode].willpowerblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.air and defc.water and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("willpowerblessing")
      end,

      action = "bless me willpower",
      onstart = function ()
        send("bless me willpower", conf.commandecho)
      end
    }
  },
  thermalblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.thermalblessing and ((sys.deffing and defdefup[defs.mode].thermalblessing) or (conf.keepup and defkeepup[defs.mode].thermalblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.spirit and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("thermalblessing")
      end,

      action = "bless me spiritshield thermal",
      onstart = function ()
        send("bless me spiritshield thermal", conf.commandecho)
      end
    }
  },
  earthblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.earthblessing and ((sys.deffing and defdefup[defs.mode].earthblessing) or (conf.keepup and defkeepup[defs.mode].earthblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.earth and defc.water and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("earthblessing")
      end,

      action = "bless me spiritshield earth",
      onstart = function ()
        send("bless me spiritshield earth", conf.commandecho)
      end
    }
  },
  enduranceblessing = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.enduranceblessing and ((sys.deffing and defdefup[defs.mode].enduranceblessing) or (conf.keepup and defkeepup[defs.mode].enduranceblessing)) and not codepaste.balanceful_defs_codepaste() and not affs.prone and defc.air and defc.earth and defc.water and defc.fire and stats.currentmana >= 750) or false
      end,

      oncompleted = function ()
        defences.got("enduranceblessing")
      end,

      action = "bless me endurance",
      onstart = function ()
        send("bless me endurance", conf.commandecho)
      end
    }
  },
#end

#if skills.spirituality then
#basicdef("heresy", "hunt heresy")
  mace = {
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true, -- it is balanceless, but this causes it to be bundled with a balanceful action - not desired
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].mace and not defc.mace) or (conf.keepup and defkeepup[defs.mode].mace and not defc.mace)) and not doingaction("waitingformace") and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        doaction(dict.waitingformace.waitingfor)
      end,

      alreadyhave = function ()
        dict.waitingformace.waitingfor.oncompleted()
        send("wield mace", conf.commandecho)
      end,

      action = "summon mace",
      onstart = function ()
      -- user commands catching needs this check
        if not (bals.balance and bals.equilibrium) then return end

        send("summon mace", conf.commandecho)

        if not conf.paused then
          dict.mace.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Temporarily pausing to summon the mace.")
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("mace")
      end,
    }
  },
  waitingformace = {
    spriority = 0,
    waitingfor = {
      customwait = 3,

      oncompleted = function ()
        defences.got("mace")

        if conf.paused and dict.mace.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          echof("Obtained mace, unpausing.")
        end
        dict.mace.physical.unpauselater = false
      end,

      cancelled = function ()
        if conf.paused and dict.mace.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echof("Oops, summoning interrupted. Unpausing.")
        end
        dict.mace.physical.unpauselater = false
      end,

      ontimeout = function()
        if conf.paused and dict.mace.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echof("Hm... doesn't seem the mace summon is happening. Going to try again.")
        end
        dict.mace.physical.unpauselater = false
      end,

      onstart = function() end
    }
  },
  sacrifice = {
    description = "tracks whenever you've sent the angel sacrifice command - so an illusion on angel sacrifice won't trick the system into clearing all affs",
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return false
      end,

      oncompleted = function ()
      end,

      action = "angel sacrifice",
      onstart = function ()
        send("angel sacrifice", conf.commandecho)
      end
    }
  },
  summon = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.summon and ((sys.deffing and defdefup[defs.mode].summon) or (conf.keepup and defkeepup[defs.mode].summon)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("summon")
      end,

      action = "angel summon",
      onstart = function ()
        send("angel summon", conf.commandecho)
      end
    }
  },
  empathy = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.empathy and ((sys.deffing and defdefup[defs.mode].empathy) or (conf.keepup and defkeepup[defs.mode].empathy)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and defc.summon) or false
      end,

      oncompleted = function ()
        defences.got("empathy")
      end,

      action = "angel empathy on",
      onstart = function ()
        send("angel empathy on", conf.commandecho)
      end
    }
  },
  watch = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.watch and ((sys.deffing and defdefup[defs.mode].watch) or (conf.keepup and defkeepup[defs.mode].watch)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and defc.summon) or false
      end,

      oncompleted = function ()
        defences.got("watch")
      end,

      action = "angel watch on",
      onstart = function ()
        send("angel watch on", conf.commandecho)
      end
    }
  },
  care = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.care and ((sys.deffing and defdefup[defs.mode].care) or (conf.keepup and defkeepup[defs.mode].care)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and defc.summon) or false
      end,

      oncompleted = function ()
        defences.got("care")
      end,

      action = "angel care on",
      onstart = function ()
        send("angel care on", conf.commandecho)
      end
    }
  },
#end

#if skills.shindo then
#basicdef("clarity", "clarity", nil, nil, true)
#basicdef("sturdiness", "stand firm", false, "standingfirm")
#basicdef("weathering", "weathering", true)
#basicdef("grip", "grip", true, "gripping")
#basicdef("toughness", "toughness", true)
#basicdef("mindnet", "mindnet on")
#basicdef("constitution", "constitution")
#basicdef("waterwalk", "waterwalk", false, "waterwalking")
#basicdef("retaliationstrike", "retaliationstrike", nil, "retaliation")
#basicdef("shintrance", "shin trance")
#basicdef("consciousness", "consciousness on")
#basicdef("bind", "binding on", nil, nil, true)
#basicdef("projectiles", "projectiles on")
#basicdef("dodging", "dodging on")
#basicdef("immunity", "immunity")
  phoenix = {
    description = "tracks whenever you've sent the shindo phoenix command - so an illusion on shindo phoenix won't trick the system into clearing all affs",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      uncurable = true,

      isadvisable = function ()
        return false
      end,

      oncompleted = function ()
      end,

      action = "shin phoenix",
      onstart = function ()
        send("shin phoenix", conf.commandecho)
      end
    }
  },
#end

#if skills.twoarts then
  doya = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].doya and not defc.doya) or (conf.keepup and defkeepup[defs.mode].doya and not defc.doya)) and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("doya")
      end,

      action = "doya",
      onstart = function ()
        send("doya", conf.commandecho)
      end
    },
  },
  thyr = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].thyr and not defc.thyr) or (conf.keepup and defkeepup[defs.mode].thyr)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("thyr")
      end,

      action = "thyr",
      onstart = function ()
        send("thyr", conf.commandecho)
      end
    },
  },
  mir = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].mir and not defc.mir) or (conf.keepup and defkeepup[defs.mode].mir)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("mir")
      end,

      action = "mir",
      onstart = function ()
        send("mir", conf.commandecho)
      end
    },
  },
  arash = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].arash and not defc.arash) or (conf.keepup and defkeepup[defs.mode].arash)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("arash")
      end,

      action = "arash",
      onstart = function ()
        send("arash", conf.commandecho)
      end
    },
  },
  sanya = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].sanya and not defc.sanya) or (conf.keepup and defkeepup[defs.mode].sanya)) and not defc.doya and not defc.thyr and not defc.mir and not defc.arash and not defc.sanya and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"doya", "thyr", "mir", "arash", "sanya"} do
          defences.lost(stance)
        end

        defences.got("sanya")
      end,

      action = "sanya",
      onstart = function ()
        send("sanya", conf.commandecho)
      end
    },
  },
#end

#if skills.metamorphosis then
affinity = {
  physical = {
    balanceful_act = true,
    aspriority = 0,
    spriority = 0,
    def = true,
    undeffable = true, -- mark as undeffable since serverside can't morph

    isadvisable = function ()
      return (not defc.affinity and ((sys.deffing and defdefup[defs.mode].affinity) or (conf.keepup and defkeepup[defs.mode].affinity)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone) or false
    end,

    oncompleted = function ()
      defences.got("affinity")
    end,

    action = "embrace spirit",
    onstart = function ()
      if sk.inamorph() then
        send("embrace spirit", conf.commandecho)
      else
        if defc.flame then send("relax flame", conf.commandecho) end

        if sk.skillmorphs.wyvern then
          send("morph wyvern", conf.commandecho)
        else
          send("morph "..sk.morphsforskill.nightsight[1], conf.commandecho)
        end
      end
    end
  }
},

#basicdef("bonding", "bond spirit", nil, nil, true)
  fitness = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        if not (not affs.weakness and not defc.dragonform and bals.fitness and not codepaste.balanceful_defs_codepaste() and (defc.wyvern or defc.wolf or defc.hyena or defc.jaguar or defc.cheetah or defc.elephant or defc.hydra) and not affs.cantmorph and sk.morphsforskill.fitness) then
          return false
        end

        for name, func in pairs(fitness) do
          if not me.disabledfitnessfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function ()
        removeaff("asthma")
        lostbal_fitness()
      end,

      curedasthma = function ()
        removeaff("asthma")
      end,

      weakness = function ()
        addaff(dict.weakness)
      end,

      allgood = function()
        removeaff("asthma")
      end,

      actions = {"fitness"},
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"fitness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"fitness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.fitness[1], conf.commandecho)
        elseif sk.inamorphfor"fitness" then
          send("fitness", conf.commandecho)
        end
      end
    },
  },
  elusiveness = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.elusiveness and ((sys.deffing and defdefup[defs.mode].elusiveness) or (conf.keepup and defkeepup[defs.mode].elusiveness)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.elusiveness) or false
      end,

      oncompleted = function ()
        defences.got("elusiveness")
      end,

      action = "elusiveness on",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"elusiveness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"elusiveness" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.elusiveness[1], conf.commandecho)
        elseif sk.inamorphfor"elusiveness" then
          send("elusiveness on", conf.commandecho)
        end
      end
    },
  },
  temperance = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.temperance and ((sys.deffing and defdefup[defs.mode].temperance) or (conf.keepup and defkeepup[defs.mode].temperance)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.temperance) or false
      end,

      oncompleted = function ()
        defences.got("temperance")
        defences.got("frost")
      end,

      action = "temperance",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"temperance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"temperance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.temperance[1], conf.commandecho)
        elseif sk.inamorphfor"temperance" then
          send("temperance", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("frost")
      end
    }
  },
  stealth = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.stealth and ((sys.deffing and defdefup[defs.mode].stealth) or (conf.keepup and defkeepup[defs.mode].stealth)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.stealth) or false
      end,

      oncompleted = function ()
        defences.got("stealth")
      end,

      action = "stealth on",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"stealth" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"stealth" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.stealth[1], conf.commandecho)
        elseif sk.inamorphfor"stealth" then
          send("stealth on", conf.commandecho)
        end
      end
    },
  },
  resistance = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.resistance and ((sys.deffing and defdefup[defs.mode].resistance) or (conf.keepup and defkeepup[defs.mode].resistance)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.resistance) or false
      end,

      oncompleted = function ()
        defences.got("resistance")
      end,

      action = "resistance",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"resistance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"resistance" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.resistance[1], conf.commandecho)
        elseif sk.inamorphfor"resistance" then
          send("resistance", conf.commandecho)
        end
      end
    },
  },
  rest = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.rest and ((sys.deffing and defdefup[defs.mode].rest) or (conf.keepup and defkeepup[defs.mode].rest)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.rest) or false
      end,

      oncompleted = function ()
        defences.got("rest")
      end,

      action = "rest",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"rest" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"rest" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.rest[1], conf.commandecho)
        elseif sk.inamorphfor"rest" then
          send("rest", conf.commandecho)
        end
      end
    },
  },
  vitality = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        if (not defc.vitality and ((sys.deffing and defdefup[defs.mode].vitality) or (conf.keepup and defkeepup[defs.mode].vitality)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.vitality and not doingaction"cantvitality") then

         if (stats.currenthealth >= stats.maxhealth and stats.currentmana >= stats.maxmana)
          then
            return true
          elseif not sk.gettingfullstats then
            fullstats(true)
            echof("Getting fullstats for vitality now...")
          end
        end
      end,

      oncompleted = function ()
        defences.got("vitality")
      end,

      action = "vitality",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"vitality" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"vitality" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.vitality[1], conf.commandecho)
        elseif sk.inamorphfor"vitality" then
          send("vitality", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("vitality")
        if not actions.cantvitality_waitingfor then doaction(dict.cantvitality.waitingfor) end
      end
    }
  },
  -- nightsight = {
  --   physical = {
  --     aspriority = 0,
  --     spriority = 0,
  --     balanceful_act = true,
  --     def = true,

  --     isadvisable = function ()
  --       return (not defc.nightsight and ((sys.deffing and defdefup[defs.mode].nightsight) or (conf.keepup and defkeepup[defs.mode].nightsight)) and not codepaste.balanceful_defs_codepaste() and ((not affs.cantmorph and sk.morphsforskill.nightsight) or defc.dragonform)) or false
  --     end,

  --     oncompleted = function ()
  --       defences.got("nightsight")
  --     end,

  --     action = "nightsight on",
  --     onstart = function ()
  --       if not defc.dragonform and (not conf.transmorph and sk.inamorph() and not sk.inamorphfor"nightsight") then
  --         if defc.flame then send("relax flame", conf.commandecho) end
  --         send("human", conf.commandecho)
  --       elseif not defc.dragonform and not sk.inamorphfor"nightsight" then
  --         if defc.flame then send("relax flame", conf.commandecho) end
  --         send("morph "..sk.morphsforskill.nightsight[1], conf.commandecho)
  --       elseif defc.dragonform or sk.inamorphfor"nightsight" then
  --         send("nightsight on", conf.commandecho)
  --       end
  --     end
  --   },
  -- },
  flame = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true, -- mark as undeffable since serverside can't morph

      isadvisable = function ()
        return (not defc.flame and ((sys.deffing and defdefup[defs.mode].flame) or (conf.keepup and defkeepup[defs.mode].flame)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and sk.morphsforskill.flame) or false
      end,

      oncompleted = function ()
        defences.got("flame")
      end,

      actions = {"summon flame", "summon fire"},
      onstart = function ()
        if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"flame" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        elseif not sk.inamorphfor"flame" then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph "..sk.morphsforskill.flame[1], conf.commandecho)
        elseif sk.inamorphfor"flame" then
          send("summon flame", conf.commandecho)
        end
      end
    },
  },

  squirrel = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.squirrel and ((sys.deffing and defdefup[defs.mode].squirrel) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].squirrel)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("squirrel")
      end,

      action = "morph squirrel",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph squirrel", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("squirrel")
      end,
    }
  },
  wildcat = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wildcat and ((sys.deffing and defdefup[defs.mode].wildcat) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wildcat)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wildcat")
      end,

      action = "morph wildcat",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wildcat", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wildcat")
      end,
    }
  },
  wolf = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wolf and ((sys.deffing and defdefup[defs.mode].wolf) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wolf)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wolf")
      end,

      action = "morph wolf",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wolf", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wolf")
      end,
    }
  },
  turtle = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.turtle and ((sys.deffing and defdefup[defs.mode].turtle) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].turtle)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("turtle")
      end,

      action = "morph turtle",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph turtle", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("turtle")
      end,
    }
  },
  jackdaw = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.jackdaw and ((sys.deffing and defdefup[defs.mode].jackdaw) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].jackdaw)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("jackdaw")
      end,

      action = "morph jackdaw",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph jackdaw", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("jackdaw")
      end,
    }
  },
  cheetah = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.cheetah and ((sys.deffing and defdefup[defs.mode].cheetah) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].cheetah)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("cheetah")
      end,

      action = "morph cheetah",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph cheetah", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("cheetah")
      end,
    }
  },
  owl = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.owl and ((sys.deffing and defdefup[defs.mode].owl) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].owl)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("owl")
      end,

      action = "morph owl",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph owl", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("owl")
      end,
    }
  },
  hyena = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.hyena and ((sys.deffing and defdefup[defs.mode].hyena) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].hyena)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("hyena")
      end,

      action = "morph hyena",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph hyena", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("hyena")
      end,
    }
  },
  condor = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.condor and ((sys.deffing and defdefup[defs.mode].condor) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].condor)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("condor")
      end,

      action = "morph condor",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph condor", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("condor")
      end,
    }
  },
  gopher = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.gopher and ((sys.deffing and defdefup[defs.mode].gopher) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].gopher)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("gopher")
      end,

      action = "morph gopher",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph gopher", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("gopher")
      end,
    }
  },
  sloth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.sloth and ((sys.deffing and defdefup[defs.mode].sloth) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].sloth)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("sloth")
      end,

      action = "morph sloth",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph sloth", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("sloth")
      end,
    }
  },
#if class == "sentinel" then
  basilisk = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.basilisk and ((sys.deffing and defdefup[defs.mode].basilisk) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].basilisk)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("basilisk")
      end,

      action = "morph basilisk",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph basilisk", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("basilisk")
      end,
    }
  },
#end
  bear = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.bear and ((sys.deffing and defdefup[defs.mode].bear) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].bear)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("bear")
      end,

      action = "morph bear",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph bear", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("bear")
      end,
    }
  },
  nightingale = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.nightingale and ((sys.deffing and defdefup[defs.mode].nightingale) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].nightingale)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("nightingale")
      end,

      action = "morph nightingale",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph nightingale", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("nightingale")
      end,
    }
  },
  elephant = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.elephant and ((sys.deffing and defdefup[defs.mode].elephant) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].elephant)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("elephant")
      end,

      action = "morph elephant",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph elephant", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("elephant")
      end,
    }
  },
  wolverine = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wolverine and ((sys.deffing and defdefup[defs.mode].wolverine) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wolverine)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wolverine")
      end,

      action = "morph wolverine",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wolverine", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wolverine")
      end,
    }
  },
#if class == "sentinel" then
  jaguar = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.jaguar and ((sys.deffing and defdefup[defs.mode].jaguar) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].jaguar)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("jaguar")
      end,

      action = "morph jaguar",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph jaguar", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("jaguar")
      end,
    }
  },
#end
  eagle = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.eagle and ((sys.deffing and defdefup[defs.mode].eagle) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].eagle)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("eagle")
      end,

      action = "morph eagle",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph eagle", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("eagle")
      end,
    }
  },
  gorilla = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.gorilla and ((sys.deffing and defdefup[defs.mode].gorilla) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].gorilla)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("gorilla")
      end,

      action = "morph gorilla",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph gorilla", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("gorilla")
      end,
    }
  },
  icewyrm = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.icewyrm and ((sys.deffing and defdefup[defs.mode].icewyrm) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].icewyrm)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("icewyrm")
      end,

      action = "morph icewyrm",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph icewyrm", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("icewyrm")
      end,
    }
  },
#if class == "druid" then
  wyvern = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.wyvern and ((sys.deffing and defdefup[defs.mode].wyvern) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].wyvern)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("wyvern")
      end,

      action = "morph wyvern",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph wyvern", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("wyvern")
      end,
    }
  },
  hydra = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.hydra and ((sys.deffing and defdefup[defs.mode].hydra) or (not sys.deffing and conf.keepup and defkeepup[defs.mode].hydra)) and not codepaste.balanceful_defs_codepaste() and not affs.cantmorph and codepaste.nonmorphdefs()) or false
      end,

      oncompleted = function ()
        sk.clearmorphs()

        defences.got("hydra")
      end,

      action = "morph hydra",
      onstart = function ()
        if not conf.transmorph and sk.inamorph() then
          if defc.flame then send("relax flame", conf.commandecho) end
          send("human", conf.commandecho)
        else
          if defc.flame then send("relax flame", conf.commandecho) end
          send("morph hydra", conf.commandecho)
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("hydra")
      end,
    }
  },
#end
#end

#if skills.swashbuckling then
  drunkensailor = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].drunkensailor and not defc.drunkensailor) or (conf.keepup and defkeepup[defs.mode].drunkensailor and not defc.drunkensailor) and not defc.heartsfury and not doingaction"drunkensailor" and not affs.paralysis) or false
      end,

      oncompleted = function ()
        defences.got("drunkensailor")
      end,

      action = "drunkensailor",
      onstart = function ()
        send("drunkensailor", conf.commandecho)
      end
    },
  },
  heartsfury = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return ((sys.deffing and defdefup[defs.mode].heartsfury and not defc.heartsfury) or (conf.keepup and defkeepup[defs.mode].heartsfury and not defc.heartsfury) and not defc.drunkensailor and not doingaction"heartsfury" and not affs.paralysis) or false
      end,

      oncompleted = function ()
        defences.got("heartsfury")
      end,

      action = "heartsfury",
      onstart = function ()
        send("heartsfury", conf.commandecho)
      end
    },
  },

#basicdef("arrowcatch", "arrowcatch on", nil, "arrowcatching")
#basicdef("balancing", "balancing on")
#basicdef("acrobatics", "acrobatics on")
#basicdef("dodging", "dodging on")
#basicdef("grip", "grip", true, "gripping")
#end

#if skills.voicecraft then
  lay = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].lay and not defc.lay) or (conf.keepup and defkeepup[defs.mode].lay and not defc.lay)) and not codepaste.balanceful_defs_codepaste() and not doingaction"lay" and bals.voice) or false
      end,

      oncompleted = function ()
        defences.got("lay")
        lostbal_voice()
      end,

      action = "sing lay",
      onstart = function ()
        send("sing lay", conf.commandecho)
      end
    },
  },
  tune = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].tune and not defc.tune) or (conf.keepup and defkeepup[defs.mode].tune and not defc.tune)) and not codepaste.balanceful_defs_codepaste() and not doingaction"tune" and bals.voice) or false
      end,

      oncompleted = function ()
        defences.got("tune")
        lostbal_voice()
      end,

      action = "sing tune",
      onstart = function ()
        send("sing tune", conf.commandecho)
      end
    },
  },
  aria = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].aria and not defc.aria) or (conf.keepup and defkeepup[defs.mode].aria and not defc.aria)) and not codepaste.balanceful_defs_codepaste() and not doingaction"aria" and bals.voice and not affs.deafaff and not defc.deaf) or false
      end,

      oncompleted = function ()
        defences.got("aria")
        lostbal_voice()
      end,

      action = "sing aria at me",
      onstart = function ()
        send("sing aria at me", conf.commandecho)
      end
    },
  },

#basicdef("songbird", "whistle for songbird")
#end

#if skills.harmonics then
#basicdef("lament", "play lament", nil, nil, true)
#basicdef("anthem", "play anthem", nil, nil, true)
#basicdef("harmonius", "play harmonius", nil, nil, true)
#basicdef("contradanse", "play contradanse", nil, nil, true)
#basicdef("paxmusicalis", "play paxmusicalis", nil, nil, true)
#basicdef("gigue", "play gigue", nil, nil, true)
#basicdef("bagatelle", "play bagatelle", nil, nil, true)
#basicdef("partita", "play partita", nil, nil, true)
#basicdef("berceuse", "play berceuse", nil, nil, true)
#basicdef("continuo", "play continuo", nil, nil, true)
#basicdef("wassail", "play wassail", nil, nil, true)
#basicdef("canticle", "play canticle", nil, nil, true)
#basicdef("reel", "play reel", nil, nil, true)
#basicdef("hallelujah", "play hallelujah", nil, nil, true)
#end

#if skills.occultism then
#basicdef("shroud", "shroud")
#basicdef("astralvision", "astralvision", nil, nil, true)
#basicdef("distortedaura", "distortaura")
#basicdef("tentacles", "tentacles")
#basicdef("devilmark", "devilmark")
  astralform = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.astralform and ((sys.deffing and defdefup[defs.mode].astralform) or (conf.keepup and defkeepup[defs.mode].astralform)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("astralform")
        defences.lost("riding")
      end,

      action = "astralform",
      onstart = function ()
        send("astralform", conf.commandecho)
      end
    }
  },
#basicdef("heartstone", "heartstone", nil, nil, true)
#basicdef("simulacrum", "simulacrum", nil, nil, true)
#basicdef("transmogrify", "transmogrify activate", nil, nil, true)
#end

#if skills.healing then
  bedevil = {
    gamename = "bedevilaura",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.bedevil and ((sys.deffing and defdefup[defs.mode].bedevil) or (conf.keepup and defkeepup[defs.mode].bedevil)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.air and defc.water and defc.fire and defc.earth and defc.spirit) or false
      end,

      oncompleted = function ()
        defences.got("bedevil")
      end,

      action = "bedevil",
      onstart = function ()
        send("bedevil", conf.commandecho)
      end
    }
  },
#end

#if skills.healing or skills.elementalism or skills.weatherweaving then
  simultaneity = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.simultaneity and ((sys.deffing and defdefup[defs.mode].simultaneity) or (conf.keepup and defkeepup[defs.mode].simultaneity)) and not codepaste.balanceful_defs_codepaste() and stats.currentmana >= 1000) or false
      end,

      oncompleted = function ()
        defences.got("simultaneity")
      end,

      action = "simultaneity",
      onstart = function ()
        send("simultaneity", conf.commandecho)
      end
    }
  },
  air = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.air and ((sys.deffing and defdefup[defs.mode].air) or (conf.keepup and defkeepup[defs.mode].air)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("air")
        if defc.air and defc.earth and defc.water
#if skills.healing then
         and defc.spirit
#end
#if not skills.weatherweaving then
         and defc.fire
#end
         then
          defences.got("simultaneity")
        end
      end,

      action = "channel air",
      onstart = function ()
        send("channel air", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("air")
        defences.lost("simultaneity")
      end
    }
  },
  water = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.water and ((sys.deffing and defdefup[defs.mode].water) or (conf.keepup and defkeepup[defs.mode].water)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("water")
        if defc.air and defc.earth and defc.water
#if skills.healing then
         and defc.spirit
#end
#if not skills.weatherweaving then
         and defc.fire
#end
         then
          defences.got("simultaneity")
        end
      end,

      action = "channel water",
      onstart = function ()
        send("channel water", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("water")
        defences.lost("simultaneity")
      end
    }
  },
  earth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.earth and ((sys.deffing and defdefup[defs.mode].earth) or (conf.keepup and defkeepup[defs.mode].earth)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("earth")
        if defc.air and defc.earth and defc.water
#if skills.healing then
         and defc.spirit
#end
#if not skills.weatherweaving then
         and defc.fire
#end
         then
          defences.got("simultaneity")
        end
      end,

      action = "channel earth",
      onstart = function ()
        send("channel earth", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("earth")
        defences.lost("simultaneity")
      end
    }
  },
#if not skills.weatherweaving then
  fire = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.fire and ((sys.deffing and defdefup[defs.mode].fire) or (conf.keepup and defkeepup[defs.mode].fire)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("fire")
        if defc.air and defc.fire and defc.earth and defc.water
#if skills.healing then
         and defc.spirit
#end
         then
          defences.got("simultaneity")
        end
      end,

      action = "channel fire",
      onstart = function ()
        send("channel fire", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fire")
        defences.lost("simultaneity")
      end
    }
  },
#end
#if skills.healing then
  spirit = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].spirit and not defc.spirit) or (conf.keepup and defkeepup[defs.mode].spirit and not defc.spirit))) or (conf.keepup and defkeepup[defs.mode].spirit and not defc.spirit)) and not codepaste.balanceful_defs_codepaste() and defc.air and defc.fire and defc.water and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("spirit")
        if defc.air and defc.fire and defc.earth and defc.water and defc.spirit then
          defences.got("simultaneity")
        end
      end,

      action = "channel spirit",
      onstart = function ()
        send("channel spirit", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("spirit")
        defences.lost("simultaneity")
      end
    }
  },
#end
  bindall = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].bindall and not defc.bindall) or (conf.keepup and defkeepup[defs.mode].bindall and not defc.bindall))) or (conf.keepup and defkeepup[defs.mode].bindall and not defc.bindall)) and not codepaste.balanceful_defs_codepaste() and stats.currentmana >= 750 and defc.air and defc.earth and defc.water
#if skills.healing then
         and defc.spirit
#end
#if not skills.weatherweaving then
        and defc.fire
#end
         ) or false
      end,

      oncompleted = function ()
        defences.got("bindall")
      end,

      action = "bind all",
      onstart = function ()
        send("bind all", conf.commandecho)
      end
    }
  },
  boundair = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundair and not defc.boundair) or (conf.keepup and defkeepup[defs.mode].boundair and not defc.boundair))) or (conf.keepup and defkeepup[defs.mode].boundair and not defc.boundair)) and not codepaste.balanceful_defs_codepaste() and defc.air) or false
      end,

      oncompleted = function ()
        defences.got("boundair")
        if defc.boundair  and defc.boundearth and defc.boundwater
#if skills.healing then
         and defc.boundspirit
#end
#if not skills.weatherweaving then
         and defc.boundfire
#end
        then
          defences.got("bindall")
        end
      end,

      action = "bind air",
      onstart = function ()
        send("bind air", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundair")
        defences.lost("bindall")
      end
    }
  },
  boundwater = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundwater and not defc.boundwater) or (conf.keepup and defkeepup[defs.mode].boundwater and not defc.boundwater))) or (conf.keepup and defkeepup[defs.mode].boundwater and not defc.boundwater)) and not codepaste.balanceful_defs_codepaste() and defc.water) or false
      end,

      oncompleted = function ()
        defences.got("boundwater")
        if defc.boundair and defc.boundearth and defc.boundwater
#if skills.healing then
         and defc.boundspirit
#end
#if not skills.weatherweaving then
         and defc.boundfire
#end
        then
          defences.got("bindall")
        end
      end,

      action = "bind water",
      onstart = function ()
        send("bind water", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundwater")
        defences.lost("bindall")
      end
    }
  },
#if not skills.weatherweaving then
  boundfire = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundfire and not defc.boundfire) or (conf.keepup and defkeepup[defs.mode].boundfire and not defc.boundfire))) or (conf.keepup and defkeepup[defs.mode].boundfire and not defc.boundfire)) and not codepaste.balanceful_defs_codepaste() and defc.fire) or false
      end,

      oncompleted = function ()
        defences.got("boundfire")
        if defc.boundair and defc.boundfire and defc.boundearth and defc.boundwater
#if skills.healing then
         and defc.boundspirit
#end
        then
          defences.got("bindall")
        end
      end,

      action = "bind fire",
      onstart = function ()
        send("bind fire", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundfire")
        defences.lost("bindall")
      end
    }
  },
#end
  boundearth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundearth and not defc.boundearth) or (conf.keepup and defkeepup[defs.mode].boundearth and not defc.boundearth))) or (conf.keepup and defkeepup[defs.mode].boundearth and not defc.boundearth)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("boundearth")
        if defc.boundair and defc.boundearth and defc.boundwater
#if skills.healing then
         and defc.boundspirit
#end
#if not skills.weatherweaving then
         and defc.boundfire
#end
        then
          defences.got("bindall")
        end
      end,

      action = "bind earth",
      onstart = function ()
        send("bind earth", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundearth")
        defences.lost("bindall")
      end
    }
  },
#if skills.healing then
  boundspirit = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].boundspirit and not defc.boundspirit) or (conf.keepup and defkeepup[defs.mode].boundspirit and not defc.boundspirit))) or (conf.keepup and defkeepup[defs.mode].boundspirit and not defc.boundspirit)) and not codepaste.balanceful_defs_codepaste() and defc.spirit) or false
      end,

      oncompleted = function ()
        defences.got("boundspirit")
        if defc.boundair and defc.boundfire and defc.boundearth and defc.boundwater and defc.boundspirit then
          defences.got("bindall")
        end
      end,

      action = "bind spirit",
      onstart = function ()
        send("bind spirit", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("boundspirit")
        defences.lost("bindall")
      end
    }
  },
#end
  fortifyall = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifyall and not defc.fortifyall) or (conf.keepup and defkeepup[defs.mode].fortifyall and not defc.fortifyall))) or (conf.keepup and defkeepup[defs.mode].fortifyall and not defc.fortifyall)) and not codepaste.balanceful_defs_codepaste() and stats.currentmana >= 600 and defc.air and defc.earth and defc.water
#if skills.healing then
         and defc.spirit
#end
#if not skills.weatherweaving then
         and defc.fire
#end
         ) or false
      end,

      oncompleted = function ()
        defences.got("fortifyall")
      end,

      action = "fortify all",
      onstart = function ()
        send("fortify all", conf.commandecho)
      end
    }
  },
  fortifiedair = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedair and not defc.fortifiedair) or (conf.keepup and defkeepup[defs.mode].fortifiedair and not defc.fortifiedair))) or (conf.keepup and defkeepup[defs.mode].fortifiedair and not defc.fortifiedair)) and not codepaste.balanceful_defs_codepaste() and defc.air) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedair")
        if defc.fortifiedair and defc.fortifiedearth and defc.fortifiedwater
#if skills.healing then
         and defc.fortifiedspirit
#end
#if not skills.weatherweaving then
         and defc.fortifiedfire
#end
         then
          defences.got("fortifyall")
        end
      end,

      action = "fortify air",
      onstart = function ()
        send("fortify air", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedair")
        defences.lost("fortifyall")
      end
    }
  },
  fortifiedwater = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedwater and not defc.fortifiedwater) or (conf.keepup and defkeepup[defs.mode].fortifiedwater and not defc.fortifiedwater))) or (conf.keepup and defkeepup[defs.mode].fortifiedwater and not defc.fortifiedwater)) and not codepaste.balanceful_defs_codepaste() and defc.water) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedwater")
        if defc.fortifiedair and defc.fortifiedearth and defc.fortifiedwater
#if skills.healing then
         and defc.fortifiedspirit
#end
#if not skills.weatherweaving then
         and defc.fortifiedfire
#end
         then
          defences.got("fortifyall")
        end
      end,

      action = "fortify water",
      onstart = function ()
        send("fortify water", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedwater")
        defences.lost("fortifyall")
      end
    }
  },
#if not skills.weatherweaving then
  fortifiedfire = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedfire and not defc.fortifiedfire) or (conf.keepup and defkeepup[defs.mode].fortifiedfire and not defc.fortifiedfire))) or (conf.keepup and defkeepup[defs.mode].fortifiedfire and not defc.fortifiedfire)) and not codepaste.balanceful_defs_codepaste() and defc.fire) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedfire")
        if defc.fortifiedair and defc.fortifiedfire and defc.fortifiedearth and defc.fortifiedwater
#if skills.healing then
         and defc.fortifiedspirit
#end
         then
          defences.got("fortifyall")
        end
      end,

      action = "fortify fire",
      onstart = function ()
        send("fortify fire", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedfire")
        defences.lost("fortifyall")
      end
    }
  },
#end
  fortifiedearth = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedearth and not defc.fortifiedearth) or (conf.keepup and defkeepup[defs.mode].fortifiedearth and not defc.fortifiedearth))) or (conf.keepup and defkeepup[defs.mode].fortifiedearth and not defc.fortifiedearth)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedearth")
        if defc.fortifiedair and defc.fortifiedearth and defc.fortifiedwater
#if skills.healing then
         and defc.fortifiedspirit
#end
#if not skills.weatherweaving then
         and defc.fortifiedfire
#end
         then
          defences.got("fortifyall")
        end
      end,

      action = "fortify earth",
      onstart = function ()
        send("fortify earth", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedearth")
        defences.lost("fortifyall")
      end
    }
  },
#if skills.healing then
  fortifiedspirit = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((((sys.deffing and defdefup[defs.mode].fortifiedspirit and not defc.fortifiedspirit) or (conf.keepup and defkeepup[defs.mode].fortifiedspirit and not defc.fortifiedspirit))) or (conf.keepup and defkeepup[defs.mode].fortifiedspirit and not defc.fortifiedspirit)) and not codepaste.balanceful_defs_codepaste() and defc.spirit) or false
      end,

      oncompleted = function ()
        defences.got("fortifiedspirit")
        if defc.fortifiedair and defc.fortifiedfire and defc.fortifiedearth and defc.fortifiedwater and defc.fortifiedspirit then
          defences.got("fortifyall")
        end
      end,

      action = "fortify spirit",
      onstart = function ()
        send("fortify spirit", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("fortifiedspirit")
        defences.lost("fortifyall")
      end
    }
  },
#end
#end

#if skills.elementalism then
#basicdef("efreeti", "cast efreeti", nil, nil, true)
  waterweird = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
       return (not defc.waterweird and ((sys.deffing and defdefup[defs.mode].waterweird) or (conf.keepup and defkeepup[defs.mode].waterweird)) and not codepaste.balanceful_defs_codepaste() and defc.water) or false
      end,

      oncompleted = function ()
        defences.got("waterweird")
      end,

      action = "cast waterweird at me",
      onstart = function ()
        send("cast waterweird at me", conf.commandecho)
      end
    }
  },
  chargeshield = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.chargeshield and ((sys.deffing and defdefup[defs.mode].chargeshield) or (conf.keepup and defkeepup[defs.mode].chargeshield)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.air) or false
      end,

      oncompleted = function ()
        defences.got("chargeshield")
      end,

      action = "cast chargeshield at me",
      onstart = function ()
        send("cast chargeshield at me", conf.commandecho)
      end
    }
  },
  stonefist = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.stonefist and ((sys.deffing and defdefup[defs.mode].stonefist) or (conf.keepup and defkeepup[defs.mode].stonefist)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("stonefist")
      end,

      action = "cast stonefist",
      onstart = function ()
        send("cast stonefist", conf.commandecho)
      end
    }
  },
  stoneskin = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.stoneskin and ((sys.deffing and defdefup[defs.mode].stoneskin) or (conf.keepup and defkeepup[defs.mode].stoneskin)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("stoneskin")
      end,

      action = "cast stoneskin",
      onstart = function ()
        send("cast stoneskin", conf.commandecho)
      end
    }
  },
  diamondskin = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.diamondskin and ((sys.deffing and defdefup[defs.mode].diamondskin) or (conf.keepup and defkeepup[defs.mode].diamondskin)) and not codepaste.balanceful_defs_codepaste() and defc.earth and defc.water and defc.fire) or false
      end,

      oncompleted = function ()
        defences.got("diamondskin")
      end,

      action = "cast diamondskin",
      onstart = function ()
        send("cast diamondskin", conf.commandecho)
      end
    }
  },
#end
#if skills.elementalism or skills.weatherweaving then
  reflection = {
    gamename = "reflections",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.reflection and ((sys.deffing and defdefup[defs.mode].reflection) or (conf.keepup and defkeepup[defs.mode].reflection)) and not codepaste.balanceful_defs_codepaste() and defc.air and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("reflection")
      end,

      action = "cast reflection at me",
      onstart = function ()
        send("cast reflection at me", conf.commandecho)
      end
    }
  },
#end

#if skills.apostasy then
  baalzadeen = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        if (not defc.baalzadeen and ((sys.deffing and defdefup[defs.mode].baalzadeen) or (conf.keepup and defkeepup[defs.mode].baalzadeen)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) then

          if (stats.mp >= 100) then
             return true
           elseif not sk.gettingfullstats then
             fullstats(true)
             echof("Getting fullstats for Baalzadeen summoning...")
           end
        end
      end,

      oncompleted = function ()
        defences.got("baalzadeen")
      end,

      action = "summon baalzadeen",
      onstart = function ()
        send("summon baalzadeen", conf.commandecho)
      end
    }
  },
  armour = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.armour and ((sys.deffing and defdefup[defs.mode].armour) or (conf.keepup and defkeepup[defs.mode].armour)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.baalzadeen) or false
      end,

      oncompleted = function ()
        defences.got("armour")
      end,

      action = "demon armour",
      onstart = function ()
        send("demon armour", conf.commandecho)
      end
    }
  },
  syphon = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.syphon and ((sys.deffing and defdefup[defs.mode].syphon) or (conf.keepup and defkeepup[defs.mode].syphon)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.baalzadeen) or false
      end,

      oncompleted = function ()
        defences.got("syphon")
      end,

      action = "demon syphon",
      onstart = function ()
        send("demon syphon", conf.commandecho)
      end
    }
  },
  mask = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.mask and ((sys.deffing and defdefup[defs.mode].mask) or (conf.keepup and defkeepup[defs.mode].mask)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone and defc.baalzadeen) or false
      end,

      oncompleted = function ()
        defences.got("mask")
      end,

      action = "mask",
      onstart = function ()
        send("mask", conf.commandecho)
      end
    }
  },
#basicdef("daegger", "summon daegger", nil, nil, true)
#basicdef("pentagram", "carve pentagram", nil, nil, true)
#end

#if skills.weatherweaving then
  circulate = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.circulate and ((sys.deffing and defdefup[defs.mode].circulate) or (conf.keepup and defkeepup[defs.mode].circulate)) and not codepaste.balanceful_defs_codepaste() and defc.air and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("circulate")
      end,

      action = "cast circulate",
      onstart = function ()
        send("cast circulate", conf.commandecho)
      end
    }
  },
#end

#if skills.evileye then
#basicdef("truestare", "truestare")
#end

#if skills.pranks then
#basicdef("arrowcatch", "arrowcatch on", nil, "arrowcatching")
#basicdef("balancing", "balancing on")
#basicdef("acrobatics", "acrobatics on")
#basicdef("slipperiness", "slipperiness", nil, "slippery")
#end

#if skills.puppetry then
#basicdef("grip", "grip", true, "gripping")
#end

#if skills.vodun then
#basicdef("grip", "grip", true, "gripping")
#end

#if skills.curses then
#basicdef("swiftcurse", "swiftcurse")
#end

#if skills.kaido then
#basicdef("numb", "numb", nil, nil, true)
#basicdef("weathering", "weathering", true)
#basicdef("nightsight", "nightsight on", true)
#basicdef("immunity", "immunity")
#basicdef("regeneration", "regeneration on", true)
  boosting = {
    gamename = "boostedregeneration",
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].boosting and not defc.boosting) or (conf.keepup and defkeepup[defs.mode].boosting and not defc.boosting)) and not codepaste.balanceful_defs_codepaste() and defc.regeneration) or false
      end,

      oncompleted = function ()
        defences.got("boosting")
      end,

      action = "boost regeneration",
      onstart = function ()
        send("boost regeneration", conf.commandecho)
      end
    }
  },
  kaiboost = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].kaiboost and not defc.kaiboost) or (conf.keepup and defkeepup[defs.mode].kaiboost and not defc.kaiboost)) and not codepaste.balanceful_defs_codepaste() and stats.kai >= 11 and not doingaction"kaiboost") or false
      end,

      oncompleted = function ()
        defences.got("kaiboost")
      end,

      action = "kai boost",
      onstart = function ()
        send("kai boost", conf.commandecho)
      end
    }
  },
  vitality = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,

      isadvisable = function ()
        if (not defc.vitality and not defc.numb and ((sys.deffing and defdefup[defs.mode].vitality) or (conf.keepup and defkeepup[defs.mode].vitality)) and not codepaste.balanceful_defs_codepaste() and not doingaction"cantvitality") then

          if (stats.currenthealth >= stats.maxhealth and stats.currentmana >= stats.maxmana) then
            return true
          elseif not sk.gettingfullstats then
            fullstats(true)
            echof("Getting fullstats for vitality now...")
          end
        end
      end,

      oncompleted = function ()
        defences.got("vitality")
      end,

      action = "vitality",
      onstart = function ()
        send("vitality", conf.commandecho)
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("vitality")
        if not actions.cantvitality_waitingfor then doaction(dict.cantvitality.waitingfor) end
      end
    }
  },
#basicdef("resistance", "resistance", true)
#basicdef("toughness", "toughness", true)
#basicdef("trance", "kai trance", true, "kaitrance")
#basicdef("consciousness", "consciousness on", true)
#basicdef("projectiles", "projectiles on", true)
#basicdef("dodging", "dodging on", true)
#basicdef("constitution", "constitution")
#basicdef("splitmind", "split mind")
#basicdef("sturdiness", "stand firm", false, "standingfirm")
#end

#if skills.telepathy then
#basicdef("mindtelesense", "mind telesense on", true)
#basicdef("hypersense", "mind hypersense on")
#basicdef("mindnet", "mindnet on", true)
#basicdef("mindcloak", "mind cloak on", true)
#end

#if skills.skirmishing then
#basicdef("scout", "scout", nil, "scouting")
#end

#if skills.tarot then
  devil = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.devil and ((sys.deffing and defdefup[defs.mode].devil) or (conf.keepup and defkeepup[defs.mode].devil)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("devil")
      end,

      action = "fling devil at ground",
      onstart = function ()
        sendAll("outd 1 devil","fling devil at ground","ind 1 devil", conf.commandecho)
      end
    }
  },
#end

#if skills.tekura then
#basicdef("bodyblock", "bdb")
#basicdef("evadeblock", "evb")
#basicdef("pinchblock", "pnb")

  horse = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].horse and not defc.horse) or (conf.keepup and defkeepup[defs.mode].horse and not defc.horse)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("horse")
      end,

      action = "hrs",
      onstart = function ()
        send("hrs", conf.commandecho)
      end
    },
  },
  eagle = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].eagle and not defc.eagle) or (conf.keepup and defkeepup[defs.mode].eagle and not defc.eagle)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("eagle")
      end,

      action = "egs",
      onstart = function ()
        send("egs", conf.commandecho)
      end
    },
  },
  cat = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].cat and not defc.cat) or (conf.keepup and defkeepup[defs.mode].cat and not defc.cat)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("cat")
      end,

      action = "cts",
      onstart = function ()
        send("cts", conf.commandecho)
      end
    },
  },
  bear = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].bear and not defc.bear) or (conf.keepup and defkeepup[defs.mode].bear and not defc.bear)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("bear")
      end,

      action = "brs",
      onstart = function ()
        send("brs", conf.commandecho)
      end
    },
  },
  rat = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].rat and not defc.rat) or (conf.keepup and defkeepup[defs.mode].rat and not defc.rat)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("rat")
      end,

      action = "rts",
      onstart = function ()
        send("rts", conf.commandecho)
      end
    },
  },
  scorpion = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].scorpion and not defc.scorpion) or (conf.keepup and defkeepup[defs.mode].scorpion and not defc.scorpion)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("scorpion")
      end,

      action = "scs",
      onstart = function ()
        send("scs", conf.commandecho)
      end
    },
  },
  dragon = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dragon and not defc.dragon) or (conf.keepup and defkeepup[defs.mode].dragon and not defc.dragon)) and not codepaste.balanceful_defs_codepaste() and not defc.riding) or false
      end,

      oncompleted = function ()
        for _, stance in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
          defences.lost(stance)
        end

        defences.got("dragon")
      end,

      action = "drs",
      onstart = function ()
        send("drs", conf.commandecho)
      end
    },
  },
#end

#if skills.weaponmastery then
#basicdef("deflect", "deflect", true)
#end

#if skills.subterfuge then
#basicdef("scales", "scales")
#basicdef("hiding", "hide", false, "hiding", true)
#basicdef("pacing", "pacing on")
#basicdef("bask", "bask", false, "basking")
#basicdef("listen", "listen", false, false, true)
#basicdef("eavesdrop", "eavesdrop", false, "eavesdropping", true) -- serverside bugs out and doesn't accept it
#basicdef("lipread", "lipread", false, "lipreading", true) -- serverside bugs and does it while blind
#basicdef("weaving", "weaving on")
#basicdef("cloaking", "conjure cloak", false, "shroud")
#basicdef("ghost", "conjure ghost")
#basicdef("phase", "phase", false, "phased", true)
#basicdef("secondsight", "secondsight")
#end

#if skills.venom then
  shrugging = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceless_act = true,

      isadvisable = function ()
        if not next(affs) or not bals.shrugging or affs.sleep or not conf.shrugging or affs.stun or affs.unconsciousness or affs.weakness or codepaste.nonstdcure() or defc.dragonform then return false end

        for name, func in pairs(shrugging) do
          if not me.disabledshruggingfunc[name] then
            local s,m = pcall(func[1])
            if s and m then return true end
          end
        end
      end,

      oncompleted = function (number)
        if number then
          -- empty
          if number+1 == getLineNumber() then
            empty.shrugging()
          end
        end
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)

        lostbal_shrugging()
      end,

      action = "shrugging",
      onstart = function ()
        send("shrugging", conf.commandecho)
      end,

      offbal = function ()
        lostbal_shrugging()
      end
    }
  },
#end

#if skills.alchemy then
#basicdef("lead", "educe lead", nil, nil, true)
#basicdef("tin", "educe tin")
#basicdef("sulphur", "educe sulphur")
#basicdef("mercury", "educe mercury")
  extispicy = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.extispicy and ((sys.deffing and defdefup[defs.mode].extispicy) or (conf.keepup and defkeepup[defs.mode].extispicy)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("extispicy")
      end,

      norat = function()
        if ignore.extispicy then return end

        ignore.extispicy = true

        if sys.deffing then
          echo'\n' echof("Looks like we have no rat - going to skip extispicy in this defup.")

          signals.donedefup:connect(function()
            ignore.extispicy = nil
          end)
        else
          echo'\n' echof("Looks like we have no rat for keepup - placing extispicy on ignore.")
        end
      end,

      action = "dissect rat",
      onstart = function ()
        send("dissect rat", conf.commandecho)
      end
    }
  },
#basicdef("empower", "astronomy empower me", nil, nil, true)
#end

#if skills.woodlore then
#basicdef("barkskin", "barkskin")
#basicdef("fleetness", "fleetness")
#basicdef("hiding", "hide", false, "hiding", true)
#basicdef("firstaid", "firstaid on")
  impaling = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].impaling and not defc.impaling) or (conf.keepup and defkeepup[defs.mode].impaling and not defc.impaling)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("impaling")
      end,

      onstart = function ()
        send("set "..(conf.weapon and conf.weapon or "unknown"), conf.commandecho)
      end
    }
  },
  spinning = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].spinning and not defc.spinning) or (conf.keepup and defkeepup[defs.mode].spinning and not defc.spinning)) and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function ()
        defences.got("spinning")
      end,

      onstart = function ()
        send("spin "..conf.weapon and conf.weapon or "unknown", conf.commandecho)
      end
    }
  },
#end

#if skills.propagation then
  barkskin = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
       return (not defc.barkskin and ((sys.deffing and defdefup[defs.mode].barkskin) or (conf.keepup and defkeepup[defs.mode].barkskin)) and not codepaste.balanceful_defs_codepaste() and defc.earth) or false
      end,

      oncompleted = function ()
        defences.got("barkskin")
      end,

      action = "barkskin",
      onstart = function ()
        send("barkskin", conf.commandecho)
      end
    }
  },
  viridian = {
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].viridian and not defc.viridian) or (conf.keepup and defkeepup[defs.mode].viridian and not defc.viridian)) and not doingaction("waitingforviridian") and not codepaste.balanceful_defs_codepaste()) or false
      end,

      oncompleted = function (def)
        if def and not defc.viridian then defences.got("viridian")
        else doaction(dict.waitingforviridian.waitingfor) end
      end,

      alreadyhave = function ()
        dict.waitingforviridian.waitingfor.oncompleted()
      end,

      indoors = function ()
        if conf.paused and dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Unpaused - you must be outside to cast Viridian.")
        end
        dict.viridian.physical.unpauselater = false
        defences.got("viridian")
      end,

      notonland = function ()
        if conf.paused and dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" echof("You must be in contact with the earth in order to call upon the might of the Viridian.")
        end
        dict.viridian.physical.unpauselater = false
        defences.got("viridian")
      end,

      actions = {"assume viridian", "assume viridian staff"},
      onstart = function ()
        if defc.flail then
          send("assume viridian staff", conf.commandecho)
        else
          send("assume viridian", conf.commandecho)
        end

        if not conf.paused then
          dict.viridian.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Temporarily pausing for viridian.")
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("viridian")
      end,
    }
  },
  waitingforviridian = {
    spriority = 0,
    waitingfor = {
      customwait = 20,

      oncompleted = function ()
        defences.got("viridian")
        dict.riding.gone.oncompleted()

        if conf.paused and dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          echo"\n"
          echof("Obtained viridian, unpausing.")
        end
        dict.viridian.physical.unpauselater = false
      end,

      cancelled = function ()
        if conf.paused and dict.viridian.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Unpausing.")
        end
        dict.viridian.physical.unpauselater = false
      end,

      ontimeout = function()
        dict.waitingforviridian.waitingfor.cancelled()
      end,

      onstart = function()
      end,
    }
  },
#end

#if skills.groves then
#basicdef("panacea", "evoke panacea", false, false, true)
#basicdef("vigour", "evoke vigour", false, false, true)
#basicdef("roots", "grove roots", false, false, true)
#basicdef("wildgrowth", "evoke wildgrowth", false, false, true)
#basicdef("flail", {"wield quarterstaff", "flail quarterstaff"}, false, false, true)
#basicdef("dampening", "evoke dampening", false, false, true)
#basicdef("snowstorm", "evoke snowstorm", false, false, true)
  lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and not doingaction("lyre") and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not will_take_balance() and not conf.lyre_step and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "evoke barrier",
      onstart = function ()
        sys.sendonceonly = true

        -- small fix to make 'lyc' work and be in-order (as well as use batching)
        local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) sendc(what, ...) sk.systemscommands[what] = true end end

        if not defc.dragonform and (not conf.lyrecmd or conf.lyrecmd == "evoke barrier") then
          send("evoke barrier", conf.commandecho)
        else
          send(tostring(conf.lyrecmd), conf.commandecho)
        end
        sys.sendonceonly = false

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and actions.lyre_physical and not lifevision.l.lyre_physical then killaction(dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  },
#basicdef("roots", "grove roots", false, false, true)
#basicdef("concealment", "grove concealment", false, false, true)
#basicdef("screen", "grove screen", false, false, true)
#basicdef("swarm", "call new swarm", false, false, true)
#basicdef("harmony", "evoke harmony me", false, false, true)
  rejuvenate = {
    description = "auto pauses/unpauses the system when you're rejuvenating the forests",
    physical = {
      aspriority = 0,
      spriority = 0,
      unpauselater = false,
      balanceful_act = true,

      isadvisable = function ()
        return false
      end,

      oncompleted = function ()
        doaction(dict.waitingforrejuvenate.waitingfor)
      end,

      action = "rejuvenate",
      onstart = function ()
      -- user commands catching needs this check
        if not (bals.balance and bals.equilibrium) then return end

        send("rejuvenate", conf.commandecho)

        if not conf.paused then
          dict.rejuvenate.physical.unpauselater = true
          conf.paused = true; raiseEvent("svo config changed", "paused")
          echo"\n" echof("Temporarily pausing to summon the rejuvenate.")
        end
      end
    }
  },
  waitingforrejuvenate = {
    spriority = 0,
    waitingfor = {
      customwait = 30,

      oncompleted = function ()
        if conf.paused and dict.rejuvenate.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")

          echof("Finished rejuvenating, unpausing.")
        end
        dict.rejuvenate.physical.unpauselater = false
      end,

      cancelled = function ()
        if conf.paused and dict.rejuvenate.physical.unpauselater then
          conf.paused = false; raiseEvent("svo config changed", "paused")
          echof("Oops, interrupted rejuvenation. Unpausing.")
        end
        dict.rejuvenate.physical.unpauselater = false
      end,

      ontimeout = function()
        dict.waitingforrejuvenate.waitingfor.cancelled()
      end,

      onstart = function() end
    }
  },
#end

-- override groves lyre, as druids can get 2 types of lyre (groves and nightingale)
#if skills.metamorphosis then
  lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not will_take_balance() and (not defc.dragonform or (not affs.cantmorph and sk.morphsforskill.lyre)) and not conf.lyre_step and not affs.prone) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "sing melody",
      onstart = function ()
        if not defc.dragonform and (not conf.lyrecmd or conf.lyrecmd == "sing melody") then
          if not conf.transmorph and sk.inamorph() and not sk.inamorphfor"lyre" then
            if defc.flame then send("relax flame", conf.commandecho) end
            send("human", conf.commandecho)
          elseif not sk.inamorphfor"lyre" then
            if defc.flame then send("relax flame", conf.commandecho) end
            send("morph "..sk.morphsforskill.lyre[1], conf.commandecho)

            if conf.transmorph then
              sys.sendonceonly = true
              send("sing melody", conf.commandecho)
              sys.sendonceonly = false
              if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
            end
          elseif sk.inamorphfor"lyre" then
            sys.sendonceonly = true
            send("sing melody", conf.commandecho)
            sys.sendonceonly = false

            if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
          end
        else
          -- small fix to make 'lyc' work and be in-order (as well as use batching)
          local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) sendc(what, ...) sk.systemscommands[what] = true end end

          sys.sendonceonly = true
          send(tostring(conf.lyrecmd), conf.commandecho)
          sys.sendonceonly = false

          if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
        end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and actions.lyre_physical and not lifevision.l.lyre_physical then killaction(dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  },
#end

#if skills.domination then
#basicdef("golgotha", "summon golgotha", nil, "golgothagrace")
  arctar = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.arctar and ((sys.deffing and defdefup[defs.mode].arctar) or (conf.keepup and defkeepup[defs.mode].arctar)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis and bals.entities) or false
      end,

      oncompleted = function ()
        defences.got("arctar")
      end,

      action = "command orb",
      onstart = function ()
        send("command orb", conf.commandecho)
      end
    }
  },
#end
#if skills.shadowmancy then
  shadowcloak = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        local shadowcloak = me.getitem("a grim cloak")
        if not defc.dragonform and not defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].shadowcloak) or (conf.keepup and defkeepup[defs.mode].shadowcloak) or (sys.deffing and defdefup[defs.mode].disperse) or (conf.keepup and defkeepup[defs.mode].disperse) or (sys.deffing and defdefup[defs.mode].shadowveil) or (conf.keepup and defkeepup[defs.mode].shadowveil) or (sys.deffing and defdefup[defs.mode].hiding) or (conf.keepup and defkeepup[defs.mode].hiding)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and stats.mp then
          if not shadowcloak then
            if stats.mp >= 100 then
              return true
            elseif not sk.gettingfullstats then
              fullstats(true)
              echof("Getting fullstats for Shadowcloak summoning...")
            end
          else
            return true
          end
        end
        return false
      end,

      oncompleted = function ()
        defences.got("shadowcloak")
      end,

      action = "shadow cloak",
      onstart = function ()
        local shadowcloak = me.getitem("a grim cloak")
        if not shadowcloak then
          send("shadow cloak", conf.commandecho)
        elseif not shadowcloak.attrib or not shadowcloak.attrib:find("w") then
          send("wear " .. shadowcloak.id, conf.commandecho)
        else
	  defences.got("shadowcloak")
        end
      end
    }
  },
  disperse = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return not defc.dragonform and not defc.disperse and defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].disperse) or (conf.keepup and defkeepup[defs.mode].disperse)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone
      end,

      oncompleted = function ()
        defences.got("disperse")
      end,

      action = "shadow disperse",
      onstart = function ()
        send("shadow disperse", conf.commandecho)
      end
    }
  },
  shadowveil = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return not defc.dragonform and not defc.shadowveil and defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].shadowveil) or (conf.keepup and defkeepup[defs.mode].shadowveil)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone
      end,

      oncompleted = function ()
        defences.got("shadowveil")
      end,

      action = "shadow veil",
      onstart = function ()
        send("shadow veil", conf.commandecho)
      end
    }
  },
  hiding = {
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return not defc.dragonform and not defc.hiding and defc.shadowcloak and ((sys.deffing and defdefup[defs.mode].hiding) or (conf.keepup and defkeepup[defs.mode].hiding)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone
      end,

      oncompleted = function ()
        defences.got("hiding")
      end,

      action = "shadow veil",
      onstart = function ()
        send("shadow veil", conf.commandecho)
      end
    }
  },
#end
#if skills.aeonics then
#basicdef("blur", "chrono blur boost")
  dilation = {
    physical = {
      balanceless_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (((sys.deffing and defdefup[defs.mode].dilation and not defc.dilation) or (conf.keepup and defkeepup[defs.mode].dilation and not defc.dilation)) and not codepaste.balanceful_defs_codepaste() and not doingaction'dilation' and (stats.age and stats.age > 0)) or false
      end,

      oncompleted = function ()
        defences.got("dilation")
      end,

      actions = {"chrono dilation", "chrono dilation boost"},
      onstart = function ()
        send("chrono dilation", conf.commandecho)
      end
    }
  },
#end
#if skills.terminus then
  trusad = {
    gamename = "precision",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.trusad and ((sys.deffing and defdefup[defs.mode].trusad) or (conf.keepup and defkeepup[defs.mode].trusad)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("trusad")
      end,
	  
      action = "intone trusad",
      onstart = function ()
	    send("intone trusad", conf.commandecho)
      end
    }
  },
  tsuura = {
    gamename = "durability",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.tsuura and ((sys.deffing and defdefup[defs.mode].tsuura) or (conf.keepup and defkeepup[defs.mode].tsuura)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("tsuura")
      end,
	  
      action = "intone tsuura",
      onstart = function ()
	    send("intone tsuura", conf.commandecho)
      end
    }
  },
  ukhia = {
    gamename = "bloodquell",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.ukhia and ((sys.deffing and defdefup[defs.mode].ukhia) or (conf.keepup and defkeepup[defs.mode].ukhia)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("ukhia")
      end,
	  
      action = "intone ukhia",
      onstart = function ()
	    send("intone ukhia", conf.commandecho)
      end
    }
  },
  qamad = {
    gamename = "ironwill",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.qamad and ((sys.deffing and defdefup[defs.mode].qamad) or (conf.keepup and defkeepup[defs.mode].qamad)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("qamad")
      end,
	  
      action = "intone qamad",
      onstart = function ()
	    send("intone qamad", conf.commandecho)
      end
    }
  },
  mainaas = {
    gamename = "bodyaugment",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.mainaas and ((sys.deffing and defdefup[defs.mode].mainaas) or (conf.keepup and defkeepup[defs.mode].mainaas)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("mainaas")
      end,
	  
      action = "intone mainaas",
      onstart = function ()
	    send("intone mainaas", conf.commandecho)
      end
    }
  },
  gaiartha = {
    gamename = "antiforce",
    physical = {
      balanceful_act = true,
      aspriority = 0,
      spriority = 0,
      def = true,

      isadvisable = function ()
        return (not defc.dragonform and not defc.gaiartha and ((sys.deffing and defdefup[defs.mode].gaiartha) or (conf.keepup and defkeepup[defs.mode].gaiartha)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and bals.word) or false
      end,

      oncompleted = function ()
        defences.got("gaiartha")
      end,
	  
      action = "intone gaiartha",
      onstart = function ()
	    send("intone gaiartha", conf.commandecho)
      end
    }
  },
  lyre = {
    physical = {
      aspriority = 0,
      spriority = 0,
      balanceful_act = true,
      def = true,
      undeffable = true,

      isadvisable = function ()
        return (not defc.lyre and not doingaction("lyre") and ((sys.deffing and defdefup[defs.mode].lyre) or (conf.keepup and defkeepup[defs.mode].lyre)) and not will_take_balance() and not conf.lyre_step and not affs.prone and (defc.dragonform or (conf.lyrecmd and conf.lyrecmd ~= "intone kail") or bals.word)) or false
      end,

      oncompleted = function ()
        defences.got("lyre")

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end,

      ontimeout = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum didn't happen - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
          make_gnomes_work()
        end
      end,

      onkill = function()
        if conf.paused and not defc.lyre then
          echof("Lyre strum cancelled - unpausing.")
          conf.paused = false; raiseEvent("svo config changed", "paused")
        end
      end,

      action = "intone kail",
      onstart = function ()
        sys.sendonceonly = true

        -- small fix to make 'lyc' work and be in-order (as well as use batching)
        local send = send
        -- record in systemscommands, so it doesn't get killed later on in the controller and loop
        if conf.batch then send = function(what, ...) sendc(what, ...) sk.systemscommands[what] = true end end

        if not defc.dragonform and not conf.lyrecmd then
          send("intone kail", conf.commandecho)
        elseif conf.lyrecmd then
          send(tostring(conf.lyrecmd), conf.commandecho)
        else
          send("strum lyre", conf.commandecho)
        end
        sys.sendonceonly = false

        if conf.lyre then conf.paused = true; raiseEvent("svo config changed", "paused") end
      end
    },
    gone = {
      oncompleted = function ()
        defences.lost("lyre")

        -- as a special case for handling the following scenario:
        --[[(focus)
          Your prismatic barrier dissolves into nothing.
          You focus your mind intently on curing your mental maladies.
          Food is no longer repulsive to you. (7.548s)
          H: 3294 (50%), M: 4911 (89%) 28725e, 10294w 89.3% ex|cdk- 19:24:04.719(sip health|eat bayberry|outr bayberry|eat
          irid|outr irid)(+324h, 5.0%, -291m, 5.3%)
          You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.
          (p) H: 3294 (50%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:04.897
          Your prismatic barrier dissolves into nothing.
          You take a drink from a purple heartwood vial.
          The elixir heals and soothes you.
          H: 4767 (73%), M: 4911 (89%) 28725e, 10194w 89.3% x|cdk- 19:24:05.247(+1473h, 22.7%)
          You eat some bayberry bark.
          Your eyes dim as you lose your sight.
        ]]
        -- we want to kill lyre going up when it goes down and you're off balance, because you won't get it up off-bal

        -- but don't kill it if it is in lifevision - meaning we're going to get it:
        --[[
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
          (x) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}
          You have recovered equilibrium. (3.887s)
          (ex) 4600h|100%, 4000m|84%, 100w%, 100e%, (cdbkr)-  {9 Mayan 637}(strum lyre)
          Your prismatic barrier dissolves into nothing.
          You strum a Lasallian lyre, and a prismatic barrier forms around you.
          (svo): Lyre strum cancelled - unpausing.
        ]]

        if not (bals.balance and bals.equilibrium) and actions.lyre_physical and not lifevision.l.lyre_physical then killaction(dict.lyre.physical) end

        -- unpause should we lose the lyre def for some reason - but not while we're doing lyc
        -- since we'll lose the lyre def and it'll come up right away
        if conf.lyre and conf.paused and not actions.lyre_physical then conf.paused = false; raiseEvent("svo config changed", "paused") end
      end,
    }
  },
#end
  sstosvoa = {
    addiction = "addiction",
    aeon = "aeon",
    agoraphobia = "agoraphobia",
    airdisrupt = "airdisrupt",
    airfisted = "galed", 
    amnesia = "amnesia",
    anorexia = "anorexia",
    asthma = "asthma",
    blackout = "blackout",
    blindness = false, 
    bound = "bound",
    brokenleftarm = "crippledleftarm", 
    brokenleftleg = "crippledleftleg", 
    brokenrightarm = "crippledrightarm", 
    brokenrightleg = "crippledrightleg", 
    bruisedribs = false, 
    burning = "ablaze",
    cadmuscurse = "cadmus",
    claustrophobia = "claustrophobia",
    clumsiness = "clumsiness",
    concussion = "seriousconcussion", 
    conflagration = false, 
    confusion = "confusion",
    corruption = "corrupted",
    crackedribs = "crackedribs",
    daeggerimpale = false, 
    damagedhead = "mildconcussion", 
    damagedleftarm = "mangledleftarm", 
    damagedleftleg = "mangledleftleg", 
    damagedrightarm = "mangledrightarm", 
    damagedrightleg = "mangledrightleg", 
    darkshade = "darkshade",
    dazed = false, 
    dazzled = false,
    deadening = "deadening",
    deafness = false, 
    deepsleep = "sleep",
    degenerate = "degenerate",
    dehydrated = "dehydrated",
    dementia = "dementia",
    demonstain = "stain",
    depression = "depression",
    deteriorate = "deteriorate",
    disloyalty = "disloyalty",
    disrupted = "disrupt",
    dissonance = "dissonance",
    dizziness = "dizziness",
    earthdisrupt = "earthdisrupt",
    enlightenment = false, 
    enmesh = false,
    entangled = "roped",
    entropy = false,
    epilepsy = "epilepsy",
    fear = "fear",
    firedisrupt = "firedisrupt",
    flamefisted = "burning",
    frozen = "frozen",
    generosity = "generosity",
    haemophilia = "haemophilia",
    hallucinations = "hallucinations",
    hamstrung = "hamstring",
    hatred = "hatred",
    healthleech = "healthleech",
    heartseed = "heartseed",
    hecatecurse = "hecate",
    hellsight = "hellsight",
    hindered = false, 
    homunculusmercury = false, 
    hypersomnia = "hypersomnia",
    hypochondria = "hypochondria",
    hypothermia = "hypothermia",
    icefisted = "icing", 
    impaled = "impale",
    impatience = "impatience",
    inquisition = "inquisition",
    insomnia = false,
    internalbleeding = false, 
    isolation = false, 
    itching = "itching",
    justice = "justice",
    kaisurge = false,
    laceratedthroat = "laceratedthroat",
    lapsingconsciousness = false, 
    lethargy = "lethargy",
    loneliness = "loneliness",
    lovers = "inlove",
    manaleech = "manaleech",
    mangledhead = "seriousconcussion", 
    mangledleftarm = "mutilatedleftarm", 
    mangledleftleg = "mutilatedleftleg", 
    mangledrightarm = "mutilatedrightarm", 
    mangledrightleg = "mutilatedrightleg", 
    masochism = "masochism",
    mildtrauma = "mildtrauma",
    mindclamp = false, 
    nausea = "illness", 
    numbedleftarm = "numbedleftarm",
    numbedrightarm = "numbedrightarm",
    pacified = "pacifism",
    palpatarfeed = "palpatar",
    paralysis = "paralysis",
    paranoia = "paranoia",
    parasite = "parasite",
    peace = "peace",
    penitence = false, 
    petrified = false, 
    phlogisticated = "phlogistication", 
    pinshot = "pinshot",
    prone = "prone",
    recklessness = "recklessness",
    retribution = "retribution",
    revealed = false,
    scalded = "scalded",
    scrambledbrains = false, 
    scytherus = "relapsing", 
    selarnia = "selarnia",
    sensitivity = "sensitivity",
    serioustrauma = "serioustrauma",
    shadowmadness = "shadowmadness",
    shivering = "shivering",
    shyness = "shyness",
    silver = false,
    skullfractures = "skullfractures",
    slashedthroat = "slashedthroat",
    sleeping = "sleep",
    slickness = "slickness",
    slimeobscure = "ninkharsag", 
    spiritdisrupt = "spiritdisrupt",
    stupidity = "stupidity",
    stuttering = "stuttering",
    temperedcholeric = "cholerichumour",
    temperedmelancholic = "melancholichumour",
    temperedphlegmatic = "phlegmatichumour", 
    temperedsanguine = "sanguinehumour",
    timeflux = "timeflux",
    timeloop = "timeloop",
    torntendons = "torntendons",
    transfixation = "transfixed",
    trueblind = false,
    unconsciousness = "unconsciousness",
    vertigo = "vertigo",
    vinewreathed = false, 
    vitiated = false, 
    vitrified = "vitrification",
    voidfisted = "voided", 
    voyria = "voyria",
    waterdisrupt = "waterdisrupt",
    weakenedmind = "rixil",
    weariness = "weakness",
    webbed = "webbed",
    whisperingmadness = "madness", 
    wristfractures = "wristfractures"
  },
  sstosvod = {
    acrobatics = "acrobatics",
    affinity = "affinity",
    aiming = false,
    airpocket = "pear",
    alertness = "alertness",
	antiforce = "gaiartha",
    arctar = "arctar",
    aria = "aria",
    arrowcatching = "arrowcatch",
    astralform = "astralform",
    astronomy = "empower",
    balancing = "balancing",
    barkskin = "barkskin",
    basking = "bask",
    bedevilaura = "bedevil",
    belltattoo = "bell",
    blackwind = false,
    blademastery = "mastery",
    blessingofthegods = false,
    blindness = "blind",
    blocking = "block",
	bloodquell = "ukhia",
    bloodshield = false,
	blur = "blur",
    boartattoo = false,
	bodyaugment = "mainaas",
    bodyblock = "bodyblock",
    boostedregeneration = "boosting",
    chameleon = "chameleon",
    chargeshield = "chargeshield",
    circulate = "circulate",
    clinging = "clinging",
    cloak = "cloak",
    coldresist = "coldresist",
    consciousness = "consciousness",
    constitution = "constitution",
    curseward = "curseward",
    deafness = "deaf",
    deathaura = "deathaura",
    deathsight = "deathsight",
    deflect = "deflect",
    deliverance = false,
    demonarmour = "armour",
    demonfury = false,
    density = "mass",
    devilmark = "devilmark",
    diamondskin = "diamondskin",
	disassociate = false,
	disperse = "disperse",
    distortedaura = "distortedaura",
    disperse = "disperse",
    dodging = "dodging",
    dragonarmour = "dragonarmour",
    dragonbreath = "dragonbreath",
    drunkensailor = "drunkensailor",
	durability = "tsuura",
    earthshield = "earthblessing",
    eavesdropping = "eavesdrop",
    electricresist = "electricresist",
    elusiveness = "elusiveness",
    enduranceblessing = "enduranceblessing",
    enhancedform = false,
    evadeblock = "evadeblock",
    evasion = false,
    extispicy = "extispicy",
    fangbarrier = "sileris",
    firefly = false,
    fireresist = "fireresist",
    firstaid = "firstaid",
    flailingstaff = "flail",
    fleetness = "fleetness",
    frenzied = false,
    frostshield = "frostblessing",
    fury = false,
    ghost = "ghost",
    golgothagrace = "golgotha",
    gripping = "grip",
    groundwatch = "groundwatch",
    harmony = "harmony",
	haste = false,
    heartsfury = "heartsfury",
    heldbreath = "breath",
    heresy = "heresy",
    hiding = "hiding",
    hypersense = "hypersense",
    hypersight = "hypersight",
    immunity = "immunity",
    insomnia = "insomnia",
    inspiration = "inspiration",
    insuflate = false,
    insulation = false,
    ironform = false,
	ironwill = "qamad",
    kaiboost = "kaiboost",
    kaitrance = "trance",
    kola = "kola",
	lament = false,
    lay = "lay",
    levitating = "levitation",
    lifegiver = false,
	lifesteal = false,
    lifevision = "lifevision",
    lipreading = "lipread",
    magicresist = "magicresist",
    megalithtattoo = false,
    mercury = "mercury",
    metawake = "metawake",
    mindcloak = "mindcloak",
    mindnet = "mindnet",
    mindseye = "mindseye",
    mindtelesense = "mindtelesense",
    moontattoo = false,
    morph = false,
    mosstattoo = false,
    nightsight = "nightsight",
    numbness = "numb",
    oxtattoo = false,
    pacing = "pacing",
    panacea = "panacea",
    phased = "phase",
    pinchblock = "pinchblock",
    poisonresist = "venom",
    preachblessing = false,
	precision = "trusad",
    prismatic = "lyre",
    projectiles = "projectiles",
    promosurcoat = false,
    putrefaction = "putrefaction",
    rebounding = "rebounding",
    reflections = "reflection",
    reflexes = false,
    regeneration = "regeneration",
    resistance = "resistance",
    retaliation = "retaliationstrike",
    satiation = "satiation",
    scales = "scales",
    scholasticism = "myrrh",
    scouting = "scout",
    secondsight = "secondsight",
    selfishness = "selfishness",
    setweapon = "impaling",
    shadowveil = "shadowveil",
    shield = "shield",
    shinbinding = "bind",
    shinclarity = "clarity",
    shinrejoinder = false,
    shintrance = "shintrance",
    shipwarning = "shipwarning",
#if skills.subterfuge then
    shroud = "cloaking",
#else
    shroud = "shroud",
#end
    skywatch = "skywatch",
    slippery = "slipperiness",
    softfocusing = "softfocus",
    songbird = "songbird",
    soulcage = "soulcage",
    speed = "speed",
    spinning = "spinning",
    spinningstaff = false,
    spiritbonded = "bonding",
    spiritwalk = false,
    splitmind = "splitmind",
    standingfirm = "sturdiness",
    starburst = "starburst",
    stealth = "stealth",
    stonefist = "stonefist",
    stoneskin = "stoneskin",
    sulphur = "sulphur",
    swiftcurse = "swiftcurse",
    tekurastance = false,
    telesense = "telesense",
    temperance = "frost",
    tentacles = "tentacles",
    thermalshield = "thermalblessing",
    thirdeye = "thirdeye",
    tin = "tin",
    toughness = "toughness",
    treewatch = "treewatch",
    truestare = "truestare",
    tune = "tune",
    twoartsstance = false,
    vengeance = "vengeance",
    vigilance = "vigilance",
    vigour = "vigour",
    viridian = "viridian",
    vitality = "vitality",
    ward = false,
    waterwalking = "waterwalk",
    weakvigour = false,
    weathering = "weathering",
    weaving = "weaving",
    wildgrowth = "wildgrowth",
    willpowerblessing = "willpowerblessing",
    xporb = false,
  },
  svotossa = {},
  svotossd = {}
}

for ssa, svoa in pairs(dict.sstosvoa) do
  if type(svoa) == "string" then dict.svotossa[svoa] = ssa end
end

for ssd, svod in pairs(dict.sstosvod) do
  if type(svod) == "string" then dict.svotossd[svod] = ssd end
end

-- finds the lowest missing priority num for given balance
local function find_lowest_async(balance)
  local data = make_prio_table(balance)
  local t = {}

  for k,_ in pairs(data) do
    t[#t+1] = k
  end

  table.sort(t)

  local function contains(value)
    for _, v in ipairs(t) do
      if v == value then return true end
    end
    return false
  end

  for i = 1, table.maxn(t) do
    if not contains(i) then return i end
  end

  return table.maxn(t)+1
end

local function find_lowest_sync()
  local data = make_sync_prio_table("%s%s")
  local t = {}

  for k,_ in pairs(data) do
    t[#t+1] = k
  end

  table.sort(t)
  local function contains(value)
    for _, v in ipairs(t) do
      if v == value then return true end
    end
    return false
  end

  for i = 1, table.maxn(t) do
    if not contains(i) then return i end
  end

  return table.maxn(t)+1
end

local function dict_setup()
  dict_balanceful  = {}
  dict_balanceless = {}

  -- defence shortlists
  dict_herb      = {}
  dict_misc      = {}
  dict_misc_def  = {}
  dict_purgative = {}
  dict_salve_def = {}
  dict_smoke_def = {}

  local unassigned_actions      = {}
  local unassigned_sync_actions = {}

  for i,j in pairs(dict) do
    for k,l in pairs(j) do
      if type(l) == "table" then
        if not l.name then l.name = i .. "_" .. k end
        if not l.balance then l.balance = k end
        if not l.action_name then l.action_name = i end
        if l.aspriority == 0 then
          unassigned_actions[k] = unassigned_actions[k] or {}
          unassigned_actions[k][#unassigned_actions[k]+1] = i
        end
        if l.spriority == 0 then
          unassigned_sync_actions[k] = unassigned_sync_actions[k] or {}
          unassigned_sync_actions[k][#unassigned_sync_actions[k]+1] = i
        end

        -- if it's a def, create the gone handler as well so lifevision will watch it
        if not j.gone and l.def then
          j.gone = {
            name = i .. "_gone",
            balance = "gone",
            action_name = i,

            oncompleted = function ()
              defences.lost(i)
            end
          }
        end
      end
    end

    if not j.name then j.name = i end
    if j.physical and j.physical.balanceless_act and not j.physical.def then dict_balanceless[i] = {p = dict[i]} end
    if j.physical and j.physical.balanceful_act and not j.physical.def then dict_balanceful[i] = {p = dict[i]} end

    if j.purgative and j.purgative.def then
      dict_purgative[i] = {p = dict[i]} end

    -- balanceful and balanceless moved to a signal for dragonform!

    if j.misc and j.misc.def then
      dict_misc_def[i] = {p = dict[i]} end

    if j.smoke and j.smoke.def then
      dict_smoke_def[i] = {p = dict[i]} end

    if j.salve and j.salve.def then
      dict_salve_def[i] = {p = dict[i]} end

    if j.misc and not j.misc.def then
      dict_misc[i] = {p = dict[i]} end

    if j.herb and j.herb.def then
      dict_herb[i] = {p = dict[i]} end

    if j.herb and not j.herb.noeffect then
      j.herb.noeffect = function()
        lostbal_herb(true)
      end
    end

    -- mickey steals balance and gives illness
    if j.herb and not j.herb.mickey then
      j.herb.mickey = function()
        lostbal_herb(false, true)
        addaff(dict.illness)
      end
    end

#for _, balance in ipairs{"focus", "salve", "herb", "smoke"} do
    if j.$(balance) and not j.$(balance).offbalance then
      j.$(balance).offbalance = function()
        lostbal_$(balance)()
      end
    end
#end

    if j.focus and not j.focus.nomana then
      j.focus.nomana = function ()
        if not actions.nomana_waitingfor and stats.currentmana ~= 0 then
          echof("Seems we're out of mana.")
          doaction(dict.nomana.waitingfor)
        end
      end
    end

    if not j.sw then j.sw = createStopWatch() end
  end -- went through the dict list once at this point

  for balancename, list in pairs(unassigned_actions) do
    if #list > 0 then
      -- shift up by # all actions for that balance to make room @ bottom
      for i,j in pairs(dict) do
        for balance,l in pairs(j) do
          if balance == balancename and type(l) == "table" and l.aspriority and l.aspriority ~= 0 then
            l.aspriority = l.aspriority + #list
          end
        end
      end

      -- now setup the low id's
      for i, actionname in ipairs(list) do
        dict[actionname][balancename].aspriority = i
      end
    end
  end

  local totalcount = 0
  for _, list in pairs(unassigned_sync_actions) do
    totalcount = totalcount + #list
  end

  for balancename, list in pairs(unassigned_sync_actions) do
    if totalcount > 0 then
      -- shift up by # all actions for that balance to make room @ bottom
      for i,j in pairs(dict) do
        for balance,l in pairs(j) do
          if type(l) == "table" and l.spriority and l.spriority ~= 0 then
            l.spriority = l.spriority + totalcount
          end
        end
      end

      -- now setup the low id's
      for i, actionname in ipairs(list) do
        dict[actionname][balancename].spriority = i
      end
    end
  end

  -- we don't want stuff in dict.lovers.map!
  dict.lovers.map = {}
end
dict_setup() -- call once now to auto-setup missing dict() functions, and later on prio import to sort out the 0's.

local function dict_validate()
  -- basic theory is to create table keys for each table within dict.#,
  -- store the dupe aspriority values inside in key-pair as well, and report
  -- what we got.
  local data = {}
  local dupes = {}
  local sync_dupes = {}
  local key = false

  -- check async ones first
  for i,j in pairs(dict) do
    for k,l in pairs(j) do
      if type(l) == "table" and l.aspriority then
        local balance = k:split("_")[1]
        if not data[balance] then data[balance] = {} dupes[balance] = {} end
        key = containsbyname(data[balance], l.aspriority)
          if key then
          -- store the new dupe that we found
          dupes[balance][(k:split("_")[2] and k:split("_")[2] .. " for " or "") .. i] = l.aspriority
          -- and store the previous one that we had already!
          dupes[balance][(key.balance:split("_")[2] and key.balance:split("_")[2] .. " for " or "") .. key.action_name] = l.aspriority
        end
        data[balance][l] = l.aspriority

      end
    end
  end

  -- if we got something, complain
  for i,j in pairs(dupes) do
    if next(j) then
        echof("Meh, problem. The following actions in %s balance have the same priorities: %s", i, oneconcatwithval(j))
    end
  end

  -- clear table for next use, don't re-make to not force rehashes
  for k in pairs(data) do
    data[k] = nil
  end
  for k in pairs(dupes) do
    dupes[k] = nil
  end

  -- check sync ones
  for i,j in pairs(dict) do
    for k,l in pairs(j) do
      if type(l) == "table" and l.spriority then
        local balance = l.name
        local key = containsbyname(data, l.spriority)
        if key then
          dupes[balance] = l.spriority
          dupes[key] = l.spriority
        end
        data[balance] = l.spriority

      end
    end
  end

  -- if we got something, complain
  if not next(dupes) then return end

  -- sort them first before complaining
  local sorted_dupes = {}
    -- stuff into table
  for i,j in pairs(dupes) do
    sorted_dupes[#sorted_dupes+1] = {name = i, prio = j}
  end

    -- sort table
  table.sort(sorted_dupes, function(a,b) return a.prio < b.prio end)

  local function a(tbl)
    assert(type(tbl) == "table")
    local result = {}
    for i,j in pairs(tbl) do
      result[#result+1] = j.name .. "(" .. j.prio .. ")"
    end

    return table.concat(result, ", ")
  end

    -- complaining time
  echof("Meh, problem. The following actions in sync mode have the same priorities: %s", a(sorted_dupes))
end

signals.dragonform:connect(function ()
  dict_balanceful_def = {}
  dict_balanceless_def = {}

  if not defc.dragonform then
    for i,j in pairs(dict) do
      if j.physical and j.physical.balanceful_act and j.physical.def then
        dict_balanceful_def[i] = {p = dict[i]} end

      if j.physical and j.physical.balanceless_act and j.physical.def then
        dict_balanceless_def[i] = {p = dict[i]} end
    end
  else
    for i,j in pairs(dict) do
      if j.physical and j.physical.balanceful_act and j.physical.def and defs_data[i] and (defs_data[i].type == "general" or defs_data[i].type == "dragoncraft" or defs_data[i].availableindragon) then
        dict_balanceful_def[i] = {p = dict[i]} end

      if j.physical and j.physical.balanceless_act and j.physical.def and defs_data[i] and (defs_data[i].type == "general" or defs_data[i].type == "dragoncraft" or defs_data[i].availableindragon) then
        dict_balanceless_def[i] = {p = dict[i]} end
    end

    -- special case for nightsight and monks: they have it
  end

end)
signals.systemstart:connect(function () signals.dragonform:emit() end)
signals.gmcpcharstatus:connect(function ()
  if gmcp.Char.Status.race then
    if gmcp.Char.Status.race:find("Dragon") then
      defences.got("dragonform")
    else
      defences.lost("dragonform")
    end
  end

  signals.dragonform:emit()
end)

make_prio_table = function (filterbalance)
  local data = {}

  for action,balances in pairs(dict) do
    for k,l in pairs(balances) do
      if k:sub(1, #filterbalance) == filterbalance and type(l) == "table" and l.aspriority then
        if #k ~= #filterbalance then
          data[l.aspriority] = k:sub(#filterbalance+2) .. " for " .. action
        else
          data[l.aspriority] = action
        end
      end
    end
  end

  return data
end

make_sync_prio_table = function(format)
  local data, type, sformat = {}, type, string.format
  for i,j in pairs(dict) do
    for k,l in pairs(j) do
      if type(l) == "table" and l.spriority then
        data[l.spriority] = sformat(format, i, k)
      end
    end
  end

  return data
end

-- func gets passed the action name to operate on, needs to return true for it to be added
make_prio_tablef = function (filterbalance, func)
  local data = {}

  for action, balances in pairs(dict) do
    for balance, l in pairs(balances) do
      if balance == filterbalance and type(l) == "table" and l.aspriority and (not func or func(action)) then
        data[l.aspriority] = action
      end
    end
  end

  return data
end

-- func gets passed the action name to operate on
-- skipbals is a key-value table, where a key is a balance to ignore
make_sync_prio_tablef = function(format, func, skipbals)
  local data, type, sformat = {}, type, string.format
  for action, balances in pairs(dict) do
    for balance, balancedata in pairs(balances) do
      if type(balancedata) == "table" and not skipbals[balance] and balancedata.spriority and (not func or func(action)) then
        data[balancedata.spriority] = sformat(format, action, balance)
      end
    end
  end

  return data
end

clear_balance_prios = function(balance)
  for i,j in pairs(dict) do
    for k,l in pairs(j) do
      if k == balance and type(l) == "table" and l.aspriority then
        l.aspriority = 0
      end
    end
  end
end

clear_sync_prios = function()
  for i,j in pairs(dict) do
    for k,l in pairs(j) do
      if type(l) == "table" and l.spriority then
        l.spriority = 0
      end
    end
  end
end

-- register various handlers
signals.curedwith_focus:connect(function (what)
  dict.unknownmental.focus[what] ()
end)

sk.check_retardation = function (...)
  if affs.retardation then
    removeaff("retardation")
  end
end

#if skills.subterfuge then
signals.newroom:connect(function()
  if defc.listen then defences.lost("listen") end
end)
#end

signals.newroom:connect(function()
  if defc.block then dict.block.gone.oncompleted() end
  if defc.eavesdrop then defences.lost("eavesdrop") end
  if defc.lyre then defences.lost("lyre") end
end)

signals.newroom:connect(sk.check_retardation)
signals.newroom:block(sk.check_retardation)

-- reset impale
signals.newroom:connect(function()
  if not next(affs) then return end

  local removables = {"impale"}
  local escaped = {}
  for i = 1, #removables do
    if affs[removables[i]] then
      escaped[#escaped+1] = removables[i]
      removeaff(removables[i])
    end
  end

  if #escaped > 0 then
    tempTimer(0, function()
      if stats.currenthealth > 0 then
        tempTimer(0, function()
          if not find_until_last_paragraph("You scrabble futilely at the ground as", "substring") then
            echof("Woo! We escaped from %s.", concatand(escaped))
          end
        end)
      end
    end)
  end
end)

signals.systemstart:connect(function()
  sys.input_to_actions = {}

  for action, actiont in pairs(dict) do
    for balance, balancet in pairs(actiont) do
      -- ignore "check*" actions, as they are only useful when used by the system,
      -- and they can override actions that could be done by the user
      if type(balancet) == "table" and not action:find("^check") then
        if type(balancet.sipcure) == "string" then
          sys.input_to_actions["drink "..balancet.sipcure] = balancet
          sys.input_to_actions["sip "..balancet.sipcure] = balancet
        elseif type(balancet.sipcure) == "table" then
          for _, potion in ipairs(balancet.sipcure) do
            sys.input_to_actions["drink "..potion] = balancet
            sys.input_to_actions["sip "..potion] = balancet
          end

        elseif type(balancet.eatcure) == "string" then
          sys.input_to_actions["eat "..balancet.eatcure] = balancet
        elseif type(balancet.eatcure) == "table" then
          for _, thing in ipairs(balancet.eatcure) do
            sys.input_to_actions["eat "..thing] = balancet
          end

        elseif type(balancet.smokecure) == "string" then
          sys.input_to_actions["smoke "..balancet.smokecure] = balancet
          sys.input_to_actions["puff "..balancet.smokecure] = balancet
        elseif type(balancet.smokecure) == "table" then
          for _, thing in ipairs(balancet.smokecure) do
            sys.input_to_actions["smoke "..thing] = balancet
            sys.input_to_actions["puff "..thing] = balancet
          end
        end

        -- add action separately, as sileris has both eatcure and action
        if balancet.action then
          sys.input_to_actions[balancet.action] = balancet
        elseif balancet.actions then
          for _, action in pairs(balancet.actions) do
            sys.input_to_actions[action] = balancet
          end
        end
      end
    end
  end

end)


-- validate stuffs on our own
-- for i,j in pairs(dict) do
--  for k,l in pairs(j) do
--   if type(l) == "table" and k == "focus" then
--     echof("%s %s is focusable", i, k)
--   end
--   end
-- end
