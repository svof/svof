-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- Svof's custom prompt feature.
-- Available to players many years before the serverside one.

svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (custom prompt, serverside)"] = 1

svo.loader.customprompt = function()

local sys, affs, signals = svo.sys, svo.affs, svo.signals
local conf, sk, me, defc = svo.conf, svo.sk, svo.me, svo.defc
local stats = svo.stats
local bals, cp, cpp = svo.bals, svo.cp, svo.cpp

for _, stat in ipairs {'health', 'mana', 'endurance', 'willpower'} do
  cpp['compute_'..stat..'_percent'] = function()
    return math.floor((stats['current'..stat]/stats['max'..stat])*100)
  end
end

for _, stat in ipairs {'health', 'mana', 'endurance', 'willpower'} do
  cpp['compute_'..stat..'_colour'] = function()
    if stats['current'..stat] >= (stats['max'..stat] * .75) then
      return "<a_darkgreen>"
    elseif stats['current'..stat] >= (stats['max'..stat] * .25) then
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

  if svo.sacid then
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
    t[#t+1] = 'c'
  end

  if affs.deafaff or defc.deaf then
    t[#t+1] = 'd'
  end

  if affs.blindaff or defc.blind then
    t[#t+1] = 'b'
  end

  if defc.kola then
    t[#t+1] = 'k'
  end

  if defc.rebounding then
    t[#t+1] = 'r'
  end

  if defc.breath then
    t[#t+1] = 'h'
  end

  return table.concat(t)
end

cpp.compute_eqbal = function()
  local t = {}

  if bals.equilibrium then t[#t+1] = 'e' end
  if bals.balance then t[#t+1] = 'x' end

  return table.concat(t)
end

cpp.compute_armbal = function()
  local t = {}

  if bals.leftarm == true then
    t[#t+1] = 'l'
  elseif bals.leftarm ~= false then
    t[#t+1] = "?" end

  if bals.rightarm == true then
    t[#t+1] = 'r'
  elseif bals.rightarm ~= false then
    t[#t+1] = "?" end

  return table.concat(t)
end

cpp.compute_prone = function ()
  return (affs.prone and 'p' or "")
end

cpp.compute_Prone = function ()
  return (affs.prone and 'P' or "")
end

if svo.haveskillset('kaido') then
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
  elseif stats.kai <= 100 then
    return "<a_sixlevel>"
  else
    return ""
  end
end
end


if svo.haveskillset('shindo') then
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
  elseif stats.shin <= 100 then
    return "<a_sixlevel>"
  else
    return ""
  end
end
end

if svo.haveskillset('aeonics') then
cpp.compute_age_colour = function ()
  if not stats.age or stats.age == 0 then
    return "<grey>"
  elseif stats.age <= 150 then
    return "<ansi_light_green>"
  elseif stats.age <= 300 then
    return "<ansiGreen>"
  elseif stats.age <= 450 then
    return "<ansi_yellow>"
  elseif stats.age <= 600 then
    return "<gold>"
  elseif stats.age <= 800 then
    return "<blaze_orange>"
  elseif stats.age <= 1000 then
    return "<red>"
  else
    return ""
  end
end
end

cpp.compute_gametarget_colour = function()
  local colour = 'blanched_almond'

  local hp = me.gametargethp or 0
  if hp == 0 then
        colour = 'blanched_almond'
  elseif hp < 5 then
        colour = 'red' -- nearly dead
  elseif hp < 25 then
        colour = 'orange_red' -- grievously wounded
  elseif hp < 50 then
        colour = 'dark_orange' -- injured
  elseif hp < 75 then
        colour = 'orange' -- slightly injured
  end

  return '<'..colour..">"
end


if svo.haveskillset('voicecraft') then
cpp.compute_voicebal = function()
  return (bals.voice and 'v' or "")
end
end

-- add me to default prompt
if svo.haveskillset('domination') then
cpp.compute_entitiesbal = function()
  return (bals.entities and 'e' or "")
end
end

if svo.haveskillset('zeal') then
cpp.compute_prayerbal = function()
  return (bals.prayer and 'E' or "")
end
end

if svo.haveskillset('physiology') then
cpp.compute_humourbal = function()
  return (bals.humour and 'h' or "")
end

cpp.compute_homunculusbal = function()
  return (bals.homunculus and 'H' or "")
end
end

if svo.haveskillset('venom') then
cpp.compute_shruggingbal = function()
  return (bals.shrugging and 's' or "")
end
end

cpp.compute_dragonhealbal = function()
  return (bals.dragonheal and 'd' or "")
end

if svo.haveskillset('terminus') then
cpp.compute_wordbal = function()
  return (bals.word and 'w' or "")
end
end

if svo.haveskillset('aeonics') then
  cpp.compute_age = function()
    return ((stats.age and stats.age > 0) and tostring(stats.age) or "")
  end
end

if svo.haveskillset('anathema') then
  cpp.compute_anathemabal = function()
    return (bals.anathema and 'A' or "")
  end
  
  cpp.compute_manifestation = function()
    return ((stats.manifestation and stats.manifestation > 0) and tostring(stats.manifestation) or "")
  end
end

if svo.haveskillset('anathema') or svo.haveskillset('occultism') then
cpp.compute_karma = function()
  return ((stats.karma and stats.karma > 0) and tostring(stats.karma) or "")
end
end

if svo.haveskillset('excision') then
  cpp.compute_wrathbal = function()
    return (bals.wrathbal and 'W' or "")
  end
  
  cpp.compute_wrath = function()
    return ((stats.wrath and stats.wrath > 0) and tostring(stats.wrath) or "")
  end
end

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
   powerColor = "<" .. (power < 25 and 'red' or power < 60 and
  'yellow' or power < 75 and
       'green_yellow' or power < 100 and 'a_darkgreen' or 'a_green') ..">"
  end
  return powerColor
end

if svo.haveskillset('metamorphosis') then
cpp.compute_morph = function()
  return me.morph or ""

end
end

if svo.haveskillset('groves') then
cpp.compute_sunlight = function()
  return stats.sunlight > 0 and tostring(stats.sunlight) or ""
end
end

if svo.haveskillset('tekura') then
cpp.compute_monkpath = function()
  return me.path or ""
end

cpp.compute_stanceform = function()
  return me.stance or me.form or ""
end

cpp.compute_stanceform_verbose = function()
  return string.format(
    "%s: %s",
    cpp.compute_monkpath(),
    cpp.compute_stanceform()
  )
end
end

if svo.haveskillset('weaponmastery') then
cpp.compute_momentum = function()
  return stats.momentum > 0 and tostring(stats.momentum) or ""
end
end

if svo.haveskillset('necromancy') or svo.haveskillset('oppression') then
cpp.compute_essence = function()
  return stats.essence > 0 and tostring(stats.essence) or ""
end
end

cpp.compute_promptstring = function()
  local text = ("<LightSlateGrey>")..
        (defc.cloak and 'c' or "") ..
        (bals.equilibrium and "<white>e<LightSlateGrey>" or "")..
        (bals.balance and "<white>x<LightSlateGrey>" or "")..
        (defc.kola and 'k' or "")..
        ((defc.deaf or affs.deafaff) and 'd' or "")..
        ((defc.blind or affs.blindaff) and 'b' or "")..
        (defc.astralform and "@" or "")..
        (defc.phase and "@" or "")..
        (defc.blackwind and "@" or "")..
        (defc.breath and "<blue>|<LightSlateGrey>b" or "")
  local composition = {text}
if bals.entities then
  composition[#composition+1] = 'e'
end
if bals.prayer then
  composition[#composition+1] = 'E'
end
if svo.haveskillset('physiology') then
  if bals.humour then
    composition[#composition+1] = 'h'
  end
  if bals.homunculus then
    composition[#composition+1] = 'H'
  end
end
if bals.shrugging then
  composition[#composition+1] = 's'
end
if bals.voice then
  composition[#composition+1] =  'v'
end
if bals.word then
  composition[#composition+1] = 'w'
end
  composition[#composition+1] = '-<grey>'
  return table.concat(composition)
end


cpp.compute_promptstringorig = function()
 return ("<grey>")..
        (defc.cloak and 'c' or "") ..
        (bals.equilibrium and 'e' or "")..
        (bals.balance and 'x' or "")..
        (defc.kola and 'k' or "")..
        ((defc.deaf or affs.deafaff) and 'd' or "")..
        ((defc.blind or affs.blindaff) and 'b' or "")..
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

cp.definitions                      = cp.definitions or {}
cp.definitions["@health"]           = "svo.stats.currenthealth"
cp.definitions["@mana"]             = "svo.stats.currentmana"
cp.definitions["@willpower"]        = "svo.stats.currentwillpower"
cp.definitions["@endurance"]        = "svo.stats.currentendurance"
cp.definitions["@maxhealth"]        = "svo.stats.maxhealth"
cp.definitions["@maxmana"]          = "svo.stats.maxmana"
cp.definitions["@maxwillpower"]     = "svo.stats.maxwillpower"
cp.definitions["@maxendurance"]     = "svo.stats.maxendurance"
cp.definitions["@%health"]          = "svo.cpp.compute_health_percent()"
cp.definitions["@%mana"]            = "svo.cpp.compute_mana_percent()"
cp.definitions["@%willpower"]       = "svo.cpp.compute_willpower_percent()"
cp.definitions["@%endurance"]       = "svo.cpp.compute_endurance_percent()"
cp.definitions["@%xp"]              = "svo.stats.nextlevel"
cp.definitions["@-%xp"]             = "svo.cpp.compute_reverse_xp()"
cp.definitions["@xprank"]           = "svo.stats.xprank"
cp.definitions["@defs"]             = "svo.cpp.compute_defs()"
cp.definitions["@eqbal"]            = "svo.cpp.compute_eqbal()"
cp.definitions["@armbal"]           = "svo.cpp.compute_armbal()"
cp.definitions["@prone"]            = "svo.cpp.compute_prone()"
cp.definitions["@Prone"]            = "svo.cpp.compute_Prone()"
cp.definitions["@@"]                = "svo.cpp.compute_at()"
cp.definitions["@power"]            = "svo.cpp.compute_power()"
cp.definitions["@promptstring"]     = "svo.cpp.compute_promptstring()"
cp.definitions["@promptstringorig"] = "svo.cpp.compute_promptstringorig()"
cp.definitions["@diffmana"]         = "svo.cpp.compute_diffmana()"
cp.definitions["@diffhealth"]       = "svo.cpp.compute_diffhealth()"
cp.definitions["@(diffmana)"]       = "svo.cpp.compute_diffmana_paren()"
cp.definitions["@(diffhealth)"]     = "svo.cpp.compute_diffhealth_paren()"
cp.definitions["@[diffmana]"]       = "svo.cpp.compute_diffmana_bracket()"
cp.definitions["@[diffhealth]"]     = "svo.cpp.compute_diffhealth_bracket()"
cp.definitions["@day"]              = "svo.cpp.compute_day()"
cp.definitions["@month"]            = "svo.cpp.compute_month()"
cp.definitions["@year"]             = "svo.cpp.compute_year()"
cp.definitions["@p"]                = "svo.cpp.compute_pause()"
cp.definitions["@slowcuring"]       = "svo.cpp.compute_slowcuring()"
cp.definitions["@?:"]               = "svo.cpp.unknown_stats()"
cp.definitions["@gametarget"]       = "svo.cpp.compute_gametarget()"
cp.definitions["@gametargethp"]     = "svo.cpp.compute_gametargethp()"
cp.definitions["@dragonhealbal"]    = "svo.cpp.compute_dragonhealbal()"
cp.definitions["@battlerage"]       = "svo.cpp.compute_battlerage()"
cp.definitions["^7"]                = "svo.cpp.compute_power_color()"
cp.definitions["^r"]                = "'<a_red>'"
cp.definitions["^R"]                = "'<a_darkred>'"
cp.definitions["^g"]                = "'<a_green>'"
cp.definitions["^G"]                = "'<a_darkgreen>'"
cp.definitions["^y"]                = "'<a_yellow>'"
cp.definitions["^Y"]                = "'<a_darkyellow>'"
cp.definitions["^b"]                = "'<a_blue>'"
cp.definitions["^B"]                = "'<a_darkblue>'"
cp.definitions["^m"]                = "'<a_magenta>'"
cp.definitions["^M"]                = "'<a_darkmagenta>'"
cp.definitions["^c"]                = "'<a_cyan>'"
cp.definitions["^C"]                = "'<a_darkcyan>'"
cp.definitions["^w"]                = "'<a_white>'"
cp.definitions["^W"]                = "'<a_darkwhite>'"
cp.definitions["^gametarget"]       = "svo.cpp.compute_gametarget_colour()"

if svo.haveskillset('voicecraft') then
  cp.definitions["@voicebal"]      = "svo.cpp.compute_voicebal()"
else
	cp.definitions["@voicebal"]      = "''"
end
if svo.haveskillset('domination') then
  cp.definitions["@entitiesbal"]   = "svo.cpp.compute_entitiesbal()"
else
	cp.definitions["@entitiesbal"]   = "''"
end
if svo.haveskillset('zeal') then
  cp.definitions["@prayerbal"]    = "svo.cpp.compute_prayerbal()"
else
	cp.definitions["@prayerbal"]    = "''"
end
if svo.haveskillset('physiology') then
  cp.definitions["@humourbal"]     = "svo.cpp.compute_humourbal()"
  cp.definitions["@homunculusbal"] = "svo.cpp.compute_homunculusbal()"
else
  cp.definitions["@humourbal"]     = "''"
  cp.definitions["@homunculusbal"] = "''"
end
if svo.haveskillset('venom') then
  cp.definitions["@shrugging"]     = "svo.cpp.compute_shruggingbal()"
else
  cp.definitions["@shrugging"]     = "''"
end
if svo.haveskillset('tekura') or svo.haveskillset('shikudo') then
  cp.definitions["@monkpath"]      = "svo.cpp.compute_monkpath()"
  cp.definitions["@monkstance"]    = "svo.cpp.compute_stanceform()"
  cp.definitions["@monkfull"]      = "svo.cpp.compute_stanceform_verbose()"
else
  cp.definitions["@monkpath"]      = "''"
  cp.definitions["@monkstance"]    = "''"
  cp.definitions["@monkfull"]      = "''"
end
if svo.haveskillset('kaido') then
  cp.definitions["@kai"]           = "svo.cpp.compute_kai()"
else
  cp.definitions["@kai"]           = "''"
end
if svo.haveskillset('shindo') then
  cp.definitions["@shin"]          = "svo.cpp.compute_shin()"
else
  cp.definitions["@shin"]          = "''"
end
  cp.definitions["@timestamp"]     = "svo.cpp.compute_timestamp()"
  cp.definitions["@servertimestamp"] = "svo.cpp.compute_servertimestamp()"
if svo.haveskillset('weaponmastery') then
  cp.definitions["@weaponmastery"] = "svo.cpp.compute_weaponmastery()"
else
  cp.definitions["@weaponmastery"] = "''"
end
if svo.haveskillset('weaponmastery') then
  cp.definitions["@momentum"] = "svo.cpp.compute_momentum()"
else
  cp.definitions["@momentum"] = "''"
end
if svo.haveskillset('metamorphosis') then
  cp.definitions["@morph"]         = "svo.cpp.compute_morph()"
else
  cp.definitions["@morph"]         = "''"
end
if svo.haveskillset('groves') then
  cp.definitions["@sunlight"]      = "svo.cpp.compute_sunlight()"
else
  cp.definitions["@sunlight"]      = "''"
end
if svo.haveskillset('terminus') then
  cp.definitions["@wordbal"]       = "svo.cpp.compute_wordbal()"
else
  cp.definitions["@wordbal"]       = "''"
end
if svo.haveskillset('aeonics') then
  cp.definitions["@age"]           = "svo.cpp.compute_age()"
else
  cp.definitions["@age"]           = "''"
end
if svo.haveskillset('anathema') then
  cp.definitions["@anathemabal"]       = "svo.cpp.compute_anathemabal()"
  cp.definitions["@manifestation"]     = "svo.cpp.compute_manifestation()"
else
  cp.definitions["@anathemabal"]       = "''"
  cp.definitions["@manifestation"]     = "''"
end
if svo.haveskillset('anathema') or svo.haveskillset('occultism') then
  cp.definitions["@karma"]       = "svo.cpp.compute_karma()"
else
  cp.definitions["@karma"]       = "''"
end
if svo.haveskillset('excision') then
  cp.definitions['@wrathbal']       = 'svo.cpp.compute_wrathbal()'
  cp.definitions['@wrath']          = 'svo.cpp.compute_wrath()'
else
  cp.definitions['@wrathbal']       = "''"
  cp.definitions['@wrath']          = "''"
end
  cp.definitions["^1"]             = "svo.cpp.compute_health_colour()"
  cp.definitions["^2"]             = "svo.cpp.compute_mana_colour()"
  cp.definitions["^4"]             = "svo.cpp.compute_willpower_colour()"
  cp.definitions["^5"]             = "svo.cpp.compute_endurance_colour()"
if svo.haveskillset('kaido') then
  cp.definitions["^6"]             = "svo.cpp.compute_kai_colour()"
elseif svo.haveskillset('shindo') then
  cp.definitions["^6"]             = "svo.cpp.compute_shin_colour()"
elseif svo.haveskillset('aeonics') then
  cp.definitions["^6"]             = "svo.cpp.compute_age_colour()"
else
  cp.definitions["^6"]             = "''"
end
if svo.haveskillset('necromancy') then
  cp.definitions["@essence"]      = "svo.cpp.compute_essence()"
else
  cp.definitions["@essence"]      = "''"
end

function cp.adddefinition(tag, func)
  func = string.format("tostring(%s)", func)

  cp.definitions[tag] = func
  cp.makefunction()
end

function cp.makefunction()
  if not conf.customprompt or not sk.logged_in then return end

  local t = cp.generatetable(conf.customprompt)

  local display, error = loadstring("return table.concat({"..table.concat(t, ", ").."})")
  if display then cp.display = display else
    cp.display = function() return '' end
    svo.debugf("Couldn't compile the custom prompt: %s", error)
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
signals.gmcpcharname:connect(cp.makefunction, 'create the prompt function at start')
-- meanwhile, return nothing
cp.display = function() return '' end

-- but also regenerate the function if we're already logged in and this script is saved
if svo.systemloaded then
  cp.makefunction()
end

signals.systemstart:connect(function ()
  if not conf.oldcustomprompt or conf.oldcustomprompt == 'off' then
    conf.oldcustomprompt = conf.customprompt
  end
end, 'remember the oldcustomprompt')

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

end -- end of svo customprompt loader

if svo.systemloaded then svo.loader.customprompt() end