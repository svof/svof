-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

cpp = {}

for _, stat in ipairs {"health", "mana", "endurance", "willpower"} do
  cpp["compute_"..stat.."_percent"] = function()
    return math.floor((stats["current"..stat]/stats["max"..stat])*100)
  end
end

for _, stat in ipairs {"health", "mana", "endurance", "willpower"} do
  cpp["compute_"..stat.."_colour"] = function()
    if stats["current"..stat] >= (stats["max"..stat] * .75) then
      return "<a_darkgreen>"
    elseif stats["current"..stat] >= (stats["max"..stat] * .25) then
      return "<a_yellow>"
    else
      return "<a_red>" end
  end
end

cpp.compute_reverse_xp = function()
  return 100 - stats.nextlevel
end

cpp.compute_pause = function()
  return conf.paused and '<a_red>(<a_darkgrey>p<a_red>)<black> ' or ''
end

cpp.compute_slowcuring = function()
  if not sys.sync then return '' end

  local s = {}
  s[#s+1] = "<red>("

  if sacid then
    s[#s+1] = "<green>a"
  elseif sk.doingstuff_inslowmode() then
    s[#s+1] = "<red>a"
  else
    s[#s+1] = "<blue>a"
  end

  s[#s+1] = "<red>) "

  return table.concat(s)
end

cpp.unknown_stats = function()
  if not affs.recklessness and not affs.blackout then return '' else
  return "<blaze_orange>?: " end
end

cpp.compute_defs = function()
  local t = {}

  if defc.cloak then
    t[#t+1] = "c"
  end

  if affs.deafaff or defc.deaf then
    t[#t+1] = "d"
  end

  if affs.blindaff or defc.blind then
    t[#t+1] = "b"
  end

  if defc.kola then
    t[#t+1] = "k"
  end

  if defc.rebounding then
    t[#t+1] = "r"
  end

  if defc.breath then
    t[#t+1] = "h"
  end

  return table.concat(t)
end

cpp.compute_eqbal = function()
  local t = {}

  if bals.equilibrium then t[#t+1] = "e" end
  if bals.balance then t[#t+1] = "x" end

  return table.concat(t)
end

cpp.compute_armbal = function()
  local t = {}

  if bals.leftarm == true then
    t[#t+1] = "l"
  elseif bals.leftarm ~= false then
    t[#t+1] = "?" end

  if bals.rightarm == true then
    t[#t+1] = "r"
  elseif bals.rightarm ~= false then
    t[#t+1] = "?" end

  return table.concat(t)
end

cpp.compute_prone = function ()
  return (affs.prone and "p" or "")
end

cpp.compute_Prone = function ()
  return (affs.prone and "P" or "")
end

#if skills.kaido then
cpp.compute_kai = function ()
  if stats.kai ~= 0 then
    return stats.kai
  end

  return ""
end

cpp.compute_kai_colour = function ()
  if not stats.kai or stats.kai == 0 then
    return ""
  elseif stats.kai <= 11 then
    return "<a_onelevel>"
  elseif stats.kai <= 21 then
    return "<a_twolevel>"
  elseif stats.kai <= 41 then
    return "<a_threelevel>"
  elseif stats.kai <= 61 then
    return "<a_fourlevel>"
  elseif stats.kai <= 81 then
    return "<a_fivelevel>"
  elseif stats.kai == 100 then
    return "<a_sixlevel>"
  else
    return ""
  end

end
#end


#if skills.shindo then
cpp.compute_shin = function ()
  if stats.shin ~= 0 then
    return stats.shin
  end

  return ""
end

cpp.compute_shin_colour = function ()
  if not stats.shin or stats.shin == 0 then
    return ""
  elseif stats.shin <= 5 then
    return "<a_onelevel>"
  elseif stats.shin <= 15 then
    return "<a_twolevel>"
  elseif stats.shin <= 30 then
    return "<a_threelevel>"
  elseif stats.shin <= 40 then
    return "<a_fourlevel>"
  elseif stats.shin <= 90 then
    return "<a_fivelevel>"
  elseif stats.shin == 100 then
    return "<a_sixlevel>"
  else
    return ""
  end

end
#end

cpp.compute_gametarget_colour = function()
  local colour = "blanched_almond"

  local hp = me.gametargethp or 0
  if hp == 0 then
      -- default colour
  elseif hp < 5 then
        colour = "red" -- nearly dead
  elseif hp < 25 then
        colour = "orange_red" -- grievously wounded
  elseif hp < 50 then
        colour = "dark_orange" -- injured
  elseif hp < 75 then
        colour = "orange" -- slightly injured
  end

  return '<'..colour..">"
end


#if skills.voicecraft then
cpp.compute_voicebal = function()
  return (bals.voice and "v" or "")
end
#end

-- add me to default prompt
#if skills.domination then
cpp.compute_entitiesbal = function()
  return (bals.entities and "e" or "")
end
#end

#if skills.healing then
cpp.compute_healingbal = function()
  return (bals.healing and "E" or "")
end
#end

#if skills.physiology then
cpp.compute_humourbal = function()
  return (bals.humour and "h" or "")
end

cpp.compute_homunculusbal = function()
  return (bals.homunculus and "H" or "")
end
#end

#if skills.venom then
cpp.compute_shruggingbal = function()
  return (bals.shrugging and "s" or "")
end
#end

cpp.compute_dragonhealbal = function()
  return (bals.dragonheal and "d" or "")
end

#if skills.terminus then
cpp.compute_wordbal = function()
  return (bals.word and "w" or "")
end
#end

#if skills.aeonics then
cpp.compute_age = function()
  return ((stats.age and stats.age > 0) and tostring(stats.age) or "")
end
#end

cpp.compute_timestamp = function()
  return getTime(true, 'hh:mm:ss.zzz')
end

cpp.compute_servertimestamp = function()
  return me.servertime or ''
end

cpp.compute_at = function()
  return (defc.blackwind or defc.astralform or defc.phase) and "@" or ""
end

cpp.compute_gametarget = function()
  return me.gametarget and me.gametarget or ""
end

cpp.compute_gametargethp = function()
  return me.gametargethp and me.gametargethp.."%" or ""
end

cpp.compute_weaponmastery = function()
  return stats.weaponmastery or 0
end

cpp.compute_power = function()
  local power = stats.shin or stats.kai
  if not power or power == 0 then
   power = ""
  else
   power = power .. "<grey>-"
  end
  return power
end

cpp.compute_power_color = function()
  local powerColor
  local power = stats.shin or stats.kai
  if not power or power == 0 then
   powerColor = ""
  else
   powerColor = "<" .. (power < 25 and "red" or power < 60 and
  "yellow" or power < 75 and
       "green_yellow" or power < 100 and "a_darkgreen" or "a_green") ..">"
  end
  return powerColor
end

#if skills.metamorphosis then
cpp.compute_morph = function()
  return me.morph or ""

end
#end

#if skills.groves then
cpp.compute_sunlight = function()
  return stats.sunlight > 0 and tostring(stats.sunlight) or ""
end
#end

cpp.compute_promptstring = function()
 return ("<LightSlateGrey>")..
        (defc.cloak and "c" or "") ..
        (bals.equilibrium and "<white>e<LightSlateGrey>" or "")..
        (bals.balance and "<white>x<LightSlateGrey>" or "")..
        (defc.kola and "k" or "")..
        ((defc.deaf or affs.deafaff) and "d" or "")..
        ((defc.blind or affs.blindaff) and "b" or "")..
        (defc.astralform and "@" or "")..
        (defc.phase and "@" or "")..
        (defc.blackwind and "@" or "")..
        (defc.breath and "<blue>|<LightSlateGrey>b" or "")..
#if skills.domination then
        (bals.entities and "e" or "")..
#end
#if skills.healing then
        (bals.healing and "E" or "")..
#end
#if skills.physiology then
        (bals.humour and "h" or "")..
        (bals.homunculus and "H" or "")..
#end
#if skills.venom then
        (bals.shrugging and "s" or "")..
#end
#if skills.voicecraft then
        (bals.voice and "v" or "")..
#end
#if skills.terminus then
        (bals.word and "w" or "")..
#end
        ("-<grey>")
end

cpp.compute_promptstringorig = function()
 return ("<grey>")..
        (defc.cloak and "c" or "") ..
        (bals.equilibrium and "e" or "")..
        (bals.balance and "x" or "")..
        (defc.kola and "k" or "")..
        ((defc.deaf or affs.deafaff) and "d" or "")..
        ((defc.blind or affs.blindaff) and "b" or "")..
        ((defc.phase or defc.blackwind or defc.astralform) and "@" or "")
end

cpp.compute_diffmana = function()
  return (me.manachange > 0 and "+"..me.manachange or (me.manachange < 0 and me.manachange or ''))
end
cpp.compute_diffhealth = function()
  return (me.healthchange > 0 and "+"..me.healthchange or (me.healthchange < 0 and me.healthchange or ''))
end

cpp.compute_diffmana_paren = function()
  return (me.manachange > 0 and "(+"..me.manachange..")" or (me.manachange < 0 and "("..me.manachange..")" or ''))
end
cpp.compute_diffhealth_paren = function()
  return (me.healthchange > 0 and "(+"..me.healthchange..")" or (me.healthchange < 0 and "("..me.healthchange..")" or ''))
end

cpp.compute_diffmana_bracket = function()
  return (me.manachange > 0 and "[+"..me.manachange.."]" or (me.manachange < 0 and "["..me.manachange.."]" or ''))
end
cpp.compute_diffhealth_bracket = function()
  return (me.healthchange > 0 and "[+"..me.healthchange.."]" or (me.healthchange < 0 and "["..me.healthchange.."]" or ''))
end

cpp.compute_day = function()
  return me.gametime and me.gametime.day or ""
end

cpp.compute_month = function()
  return me.gametime and me.gametime.month or ""
end

cpp.compute_year = function()
  return me.gametime and me.gametime.year or ""
end

cpp.compute_battlerage = function()
  return stats.battlerage > 0 and tostring(stats.battlerage) or ""
end

cp.definitions = {
  ["@health"]        = "svo.stats.currenthealth",
  ["@mana"]          = "svo.stats.currentmana",
  ["@willpower"]     = "svo.stats.currentwillpower",
  ["@endurance"]     = "svo.stats.currentendurance",
  ["@maxhealth"]     = "svo.stats.maxhealth",
  ["@maxmana"]       = "svo.stats.maxmana",
  ["@maxwillpower"]  = "svo.stats.maxwillpower",
  ["@maxendurance"]  = "svo.stats.maxendurance",
  ["@%health"]       = "svo.cpp.compute_health_percent()",
  ["@%mana"]         = "svo.cpp.compute_mana_percent()",
  ["@%willpower"]    = "svo.cpp.compute_willpower_percent()",
  ["@%endurance"]    = "svo.cpp.compute_endurance_percent()",
  ["@%xp"]           = "svo.stats.nextlevel",
  ["@-%xp"]          = "svo.cpp.compute_reverse_xp()",
  ["@xprank"]        = "svo.stats.xprank",
  ["@defs"]          = "svo.cpp.compute_defs()",
  ["@eqbal"]         = "svo.cpp.compute_eqbal()",
  ["@armbal"]        = "svo.cpp.compute_armbal()",
  ["@prone"]         = "svo.cpp.compute_prone()",
  ["@Prone"]         = "svo.cpp.compute_Prone()",
  ["@@"]             = "svo.cpp.compute_at()",
  ["@power"]         = "svo.cpp.compute_power()",
  ["@promptstring"]  = "svo.cpp.compute_promptstring()",
  ["@promptstringorig"] = "svo.cpp.compute_promptstringorig()",
  ["@diffmana"]     = "svo.cpp.compute_diffmana()",
  ["@diffhealth"]   = "svo.cpp.compute_diffhealth()",
  ["@(diffmana)"]   = "svo.cpp.compute_diffmana_paren()",
  ["@(diffhealth)"] = "svo.cpp.compute_diffhealth_paren()",
  ["@[diffmana]"]   = "svo.cpp.compute_diffmana_bracket()",
  ["@[diffhealth]"] = "svo.cpp.compute_diffhealth_bracket()",
  ["@day"]          = "svo.cpp.compute_day()",
  ["@month"]        = "svo.cpp.compute_month()",
  ["@year"]         = "svo.cpp.compute_year()",
  ["@p"]            = "svo.cpp.compute_pause()",
  ["@slowcuring"]   = "svo.cpp.compute_slowcuring()",
  ["@?:"]           = "svo.cpp.unknown_stats()",
  ["@gametarget"]   = "svo.cpp.compute_gametarget()",
  ["@gametargethp"] = "svo.cpp.compute_gametargethp()",
  ["@dragonhealbal"]    = "svo.cpp.compute_dragonhealbal()",
  ["@battlerage"]    = "svo.cpp.compute_battlerage()",
#if skills.voicecraft then
  ["@voicebal"]      = "svo.cpp.compute_voicebal()",
#end
#if skills.domination then
  ["@entitiesbal"]   = "svo.cpp.compute_entitiesbal()",
#end
#if skills.healing then
  ["@healingbal"]    = "svo.cpp.compute_healingbal()",
#end
#if skills.physiology then
  ["@humourbal"]     = "svo.cpp.compute_humourbal()",
  ["@homunculusbal"] = "svo.cpp.compute_homunculusbal()",
#end
#if skills.venom then
  ["@shrugging"]     = "svo.cpp.compute_shruggingbal()",
#end
#if skills.kaido then
  ["@kai"]           = "svo.cpp.compute_kai()",
#end
#if skills.shindo then
  ["@shin"]          = "svo.cpp.compute_shin()",
#end
  ["@timestamp"]     = "svo.cpp.compute_timestamp()",
  ["@servertimestamp"] = "svo.cpp.compute_servertimestamp()",
#if skills.weaponmastery then
  ["@weaponmastery"] = "svo.cpp.compute_weaponmastery()",
#end
#if skills.metamorphosis then
  ["@morph"]         = "svo.cpp.compute_morph()",
#end
#if skills.groves then
  ["@sunlight"]      = "svo.cpp.compute_sunlight()",
#end
#if skills.terminus then
  ["@wordbal"]       = "svo.cpp.compute_wordbal()",
#end
#if skills.aeonics then
  ["@age"]           = "svo.cpp.compute_age()",
#end
  ["^1"]             = "svo.cpp.compute_health_colour()",
  ["^2"]             = "svo.cpp.compute_mana_colour()",
  ["^4"]             = "svo.cpp.compute_willpower_colour()",
  ["^5"]             = "svo.cpp.compute_endurance_colour()",
#if skills.kaido then
  ["^6"]             = "svo.cpp.compute_kai_colour()",
#end
#if skills.shindo then
  ["^6"]             = "svo.cpp.compute_shin_colour()",
#end
  ["^7"]             = "svo.cpp.compute_power_color()",
  ["^r"]             = "'<a_red>'",
  ["^R"]             = "'<a_darkred>'",
  ["^g"]             = "'<a_green>'",
  ["^G"]             = "'<a_darkgreen>'",
  ["^y"]             = "'<a_yellow>'",
  ["^Y"]             = "'<a_darkyellow>'",
  ["^b"]             = "'<a_blue>'",
  ["^B"]             = "'<a_darkblue>'",
  ["^m"]             = "'<a_magenta>'",
  ["^M"]             = "'<a_darkmagenta>'",
  ["^c"]             = "'<a_cyan>'",
  ["^C"]             = "'<a_darkcyan>'",
  ["^w"]             = "'<a_white>'",
  ["^W"]             = "'<a_darkwhite>'",
  ["^gametarget"]    = "svo.cpp.compute_gametarget_colour()",
}

function cp.adddefinition(tag, func)
  local func = string.format("tostring(%s)", func)

  cp.definitions[tag] = func
  cp.makefunction()
end

function cp.makefunction()
  if not conf.customprompt or not sk.logged_in then return end

  local t = cp.generatetable(conf.customprompt)

  local display, error = loadstring("return table.concat({"..table.concat(t, ", ").."})")
  if display then cp.display = display else
    cp.display = function() return '' end
    debugf("Couldn't compile the custom prompt: %s", error)
  end

  -- set the prompt we require within the game for these tags to work
  if conf.customprompt:find("@gametarget") or conf.customprompt:find("@gametargethp") or conf.customprompt:find("@weaponmastery") or conf.customprompt:find("@servertimestamp") then
    send(sys.ingamecustomprompt, false)

    svo.ingameprompt = tempExactMatchTrigger("Your custom prompt is now:", [[
      svo.deleteAllP()
      if svo.ingameprompt then
        killTrigger(svo.ingameprompt)
        svo.ingameprompt = nil
      end
    ]])
  end
end
-- use the login event, and not systemstart, so we get can set the right prompt in the game
signals.gmcpcharname:connect(cp.makefunction)
-- meanwhile, return nothing
cp.display = function() return '' end

signals.systemstart:connect(function ()
  if not conf.oldcustomprompt or conf.oldcustomprompt == "off" then
    conf.oldcustomprompt = conf.customprompt
  end
end)

function cp.generatetable(customprompt)
  local t = {}
  local ssub = string.sub

  local tags_array = {}
  for def, defv in pairs(cp.definitions) do
    tags_array[#tags_array+1] = {def = def, defv = defv}
  end

  table.sort(tags_array, function(a,b) return #a.def > #b.def end)

  local buffer = ""

  local function add_character(c)
      buffer = buffer .. c
  end

  local function add_buffer()
    if buffer ~= "" then
      t[#t+1] = "'" .. buffer .. "'"
      buffer = ""
    end
  end

  local function add_code(c)
      add_buffer()
      t[#t+1] = c
  end

  while customprompt ~= "" do
    local matched = false

    for i = 1, #tags_array do
      local def = tags_array[i].def

      if ssub(customprompt, 1, #def) == def then
        add_code(tags_array[i].defv)
        customprompt = ssub(customprompt, #def + 1)
        matched = true
        break
      end
    end

    if not matched then
      add_character(ssub(customprompt, 1, 1))
      customprompt = ssub(customprompt, 2)
    end

  end

  add_buffer()

  return t
end

-- import color_table
for color in pairs(color_table) do
  cp.definitions["^"..color] = "'<"..color..">'"
end
