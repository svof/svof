-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.setup = function()

-- The package's own version is the single source of truth, so a release only
-- has to bump it in one place (mfile). Falls back to the last module-era
-- version if the package metadata is unavailable for any reason.
svo.version = (getPackageInfo and getPackageInfo("svof", "version")) or "64"
if svo.version == "" then svo.version = "64" end

if Logger and not svo.systemloaded then
  Logger:LogSection('svof', {'timestamp', split = 5000, 'keepOpen'})
end

local luanotify = {}
luanotify.signal = require("notify.signal")

local lfs = require 'lfs'

local debug = require 'debug'

-- !!
svo.pl = svo.pl or {}
local pl = svo.pl

pl.pretty     = require "pl.pretty"
pl.config     = require "pl.config"
pl.dir        = require "pl.dir"
pl.path       = require "pl.path"
pl.string     = require "pl.stringx"
pl.OrderedMap = require "pl.OrderedMap"
pl.tablex     = require "pl.tablex"

svo.phpTable = function (...) -- abuse to: http://richard.warburton.it
  local newTable,keys,values={},{},{}
  newTable.pairs=function(self) -- pairs iterator
    local count=0
    return function()
      count=count+1
      return keys[count],values[keys[count]]
    end
  end
  setmetatable(newTable,{
    __newindex=function(self,key,value)
      if not self[key] then table.insert(keys,key)
      elseif value==nil then -- Handle item delete
        local count=1
        while keys[count]~=key do count = count + 1 end
        table.remove(keys,count)
      end
      values[key]=value -- replace/create
    end,
    __index=function(self,key) return values[key] end
  })
  local arg = {...}
  for x=1,#arg do
    for k,v in pairs(arg[x]) do newTable[k]=v end
  end
  return newTable
end

function svo.ripairs(t)
  local function ripairs_it(t,i)
    i=i-1
    local v=t[i]
    if v==nil then return v end
    return i,v
  end
  return ripairs_it, t, #t+1
end

function svo.deepcopy(object)
  local lookup_table = {}
  local function _copy(object)
      if type(object) ~= 'table' then
          return object
      elseif lookup_table[object] then
          return lookup_table[object]
      end
      local new_table = {}
      lookup_table[object] = new_table
      for index, value in pairs(object) do
          new_table[_copy(index)] = _copy(value)
      end
      return setmetatable(new_table, getmetatable(object))
  end
  return _copy(object)
end

svo.affs             = svo.affs or {}
local affs           = svo.affs
svo.balanceless      = svo.balanceless or {}
svo.cp               = svo.cp or {}
svo.cpp              = svo.cpp or {}
svo.defences         = svo.defences or {}
local defences       = svo.defences
svo.lifevision       = svo.lifevision or {}
svo.signals          = svo.signals or {}
local signals        = svo.signals
svo.sps              = svo.sps or {}
svo.sys              = svo.sys or {}
local sys            = svo.sys
svo.conf             = svo.conf or {}
svo.empty            = svo.empty or {}
local conf           = svo.conf
svo.config           = svo.config or {}
svo.defc             = svo.defc or {} -- current defences
local defc           = svo.defc
svo.defs             = svo.defs or {}
svo.dragonheal       = svo.dragonheal or {} -- stores dragonheal curing strats
svo.lifep            = svo.lifep or {}
svo.lifevision.l     = svo.lifevision.l or pl.OrderedMap()
svo.paragraph_length = 0
svo.restore          = svo.restore or {}
svo.shrugging        = svo.shrugging or {} -- stores shrugging curing strats
svo.sp               = svo.sp or {} -- parry
svo.sp_config        = svo.sp_config or {}
svo.stats            = svo.stats or {}
local stats          = svo.stats
svo.tree             = svo.tree or {}
svo.rage             = svo.rage or {}
svo.fitness          = svo.fitness or {}
svo.valid            = svo.valid or {}
svo.watch            = svo.watch or {}
svo.gaffl            = svo.gaffl or {}
local gaffl          = svo.gaffl
svo.gdefc            = svo.gdefc or {}
svo.me               = svo.me or {}
local me             = svo.me
svo.sk               = svo.sk or {}
local sk             = svo.sk
svo.vm               = svo.vm or {}
svo.cn               = svo.cn or {}
svo.cnrl             = svo.cnrl or {}
svo.bals             = svo.bals or {}
-- table to keep original functions for when
-- we override Mudlet defaults
svo.ofs              = svo.ofs or {}
svo.actions          = svo.actions or pl.OrderedMap()

svo.reset            = svo.reset or {}
svo.prio             = svo.prio or {}
svo.defdefup = svo.defdefup or {
  basic  = {},
  combat = {},
  empty  = {},
}
svo.defkeepup = svo.defkeepup or {
  basic  = {},
  combat = {},
  empty  = {},
}


local affmt = {
  __tostring = function (self)
      local result = {}
      for i,k in pairs(self) do
        if k.p.count then
          result[#result+1] = i .. ": " ..getStopWatchTime(k.sw).."s (" .. k.p.count .. ")"
        else
          result[#result+1] = i .. ": " ..getStopWatchTime(k.sw)..'s'
        end
      end

      return table.concat(result, ", ")
  end
}
setmetatable(svo.affs, affmt)

svo.affl = svo.affl or {}
svo.serverignore = svo.serverignore or {}
svo.ignore = svo.ignore or {}
svo.dict = svo.dict or {}

local oldecho = svo.conf.commandecho
signals.changecuring = signals.changecuring or luanotify.signal.new()
signals.sync = signals.sync or luanotify.signal.new()
signals.dragonform = signals.dragonform or luanotify.signal.new()

if not svo.systemloaded then
local haddragonform = false
signals.dragonform:add_post_emit(function()
  if svo.defc.dragonform and not haddragonform then
    raiseEvent"svo got dragonform"
    haddragonform = true
  elseif not svo.defc.dragonform and haddragonform then
    raiseEvent"svo lost dragonform"
    haddragonform = false
  end
end, 'post emit dragonform')
end

signals.canoutr = signals.canoutr or luanotify.signal.new()
signals.canoutr:connect(function()
  if (affs.webbed or affs.bound or affs.transfixed or affs.roped or affs.impale or
    ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and
      (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))) then
    svo.sys.canoutr = false
    svo.me.canoutr = false
  else
    svo.sys.canoutr = true
    svo.me.canoutr = true
  end
end, 'update canoutr')


signals.removed_from_rift = signals.removed_from_rift or luanotify.signal.new()
signals.moved = signals.moved or luanotify.signal.new()
signals.systemstart = signals.systemstart or luanotify.signal.new()
signals.systemstart:connect(function() signals.canoutr:emit() end, 'setup canoutr on start')
signals.quit = signals.quit or luanotify.signal.new()
signals.connected = signals.connected or luanotify.signal.new()
signals.quit:connect(function ()
  if Logger then Logger:CloseLog('svo') end
end, 'stop the logger on quit')
signals.quit:add_pre_emit(function () signals.saveconfig:emit() end, 'save config on quit')
signals.quit:add_pre_emit(function () raiseEvent "svo quit" end, 'raise svo quit on quit')
signals.systemend = signals.systemend or luanotify.signal.new()
signals.saveconfig = signals.saveconfig or luanotify.signal.new()

signals.donedefup = signals.donedefup or luanotify.signal.new()



-- gmcp ones
signals.gmcpcharname = signals.gmcpcharname or luanotify.signal.new()
signals.gmcpcharname:connect(function ()
  signals.enablegmcp:emit()
end, 'emit enablegmcp')
signals.gmcproominfo = signals.gmcproominfo or luanotify.signal.new()
signals.gmcpcharstatus = signals.gmcpcharstatus or luanotify.signal.new()
signals.gmcpcharitemslist = signals.gmcpcharitemslist or luanotify.signal.new()
signals.gmcpcharitemslist:connect(function()
  if not gmcp.Char.Items.List.location then
    svo.debugf("(GMCP problem) location field is missing from Achaea's response.")
    return
  end
  if gmcp.Char.Items.List.location ~= 'inv' then return end
  me.inventory = svo.deepcopy(gmcp.Char.Items.List.items)
end, 'update gmcpcharitemslist')
signals.gmcpcharitemsadd = signals.gmcpcharitemsadd or luanotify.signal.new()
signals.gmcpcharitemsadd:connect(function()
  if not gmcp.Char.Items.Add.location then
    svo.debugf("(GMCP problem) location field is missing from Achaea's response.")
    return
  end
  if gmcp.Char.Items.Add.location ~= 'inv' then return end
  me.inventory[#me.inventory + 1] = svo.deepcopy(gmcp.Char.Items.Add.item)
end, 'update gmcpcharitemsadd')
signals.gmcpcharskillsinfo = signals.gmcpcharskillsinfo or luanotify.signal.new()
signals.gmcpcharskillslist = signals.gmcpcharskillslist or luanotify.signal.new()
signals.gmcpcharitemsupdate = signals.gmcpcharitemsupdate or luanotify.signal.new()
signals.gmcpcharitemsupdate:connect(function()
  if not gmcp.Char.Items.Update.location then
    svo.debugf("(GMCP problem) location field is missing from Achaea's response.")
    return
  end
  if gmcp.Char.Items.Update.location ~= 'inv' then return end
  local update = gmcp.Char.Items.Update.item
  for i, item in ipairs(me.inventory) do
    if item.id == update.id then
      me.inventory[i] = svo.deepcopy(gmcp.Char.Items.Update.item)
      break
    end
  end
end, 'update gmcpcharitemsupdate')
signals.gmcpcharitemsremove = signals.gmcpcharitemsremove or luanotify.signal.new()
signals.gmcpcharitemsremove:connect(function()
  if not gmcp.Char.Items.Remove.location then
    svo.debugf("(GMCP problem) location field is missing from Achaea's response.")
    return
  end
  if gmcp.Char.Items.Remove.location ~= 'inv' then return end
  local remove = gmcp.Char.Items.Remove.item
  for i, item in ipairs(me.inventory) do
    if item.id == remove.id then
      table.remove(me.inventory, i)
      break
    end
  end
end, 'update gmcpcharitemsremove')
signals.gmcpcharvitals = signals.gmcpcharvitals or luanotify.signal.new()
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local rage = val:match("^Rage: (%d+)$")
      if rage then
        stats.battlerage = tonumber(rage)
      else
        local bleed = val:match("^Bleed: (%d+)$")
        if bleed then
          if bleed == '0' then
            svo.rmaff('bleeding')
          else
            svo.dict.bleeding.aff.oncompleted(tonumber(bleed))
          end
        end
      end
    end
  end
  if not stats.battlerage then
    stats.battlerage = 0
  end
end, 'update gmcpcharvitals')


local my_class_location = getMudletHomeDir() .. "/svo/config/my_class"
local my_class = {}
if lfs.attributes(my_class_location) then
  table.load(my_class_location, my_class)
end

me.class = me.class or (table.is_empty(my_class) and 'Infernal' or my_class.class)
me.path = me.path or (table.is_empty(my_class)  and ""  or my_class.path)

signals.saveconfig:connect(function()
  svo.tablesave(my_class_location, {class = svo.me.class, path = svo.me.path})
end, 'save my class')


svo.knownskills = {
  alchemist                = {'transmutation', 'physiology', 'alchemy'},
  apostate                 = {'evileye', 'necromancy', 'apostasy'},
  bard                     = {'voicecraft', 'swashbuckling', 'harmonics'},
  blademaster              = {'twoarts', 'striking', 'shindo'},
  depthswalker             = {'shadowmancy','aeonics','terminus'},
  druid                    = {'groves', 'metamorphosis', 'reclamation'},
  infernal                 = {'oppression', 'malignity', 'weaponmastery'},
  jester                   = {'tarot', 'pranks', 'puppetry'},
  magi                     = {'elementalism', 'crystalism', 'artificing'},
  monk                     = {'tekura', 'kaido', 'telepathy', 'shikudo'},
  none                     = {},
  occultist                = {'occultism', 'tarot', 'domination'},
  paladin                  = {'valour', 'excision', 'weaponmastery'},
  pariah                   = {'memorium', 'pestilence', 'charnel'},
  priest                   = {'spirituality', 'devotion', 'zeal'},
  runewarden               = {'runelore', 'discipline', 'weaponmastery'},
  sentinel                 = {'metamorphosis', 'woodlore', 'skirmishing'},
  serpent                  = {'subterfuge', 'venom', 'hypnosis'},
  shaman                   = {'runelore', 'curses', 'vodun'},
  sylvan                   = {'weatherweaving', 'groves', 'propagation'},
  psion                    = {"weaving", "psionics", "emulation"},
  unnamable                = {"anathema","dominion","weaponmastery"},
  ["earth elemental lord"] = {'sculpting'},
  ["fire elemental lord"]  = {'ignition'},
  ["air elemental lord"]   = {'duress'},
  ["water elemental lord"] = {'pervasion'},
  ["earth elemental lady"] = {'sculpting'},
  ["fire elemental lady"]  = {'ignition'},
  ["air elemental lady"]   = {'duress'},
  ["water elemental lady"] = {'pervasion'},
}

me.skills = {}
for _, skill in ipairs(svo.knownskills[me.class:lower()]) do
  me.skills[skill] = true
end


-- optimised haveskillset, since it gets called often: compute a key-value table
-- with all of the skills we have.
do
  local available_skills = {}
  for _, skill in ipairs(svo.knownskills[svo.me.class:lower()]) do
    available_skills[skill] = true
  end

  function svo.haveskillset(skillset)
    return available_skills[skillset] and true or false
  end
end

-- Class resources: Some classes have resources that it is good to keep track. Put them here!
if svo.haveskillset('groves') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local sunlight = val:match("^Sunlight: (%d+)$")
      if sunlight then
        stats.sunlight = tonumber(sunlight)
        break
      end
    end
  end
  if not stats.sunlight then
    stats.sunlight = 0
  end
end, 'update sunlight')
end
if svo.haveskillset('metamorphosis') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local morph = val:match("^Morph: (%w+)$")
      if morph then
        morph = morph:lower()
        me.morph = morph
        if not defc[morph] then
          sk.clearmorphs()
          if morph ~= 'none' then
            defences.got(morph)
          end
        end
        break
      end
    end
  end
  if not me.morph then
    me.morph = ""
  end
end, 'update morph')
end

if svo.haveskillset('tekura') or svo.haveskillset('shikudo') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local stance = val:match("^Stance: (%w+)$")
      local form = val:match("^Form: (%w+)$")

      if stance then
        me.path = 'tekura'
        me.form = nil
        me.stance = stance:lower()
        sk.ignored_defences['tekura'].status = false
        sk.ignored_defences['shikudo'].status = true

        break
      elseif form then
        me.path = 'shikudo'
        me.form = form:lower()
        me.stance = nil
        sk.ignored_defences['tekura'].status = true
        sk.ignored_defences['shikudo'].status = false

        break
      end
    end
  end

  if not me.path then
    me.path = 'tekura'
  end
end, 'update path and form')
end

if svo.haveskillset('necromancy') or svo.haveskillset('oppression') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local essence = val:match("^Essence: (%d+)%%$")
      if essence then
        stats.essence = tonumber(essence)
        break
      end
    end
  end
  if not stats.essence then
    stats.essence = 0
  end
end, 'update necromancy essence')
end

if svo.haveskillset('weaponmastery') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local momentum = val:match("^Momentum: (%d+)$")
      if momentum then
        stats.momentum = tonumber(momentum)
        break
      end
    end
  end
  if not stats.momentum then
    stats.momentum = 0
  end
end, 'update dual blunt momentum')
end

if svo.haveskillset('memorium') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local epitaph_length = val:match("^epitaph_length: (%d+)$")
      if epitaph_length then
        stats.epitaph_length = tonumber(epitaph_length)
        break
      end
    end
  end
  if not stats.epitaph_length then
    stats.epitaph_length = 0
  end
end, 'update memorium epitaph length')
end

if svo.haveskillset('anathema') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local manifestation = val:match("^Manifestation: (%d+)%%$")
      if manifestation then
        stats.manifestation = tonumber(manifestation)
        break
      end
    end
  end
  if not stats.manifestation then
    stats.manifestation = 0
  end
end, 'update anathema manifestation')
end

if svo.haveskillset('anathema') or svo.haveskillset('occultism') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local karma = val:match("^Karma: (%d+)%%$")
      if karma then
        stats.karma = tonumber(karma)
        break
      end
    end
  end
  if not stats.karma then
    stats.karma = 0
  end
end, 'update anathema/occultism karma')
end

if svo.haveskillset('excision') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local wrath = val:match('^Wrath: (%d+)%%$')
      if wrath then
        stats.wrath = tonumber(wrath)
        break
      end
    end
  end
  if not stats.wrath then
    stats.wrath = 0
  end
end, 'update excision wrath')
end

--[[
new model for tertiary balances that don't need to rely on dozens of attack triggers and timers. 
If this works properly and don't error anything out down the road we can extend it to the other balances as well :)
]] 
if svo.haveskillset('anathema') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      local anathema = val:match("^Anathema: (%w+)$")
      if anathema then
        if svo.bals.anathema ~= nil and (svo.bals.anathema == false and anathema == "Yes") then       
          svo.valid.gotanathemabalance()
        break
        elseif svo.bals.anathema ~= nil and (svo.bals.anathema == true and anathema == "No") then
          svo.valid.usedanathemabalance()
        break
        end
      end
    end
  end
end, 'update anathema balance')
end

if svo.haveskillset('excision') then
signals.gmcpcharvitals:connect(function()
  if gmcp.Char.Vitals.charstats then
    
    for _, val in ipairs(gmcp.Char.Vitals.charstats) do
      
      local wrathbal = val:match('^wrathbal: (%w+)$')
      if wrathbal then
        if svo.bals.wrathbal ~= nil and (svo.bals.wrathbal == false and wrathbal == 'Yes') then       
          svo.valid.gotwrathbalbalance()
        break
        elseif svo.bals.wrathbal ~= nil and (svo.bals.wrathbal == true and wrathbal == 'No') then
          svo.valid.usedwrathbalbalance()
        break
        end
      end
    end
  end
end, 'update wrathbal balance')
end

-- End of class resources

signals.gmcpiretimelist = signals.gmcpiretimelist or luanotify.signal.new()
signals.gmcpiretimelist:connect(function()
  me.gametime = svo.deepcopy(gmcp.IRE.Time.List)
end, 'update gametime')
signals.gmcpiretimeupdate = signals.gmcpiretimeupdate or luanotify.signal.new()
signals.gmcpiretimeupdate:connect(function()
  me.gametime = me.gametime or {}
  for k, v in pairs(gmcp.IRE.Time.Update) do
    me.gametime[k] = v
  end
end, 'update gametime')

signals.gmcpcharafflictionslist = signals.gmcpcharafflictionslist or luanotify.signal.new()
signals.gmcpcharafflictionsremove = signals.gmcpcharafflictionsremove or luanotify.signal.new()
signals.gmcpcharafflictionsadd = signals.gmcpcharafflictionsadd or luanotify.signal.new()

signals.gmcpchardefenceslist = signals.gmcpchardefenceslist or luanotify.signal.new()
signals.gmcpchardefencesremove = signals.gmcpchardefencesremove or luanotify.signal.new()
signals.gmcpchardefencesadd = signals.gmcpchardefencesadd or luanotify.signal.new()


signals.gmcpcharafflictionsadd:connect(function()
  local thisaff = gmcp.Char.Afflictions.Add.name
  local affcount = tonumber(string.match(gmcp.Char.Afflictions.Add.name, "%d"))
  local affname = ""
  if string.match(gmcp.Char.Afflictions.Add.name, "%d") then affname = thisaff:sub(1, -5) end
  if thisaff:sub(-4) == " (1)" then thisaff = thisaff:sub(1, -5) end
  gaffl[thisaff] = true
  if conf.gmcpaffechoes then svo.echof("Gained aff %s", thisaff) end
  if svo.dict.sstosvoa[thisaff] then
    svo.addaffdict(svo.dict[svo.dict.sstosvoa[thisaff]])
  end
  if affname ~= "" then
    if svo.dict.sstosvoa[affname] then
      svo.addaffdict(svo.dict[svo.dict.sstosvoa[affname]])
    end
  end
  if affcount ~= nil and svo.dict[svo.dict.sstosvoa[affname]].count ~= nil then
    svo.dict[svo.dict.sstosvoa[affname]].count = affcount
  end
  if affcount ~= nil and table.contains(svo.affl, svo.dict[svo.dict.sstosvoa[affname]].name) then
    svo.updateaffcount(svo.dict[svo.dict.sstosvoa[affname]])
  end
  sk.checkaeony()
  signals.changecuring:emit()
end, 'track gained gmcp aff')

signals.gmcpcharafflictionsremove:connect(function()
  local thisaff = gmcp.Char.Afflictions.Remove[1]
  local affcount = tonumber(string.match(gmcp.Char.Afflictions.Remove[1], "%d"))
  local affname = ""
  if string.match(gmcp.Char.Afflictions.Remove[1], "%d") then affname = thisaff:sub(1, -5) end
  --If level 1 of an affliction is removed, then the aff is completely gone
  if thisaff:sub(-4) == " (1)" then thisaff = thisaff:sub(1, -5) end
  gaffl[thisaff] = nil
  if conf.gmcpaffechoes then svo.echof("Cured aff %s", thisaff) end
  if svo.dict.unknownany.count >= 1 and not svo.affl[affname] then
    svo.valid.remove_unknownany(affname)
  end
  if svo.dict.sstosvoa[thisaff] then
    svo.rmaff(svo.dict[svo.dict.sstosvoa[thisaff]])
  elseif affname ~= "" then
    if svo.dict.sstosvoa[affname] then
      svo.rmaff(svo.dict[svo.dict.sstosvoa[affname]])
    end
  end
  if affcount ~= nil and svo.dict[svo.dict.sstosvoa[affname]].count ~= nil then
    svo.dict[svo.dict.sstosvoa[affname]].count = 0
  end
  sk.checkaeony()
  signals.changecuring:emit()
end, 'track lost gmcp aff')

signals.gmcpcharafflictionslist:connect(function()
  svo.gaffl = {}
  local preaffl = {}
  for _, val in ipairs(svo.affl) do preaffl[val] = true end

  for _, val in ipairs(gmcp.Char.Afflictions.List) do
    local thisaff = val.name
    if thisaff:sub(-4) == " (1)" then thisaff = thisaff:sub(1, -5) end
    gaffl[thisaff] = true
    local svoAffliction = svo.dict.sstosvoa[thisaff]
    if svoAffliction then
      if preaffl[svoAffliction] then
        preaffl[svoAffliction] = false
      else
        svo.addaff(svoAffliction)
      end
    end
  sk.checkaeony()
  signals.changecuring:emit()
  end

  for key, val in pairs(preaffl) do
    if val then svo.rmaff(key) end
  end
end, 'update list of gmcp affs')


signals.gmcpchardefencesadd:connect(function()
  local thisdef = gmcp.Char.Defences.Add.name
  svo.gdefc[thisdef] = true
  if conf.gmcpdefechoes then svo.echof("Gained def "..thisdef) end
  if svo.dict.sstosvod[thisdef] then
    if type(svo.defs['got_'..svo.dict.sstosvod[thisdef]]) == 'function' then
      svo.defs['got_'..svo.dict.sstosvod[thisdef]](true)
    end
  end
end, 'track gained gmcp def')

signals.gmcpchardefencesremove:connect(function()
  local thisdef = gmcp.Char.Defences.Remove[1]
  svo.gdefc[thisdef] = nil
  if conf.gmcpdefechoes then svo.echof("Lost def "..thisdef) end
  if svo.dict.sstosvod[thisdef] then
    if type(svo.defs['lost_'..svo.dict.sstosvod[thisdef]]) == 'function' then
      svo.defs['lost_'..svo.dict.sstosvod[thisdef]]()
    end
  end
end, 'track lost gmcp def')

signals.gmcpchardefenceslist:connect(function()
  svo.gdefc = {}
  local predefs = svo.deepcopy(defc)
  for _, val in ipairs(gmcp.Char.Defences.List) do
    local thisdef = val.name
    svo.gdefc[thisdef] = true
    if svo.dict.sstosvod[thisdef] then
      if predefs[svo.dict.sstosvod[thisdef]] then
        predefs[svo.dict.sstosvod[thisdef]] = false
      elseif type(svo.defs['got_'..svo.dict.sstosvod[thisdef]]) == 'function' then
        svo.defs['got_'..svo.dict.sstosvod[thisdef]](true)
      end
    end
  end
  for defname, val in pairs(predefs) do
    if val == true and svo.dict.sstosvod[defname] then
      if type(svo.defs['lost_'..svo.dict.sstosvod[defname]]) == 'function' then
        svo.defs['lost_'..svo.dict.sstosvod[defname]]()
      end
    end
  end
end, 'update list of defs from gmcp')

-- make a 'signals bank' that remembers all gmcp events that happend before the prompt.
-- reset on prompt. check it for stuff when necessary.
-- have the herb out signal be remembers on it's own & verified by the syste

do
  local oldnum, oldarea
  signals.gmcproominfo:connect(function ()
    if me then
        if table.contains(gmcp.Room.Info.details, 'underwater') then
            me.is_underwater = true
        else
            me.is_underwater = false
        end
    end

    if oldnum ~= gmcp.Room.Info.num then
      signals.newroom:emit(_G.gmcp.Room.Info.name)
      oldnum = gmcp.Room.Info.num
    end

    signals.anyroom:emit(_G.gmcp.Room.Info.name)

    if oldarea ~= gmcp.Room.Info.area then
      signals.newarea:emit(_G.gmcp.Room.Info.area)
      oldarea = gmcp.Room.Info.area
    end
  end, 'track underwater status')
end

-- atcp ones
signals.charname = signals.charname or luanotify.signal.new()
signals.roombrief = signals.roombrief or luanotify.signal.new()

do
  local oldnum
  signals.roombrief:connect(function (...)
    if oldnum ~= atcp.RoomNum then
      signals.newroom:emit(({...})[1])
      oldnum = atcp.RoomNum
    end

    signals.anyroom:emit(({...})[1])
  end, 'setup newroom tracking')
end

-- general ones
signals.relogin = signals.relogin or luanotify.signal.new()
signals.enablegmcp = signals.enablegmcp or luanotify.signal.new()

if not svo.systemloaded then
signals.enablegmcp:add_post_emit(function ()
  tempBeginOfLineTrigger("Password correct. Welcome to Achaea.", function() svo.logging_in = false signals.changecuring:emit() end, 5)  
  if not sys.enabledgmcp then
    sys.enabledgmcp = true
  else
    signals.relogin:emit()
    svo.echof("Welcome back!")
    -- svo.defs.quietswitch('basic')
  end
  -- app('off', true) -- this triggers a svo.dict() run too early before login
  if svo.dont_unpause_login then svo.dont_unpause_login = nil
  else conf.paused = false end

  svo.innews = false
end, 'post emit enablegmcp')
end

registerAnonymousEventHandler("sysLoadEvent", function () svo.logging_in = true signals.changecuring:emit() end)
registerAnonymousEventHandler("sysConnectionEvent", function () svo.logging_in = true signals.changecuring:emit() end)

signals.newroom = signals.newroom or luanotify.signal.new()
signals.newarea = signals.newarea or luanotify.signal.new()
signals.anyroom = signals.anyroom or luanotify.signal.new()
signals.changed_maxhealth = signals.changed_maxhealth or luanotify.signal.new()
signals.changed_maxhealth:connect(function (old, new) -- can't use add_post_emit, as that doesn't pass arguments down
  if not string.find(debug.traceback(), 'Alias', 1, true) then
    if not (old and new) or (old and old == 1) then
      svo.echof("Your max health changed to %dh.", stats.maxhealth)
    elseif old > new then
      svo.echof("Your max health decreased by %dh/%d%% to %d.", (old-new), 100-math.floor((100/old)*new), new)
    else
      svo.echof("Your max health increased by %dh/%d%% to %d.", (new-old), (math.floor((100/old)*new)-100), new)

      -- track stain
      sk.gotmaxhealth = true
      svo.prompttrigger("check stain expiring", function()
        if svo.paragraph_length == 0 and sk.gotmaxhealth and sk.gotmaxmana and svo.affs.stain then
          svo.rmaff('stain')
          svo.echof("I think stain faded.")
        end
        sk.gotmaxhealth, sk.gotmaxmana = nil, nil
      end)
    end
  end
end, 'update maxhealth tracking')
signals.changed_maxmana = signals.changed_maxmana or luanotify.signal.new()
signals.changed_maxmana:connect(function (old, new)
  if not string.find(debug.traceback(), 'Alias', 1, true) then
    if not (old and new) or (old and old == 1) then
      svo.echof("Your max mana changed to %dm.", stats.maxmana)
    elseif old > new then
      svo.echof("Your max mana decreased by %dm/%d%% to %d.", (old-new), 100-math.floor((100/old)*new), new)
    else
      svo.echof("Your max mana increased by %dm/%d%% to %d.", (new-old), (math.floor((100/old)*new)-100), new)

      sk.gotmaxmana = true
      svo.prompttrigger("check stain expiring", function()
        if svo.paragraph_length == 0 and sk.gotmaxhealth and sk.gotmaxmana and svo.affs.stain then
          svo.rmaff('stain')
          svo.echof("I think stain faded.")
        end
        sk.gotmaxhealth, sk.gotmaxmana = nil, nil
      end)
    end
  end
end, 'update maxmana tracking')

signals.before_prompt_processing = signals.before_prompt_processing or luanotify.signal.new()
signals.after_prompt_processing = signals.after_prompt_processing or luanotify.signal.new()
signals.after_lifevision_processing = signals.after_lifevision_processing or luanotify.signal.new()

signals.curedwith_focus = signals.curedwith_focus or luanotify.signal.new()
signals.curemethodchanged = signals.curemethodchanged or luanotify.signal.new()
signals.limbhit = signals.limbhit or luanotify.signal.new()
signals.loadconfig = signals.loadconfig or luanotify.signal.new()
signals.orgchanged = signals.orgchanged or luanotify.signal.new()
signals.sysdatasendrequest = signals.sysdatasendrequest or luanotify.signal.new()
if svo.haveskillset('metamorphosis') then
signals.morphskillchanged = signals.morphskillchanged or luanotify.signal.new()
end

if not svo.systemloaded then
  signals.saveconfig:add_post_emit(function ()
    echo"\n"
    svo.echof("Saved system settings.")
  end, 'post emit saveconfig')
end

signals.loadedconfig = signals.loadedconfig or luanotify.signal.new()
signals.svogotaff = signals.svogotaff or luanotify.signal.new()
signals.svolostaff = signals.svolostaff or luanotify.signal.new()
signals.sysexitevent = signals.sysexitevent or luanotify.signal.new()
signals["mmapper updated pdb"]       = luanotify.signal.new()
signals["svo config changed"]        = luanotify.signal.new()
signals["svo defup changed"]         = luanotify.signal.new()
signals["svo got balance"]           = luanotify.signal.new()
signals["svo ignore changed"]        = luanotify.signal.new()
signals["svo keepup changed"]        = luanotify.signal.new()
signals["svo lost balance"]          = luanotify.signal.new()
signals["svo prio changed"]          = luanotify.signal.new()
signals["svo serverignore changed"]  = luanotify.signal.new()
signals["svo switched defence mode"] = luanotify.signal.new()
signals["svo system loaded"]         = luanotify.signal.new()
signals["svo done defup"]            = luanotify.signal.new()


if not svo.systemloaded then
  conf.siphealth            = 80
  conf.sipmana              = 70
  conf.mosshealth           = 60
  conf.mossmana             = 60
  conf.assumestats          = 15

  conf.ai_resetfocusbal     = 5
  conf.ai_resetsipbal       = 7 -- was 5 before, but started overrunning
  conf.ai_resetherbbal      = 2.5 -- normally at 1.6
  conf.ai_resetsalvebal     = 5
  conf.ai_resetmossbal      = 10  -- resets at 6
  if svo.haveskillset('zeal') then
    -- resets at 3 for blessings, 4 for benediction 1.6-2.3 for affs
    conf.ai_resetprayerbal        = 4
  end
  conf.ai_resetpurgativebal = 10 -- it's 7s for voyria
  conf.ai_resetdragonhealbal = 20 -- 20s for dragonheal
  conf.ai_resetsmokebal = 2 -- ~1.5s for smoking bal

  conf.ai_minherbbal        = 1.0
  conf.ai_restoreckless     = 0.4
  conf.ai_minrestorecure    = 3.5
  conf.tekura_delay         = 0.050

  conf.classattacksamount   = 3
  conf.classattackswithin   = 15
  conf.enableclassesfor     = 2

  conf.singlepromptsize     = 11

  conf.gagotherbreath       = true
  conf.gagbreath            = true

  conf.burrowpause          = true

  conf.changestype          = 'shortpercent'

  conf.paused               = false
  conf.lag                  = 0
  sys.wait                  = 0.7 -- for lag
  conf.aillusion            = true -- on by deafult, disable it if necessary
  conf.keepup               = true

  conf.burstmode            = 'empty'
  conf.slowcurecolour       = 'blue'
  conf.hinderpausecolour    = 'orange'

  conf.sacdelay             = 0.5 -- delay after which the systems curing should resume in sync mode

  conf.bleedamount          = 60
  conf.manableedamount      = 60
  conf.corruptedhealthmin   = 70
  conf.manause              = 35

  conf.fluiddelay           = 0.3
  conf.smallbleedremove     = 8

  conf.eventaffs            = true
  conf.autoarena            = true

  -- have skills?
  conf.commandecho          = true
  conf.blockcommands        = true
  conf.commandechotype      = 'fancy'
  conf.warningtype          = 'right'

  conf.autoreject           = 'white'
  conf.doubledo             = false

  conf.ridingskill          = 'mount'
  conf.ridingsteed          = 'pony'

  conf.screenwidth          = 100
  conf.refillat             = 1
  conf.waitherbai           = true
  conf.noeqtimeout          = 5

  conf.autoslick            = true
  conf.showbaltimes         = true
  conf.showafftimes         = true

  conf.steedfollow          = true
  conf.autoclasses          = true

  conf.ccto                 = 'pt'
  conf.repeatcmd            = 0

  if svo.haveskillset('kaido') then
  conf.transmute            = 'supplement'
  conf.transmuteamount      = 70
  end

  if svo.haveskillset('devotion') then
  conf.bloodswornoff        = 30
  end

  conf.gagclot              = true
  conf.gagrelight           = false
  conf.relight              = true

  conf.passive_eqloss       = 10

  conf.highlightparryfg     = 'white'
  conf.highlightparrybg     = 'blue'

  conf.autotsc              = true
  conf.ignoresinglebites    = false

  conf.medprone             = false
  conf.unmed                = false

  conf.pagelength           = 20
  conf.treebalance          = 0

  conf.healthaffsabove      = 70

  conf.batch                = true

  conf.curemethod = 'conconly'
  signals.systemstart:add_post_emit(function()
    if not conf.curemethod or conf.curemethod == 'auto' then
      conf.curemethod = 'conconly'
    end
  end, 'post emit adjust cure method')

  conf.ninkharsag = true
end

sys.sync = false
sys.deffing = false
sys.balanceid = 0
sys.balancetick = 1
sys.lagcount, sys.lagcountmax = 0, 3
sys.actiontimeout = 3
sys.actiontimeoutid = false
sys.manause = 0
sys.sipmana, sys.siphealth, sys.mosshealth, sys.mossmana = 0, 0, 0, 0
sys.transmuteamount = 0

sys.sp_satisfied, sys.blockparry = false, false
sys.canoutr = true

-- the in-game custom prompt needs to show the game target and game target hp, since
-- that isn't available in GMCP at the moment, as well as any class-specific balances and values
if not svo.haveskillset('weaponmastery') then
sys.ingamecustomprompt ="CONFIG PROMPT CUSTOM *hh, *mm, *ee, *ww *t*T *b*d*c-*r-s*s-"
else
-- account for ferocity
sys.ingamecustomprompt ="CONFIG PROMPT CUSTOM *hh, *mm, *ee, *ww *t*T *b*d*c-*r-k*k-s*s-"
end
-- used in lyre actions to prevent doubledo from activating - since that'd destroy the lyre right away
sys.sendonceonly = false

-- a map that has possible commands linked to svo.dict.action.balance entries
sys.input_to_actions = {}
-- a map that stores svo.dict.action.balance.name
sys.last_used = {}

---

svo.danaeusaffs = {'agoraphobia', 'claustrophobia', 'dizziness', 'epilepsy', 'hypersomnia', 'vertigo'}
svo.nemesisaffs = {'agoraphobia', 'recklessness', 'confusion', 'masochism', 'loneliness'}
svo.scragaffs   = {'clumsiness', 'healthleech', 'lethargy', 'sensitivity', 'haemophilia', 'darkshade'}

---

stats.nextlevel,
stats.currenthealth, stats.maxhealth,
stats.currentmana, stats.maxmana,
stats.currentendurance, stats.maxendurance,
stats.currentwillpower, stats.maxwillpower = 1,1,1,1,1,1,1,1,1

if svo.haveskillset('kaido') then
stats.kai = 0
end

---
me.wielded = me.wielded or {}
me.oldhealth = 0

me.doqueue = {repeating = false}
me.dofreequeue = {}
me.dopaused = false
me.lustlist = {} -- list if names not to add lovers aff for
me.hoistlist = {} -- list if names not to add hoisted aff for
me.lasthitlimb = 'head' -- last hit limb
me.disableddragonhealfunc = {}
me.disabledrestorefunc    = {}
if svo.haveskillset('venom') then
me.disabledshruggingfunc  = {}
end
me.disabledtreefunc       = {}
me.disabledragefunc       = {}
me.disabledfitnessfunc       = {}
me.unparryables = {}
me.focusedknights = {}
me.locks = {}
me.curelist = {
  ash         = 'ash',
  bayberry    = 'bayberry',
  bellwort    = 'bellwort',
  bloodroot   = 'bloodroot',
  caloric     = 'caloric',
  cohosh      = 'cohosh',
  echinacea   = 'echinacea',
  elm         = 'elm',
  epidermal   = 'epidermal',
  frost       = 'frost',
  ginger      = 'ginger',
  ginseng     = 'ginseng',
  goldenseal  = 'goldenseal',
  hawthorn    = 'hawthorn',
  health      = 'health',
  immunity    = 'immunity',
  irid        = 'irid',
  kelp        = 'kelp',
  kola        = 'kola',
  levitation  = 'levitation',
  lobelia     = 'lobelia',
  mana        = 'mana',
  mass        = 'mass',
  mending     = 'mending',
  myrrh       = 'myrrh',
  pear        = 'pear',
  restoration = 'restoration',
  sileris     = 'sileris',
  skullcap    = 'skullcap',
  speed       = 'speed',
  valerian    = 'valerian',
  venom       = 'venom',
}


me.cadmusaffs = me.cadmusaffs or {
  ['agoraphobia']    = false,
  ['anorexia']       = true,
  ['claustrophobia'] = false,
  ['confusion']      = false,
  ['dizziness']      = false,
  ['epilepsy']       = false,
  ['fear']           = false,
  ['generosity']     = false,
  ['loneliness']     = false,
  ['masochism']      = false,
  ['pacifism']       = false,
  ['recklessness']   = true,
  ['shyness']        = false,
  ['stupidity']      = true,
  ['unknownmental']  = false,
  ['vertigo']        = false,
  ['weakness']       = false,
}

me.inventory = {}

me.getitem = function(name)
  for _, thing in ipairs(me.inventory) do
    if thing.name == name then
      return thing
    end
  end
end
---

if not svo.haveskillset('shindo') then
disableTrigger("Shindo defences")
else
enableTrigger("Shindo defences")
end

if not svo.haveskillset('kaido') then
disableTrigger("Kaido defences")
else
enableTrigger("Kaido defences")
end

if not svo.haveskillset('tekura') and not svo.haveskillset('shikudo') then
disableTrigger("Monk balances")
else
enableTrigger("Monk balances")
end

if svo.me.class == 'Druid' then
enableTrigger("Hydra balance")
else
disableTrigger("Hydra balance")
end

if svo.haveskillset('voicecraft') then
enableTrigger("Voice balance")
else
disableTrigger("Voice balance")
end

if svo.haveskillset('zeal') then
enableTrigger("Prayer balance")
else
disableTrigger("Prayer balance")
end

if svo.haveskillset('discipline') or svo.haveskillset('malignity') or 
  svo.haveskillset('valour') or svo.haveskillset('dominion') or 
  svo.haveskillset('shindo') or svo.haveskillset('kaido') or 
  svo.haveskillset('metamorphosis') then
enableTrigger("Fitness balance")
else
disableTrigger("Fitness balance")
end

if svo.haveskillset('discipline') or svo.haveskillset('malignity') or svo.haveskillset('valour') or svo.haveskillset('dominion') then
enableTrigger("Rage balance")
else
disableTrigger("Rage balance")
end

if svo.haveskillset('weaponmastery') then
enableTrigger("Two-hander recover footing")
else
disableTrigger("Two-hander recover footing")
end

if svo.haveskillset('domination') then
enableTrigger("Domination entities balance")
else
disableTrigger("Domination entities balance")
end

if svo.haveskillset('venom') then
enableTrigger("Shrugging balance")
else
disableTrigger("Shrugging balance")
end

if svo.haveskillset('elementalism') then
enableTrigger("Elementalism channels")
else
disableTrigger("Elementalism channels")
end

if svo.haveskillset('elementalism') then
enableAlias("Elementalism aliases")
else
disableAlias("Elementalism aliases")
end

if svo.haveskillset('spirituality') then
enableTrigger("Spirituality defences")
enableAlias("Spirituality aliases")
else
disableTrigger("Spirituality defences")
disableAlias("Spirituality aliases")
end

if svo.haveskillset('propagation') then
enableTrigger("Propagation defences")
else
disableTrigger("Propagation defences")
end

if svo.haveskillset('necromancy') then
enableTrigger("Necromancy defences")
else
disableTrigger("Necromancy defences")
end

if not svo.haveskillset('occultism') then
disableTrigger("Occultism defences")
else
enableTrigger("Occultism defences")
end

if not svo.haveskillset('alchemy') then
disableTrigger("Alchemy defences")
else
enableTrigger("Alchemy defences")
end

if not svo.haveskillset('groves') then
disableTrigger("Groves defences")
else
enableTrigger("Groves defences")
end

if not svo.haveskillset('harmonics') then
disableTrigger("Harmonics defences")
else
enableTrigger("Harmonics defences")
end

if not svo.haveskillset('physiology') then
disableTrigger("Humour balance")
else
enableTrigger("Humour balance")
end

if svo.haveskillset('terminus') then
enableTrigger("Word balance")
else
disableTrigger("Word balance")
end

if svo.haveskillset('aeonics') then
enableTrigger("Age tracking")
else
disableTrigger("Age tracking")
end

-- local oldsend
-- local defupfinish, process_defs
-- local wait_tbl

svo.index_map = pl.tablex.index_map

-- local addaff, rmaff, checkanyaffs, updateaffcount

-- lostbal_focus, lostbal_herb, lostbal_salve, lostbal_purgative, lostbal_sip
sk.salvetick, sk.herbtick, sk.focustick, sk.teatick = 0, 0, 0, 0
sk.purgativetick, sk.siptick, sk.mosstick, sk.dragonhealtick = 0, 0, 0, 0
sk.smoketick, sk.voicetick, sk.wordtick =  0, 0, 0

if svo.haveskillset('zeal') then
  sk.prayertick = 0
end

if svo.haveskillset('venom') then
sk.shruggingtick = 0
end
if svo.haveskillset('discipline') or svo.haveskillset('malignity') or 
  svo.haveskillset('valour') or svo.haveskillset('dominion') or 
  svo.haveskillset('shindo') or svo.haveskillset('kaido') or 
  svo.haveskillset('metamorphosis') then
sk.fitnesstick = 0
end
if svo.haveskillset('discipline') or svo.haveskillset('malignity') or svo.haveskillset('valour') or svo.haveskillset('dominion') then
sk.ragetick = 0
end
if svo.haveskillset('weaponmastery') then
sk.didfootingattack = false
end

sk.diag_list = sk.diag_list or {}
sk.priosbeforechange = sk.priosbeforechange or {}
 -- caches prio changes, so none need to happen on holes in svo's prios
sk.priochangecache = sk.priochangecache or { special = {} }
-- queue of commands to batch into a serverside alias for curing
sk.sendqueue = sk.sendqueue or {}
sk.affqueue = sk.affqueue or {}
sk.defqueue = sk.defqueue or {}
-- keep track of the length of the command - max command length in Achaea is 2048
sk.sendqueuel = 18 -- 'setalias multicmd ' is 24 characters
sk.achaea_command_max_length = 2048

-- a buffer to keep track of the commands the system has sent
sk.systemscommands = {}

svo.promptcount, svo.lastpromptnumber = 0, 0
svo.send = _G.send

-- possible afflictions that need to go through a check first
svo.affsp               = svo.affsp or {}
svo.rift                = svo.rift or {}
svo.pipes               = svo.pipes or {}
svo.install             = svo.install or {}
svo.life                = svo.life or {}
svo.echos               = svo.echos or {}
svo.echosd              = svo.echosd or {}
sk.ignored_defences     = sk.ignored_defences or {}
sk.ignored_defences_map = sk.ignored_defences_map or {}
sk.zeromana             = false
svo.pflags              = svo.pflags or {}

--[=[
uncommented for now: Makes svof prone to illusions with server side turned on
signals.svogotaff:connect(function(isloki)
  if svo.dict.svotossa[isloki] and not gaffl[svo.dict.svotossa[isloki]] and conf.serverside then
    svo.echof("Svo caught "..isloki.." ("..svo.dict.svotossa[isloki].."), predicting for serverside.")
    send("CURING PREDICT "..svo.dict.svotossa[isloki])
  end
end)
--]=]

function svo.assert(condition, msg, extra)
  if not condition then
    if extra then
      extra(msg)
    else
      error(msg)
    end
  end
end

sk.checkaeony = function()
  if (affs.aeon or affs.retardation) and not sys.sync then
    oldecho = conf.commandecho
    conf.commandecho = true
    sys.sync = true
    signals.sync:emit()
    signals.sysdatasendrequest:unblock(svo.cnrl.processcommand)

    -- kill actions prior to this, so we can do aeon
    local to_kill = {}
    for _,v in svo.actions:iter() do
      if v.p.balance ~= 'waitingfor' and v.p.balance ~= 'aff' and v.p.balance ~= 'gone' and
        v.p.name ~= 'aeon_smoke' and v.p.name ~= 'checkslows_misc' and v.p.name ~= 'touchtree_misc' then
      -- don't kill aeon_smoke: if we do, we double-smoke. instead, since smoke is started before sync is set:
      -- add a customwait delay. Don't kill tree touching either, could help for asthma
        to_kill[#to_kill+1] = svo.dict[v.p.action_name][v.p.balance]
      end
    end

    local killaction = svo.killaction
    for _, action in ipairs(to_kill) do
      killaction(action)
    end

    echo("\n")
    svo.echof("%s mode enabled.", (math.random(1, 20) == 20 and 'Matrix' or "Slow curing"))

    if conf.autotsc then
      if affs.retardation then
        conf.blockcommands = false -- bypass config.set, because that calls gnomes for us
        echo"\n" svo.echof(" (autotsc) - command overrides enabled.")
      elseif affs.aeon then
        conf.blockcommands = true
        echo"\n" svo.echof(" (autotsc) - command denies enabled.")
      end
    end
  elseif sys.sync and not (affs.aeon or affs.retardation) then
    conf.commandecho = oldecho
    sys.sync = false
    signals.sync:emit()
    signals.sysdatasendrequest:block(svo.cnrl.processcommand)
    echo("\n")
    svo.echof("Slow curing mode disabled.")
  end
end

signals.systemstart:connect(function ()
  (tempExactMatchTrigger or tempTrigger)("You open your mouth but say nothing.",
    [[svo.valid.saidnothing()]]);

  (tempExactMatchTrigger or tempTrigger)("You are not fallen or kneeling.",
    [[svo.valid.nothingtowield()]]);

  (tempExactMatchTrigger or tempTrigger)("You stand up and stretch your arms out wide.",
    [[svo.valid.nothingtowield()]]);

  (tempExactMatchTrigger or tempTrigger)("What do you want to eat?",
    [[svo.valid.nothingtoeat()]]);

  (tempExactMatchTrigger or tempTrigger)("You inhale deeply and begin holding your breath.",
    [[svo.valid.lungsokay()]]);

  (tempExactMatchTrigger or tempTrigger)("Sticky strands of webbing cling to you, making that impossible.",
    [[svo.valid.symp_webbed()]]);

  (tempExactMatchTrigger or tempTrigger)("You are too tangled up to do that.",
    [[svo.valid.symp_roped()]]);
  (tempExactMatchTrigger or tempTrigger)("Your legs are tangled in a mass of rope and you cannot move.",
    [[svo.valid.symp_roped()]]);

  (tempExactMatchTrigger or tempTrigger)("Your lungs are too weak to hold your breath.",
    [[svo.valid.weakbreath()]]);

  (tempExactMatchTrigger or tempTrigger)("You are impaled and must writhe off before you may do that.",
    [[svo.valid.symp_impaled()]]);
  (tempExactMatchTrigger or tempTrigger)("The weapon that transfixes your gut makes leaving impossible.",
    [[svo.valid.symp_impaled()]]);

  (tempExactMatchTrigger or tempTrigger)("You move sluggishly into action.",
    [[svo.valid.webeslow()]]);

  (tempExactMatchTrigger or tempTrigger)("You are transfixed and cannot do that. You must writhe to escape.",
    [[svo.valid.symp_transfixed()]]);
end, 'setup anti-illusion triggers');

if svo.haveskillset('metamorphosis') then
  (tempExactMatchTrigger or tempTrigger)(
    "You take a deep breath and realise your error - you sputter and engulf yourself in fire!",
    [[svo.valid.simpleablaze()]]);

  tempRegexTrigger([[^Your soul quakes and shifts as the spirits depart, leaving you .+ once more\.$]],
    [[
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor',
        'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla',
         'icewyrm', 'wyvern', 'hydra'} do
        if svo.defc[morph] then svo.defs['lost_'..morph]() end
      end
    ]]);

  tempRegexTrigger([[^You remain in .+ form, dolt\.$]],
    [[
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor',
        'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla',
        'icewyrm', 'wyvern', 'hydra'} do
        if svo.defc[morph] then svo.defs['lost_'..morph]() end
      end
    ]]);

  tempRegexTrigger([[^You are already in .+ form\.$]],
    [[
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor',
        'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla',
        'icewyrm', 'wyvern', 'hydra'} do
        if svo.defc[morph] then svo.defs['lost_'..morph]() end
      end
    ]]);

  tempRegexTrigger(
    [[^You writhe in spiritual torment as the creature spirit is torn from your soul \- you are .+ once more\.$]],
    [[
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor',
        'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla',
        'icewyrm', 'wyvern', 'hydra'} do
        if svo.defc[morph] then svo.defs['lost_'..morph]() end
        svo.valid.simplecantmorph()
      end
    ]]);

  (tempExactMatchTrigger or tempTrigger)("You cannot possibly morph again so soon.", "svo.valid.simplecantmorph()");

  (tempExactMatchTrigger or tempTrigger)(
    "You feel your bond with the animal spirits strengthen, allowing you to morph once again.",
    [[svo.valid.cantmorph_woreoff()]]);
end

color_table.a_darkred     = {128, 0, 0}
color_table.a_darkgreen   = {0, 179, 0}
color_table.a_brown       = {128, 128, 0}
color_table.a_darkblue    = {0, 0, 128}
color_table.a_darkmagenta = {128, 0, 128}
color_table.a_darkcyan    = {0, 128, 128}
color_table.a_grey        = {192, 192, 192}
color_table.a_darkgrey    = {128, 128, 128}
color_table.a_red         = {255, 0, 0}
color_table.a_green       = {0, 255, 0}
color_table.a_yellow      = {255, 255, 0}
color_table.a_blue        = {0, 85, 255}
color_table.a_magenta     = {255, 0, 255}
color_table.a_cyan        = {0, 255, 255}
color_table.a_white       = {255, 255, 255}
color_table.a_darkwhite   = {192, 192, 192}
color_table.a_darkyellow  = {179, 179, 0}
-- 2D2E2E, 676562, 433020, 28BA28, 398C39, 0D790D
color_table.a_onelevel    = {45, 46, 46}
color_table.a_twolevel    = {103, 101, 98}
color_table.a_threelevel  = {67, 48, 32}
color_table.a_fourlevel   = {40, 186, 40}
color_table.a_fivelevel   = {57, 140, 57}
color_table.a_sixlevel    = {13, 121, 13}
color_table.blaze_orange  = {255, 102, 0}


-- check if the person imported the xml many times by accident
signals.systemstart:connect(function ()
  local toomany, types = {}, {'alias', 'trigger'} -- add scripts when exists() function supports it

  for _, type in ipairs(types) do
    if exists('svo', type) > 1 then
      toomany[#toomany+1] = type
    end
  end

  if #toomany == 0 then return end

  tempTimer(10, function ()
    svo.echof("Warning! You have multiple %s svo folders while you only should have one per aliases, triggers, etc."
      .." Delete the extra ones.", table.concat(toomany, ", ")) end)
end, 'check for multiple svos')

-- table.save() before Mudlet 3.7.1 didn't return the error, so we have a patched copy
-- fix has been contributed upstream
function svo.tablesave( sfile, t )
    local tables = {}
    table.insert( tables, t )
    local lookup = { [t] = 1 }
    local file, msg = io.open( sfile, 'w' )
    if not file then return nil, msg end

    file:write( "return {" )
    for _,v in ipairs( tables ) do
        table.pickle( v, file, tables, lookup )
    end
    file:write( "}" )
    file:close()

    return true
end

-- load the lust list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/lustlist"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    svo.update(me.lustlist, t)
  end
end, 'load lust list')
-- save the lust list
signals.saveconfig:connect(function () me.lustlist = me.lustlist or {}
  svo.tablesave(getMudletHomeDir() .. "/svo/config/lustlist", me.lustlist) end, 'save lust list')

-- load the hoist list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/hoistlist"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    svo.update(me.hoistlist, t)
  end
end, 'load hoist list')
-- save the hoist list
signals.saveconfig:connect(function () me.hoistlist = me.hoistlist or {}
  svo.tablesave(getMudletHomeDir() .. "/svo/config/hoistlist", me.hoistlist) end, 'save hoist list')

-- load the ignore list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/ignore"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    svo.update(svo.ignore, t)
  end
  svo.ignore.checkparalysis = true
end, 'load ignore list')
-- save the ignore list
  signals.saveconfig:connect(function () svo.ignore = svo.ignore or {}
  table.save(getMudletHomeDir() .. "/svo/config/ignore", svo.ignore)
end, 'save ignore list')

-- load the locatelist
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/locatelist"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    me.locatelist = me.locatelist or {} -- make sure it's initialized
    svo.update(me.locatelist, t)
  end
end, 'load locate list')
-- save the locate list
signals.saveconfig:connect(function () me.locatelist = me.locatelist or {}
  svo.tablesave(getMudletHomeDir() .. "/svo/config/locatelist", me.locatelist)
end, 'save locate list')

-- load the watchfor list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/watchfor"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    me.watchfor = me.watchfor or {} -- make sure it's initialized
    svo.update(me.watchfor, t)
  end
end, 'load watchfor list')
-- save the watchfor list
signals.saveconfig:connect(function () me.watchfor = me.watchfor or {}
  svo.tablesave(getMudletHomeDir() .. "/svo/config/watchfor", me.watchfor)
end, 'save watchfor list')

-- load the tree list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/tree"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledtreefunc)
  end

  if not conf.disabledtreedefaults then
    conf.disabledtreedefaults = true

    me.disabledtreefunc.any2affs = true
    me.disabledtreefunc.any3affs = true
  end
end, 'load tree list')
-- save the tree func list
signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/config/tree", me.disabledtreefunc)
end, 'save tree list')

-- load the fitness list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/fitness"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledfitnessfunc)
  end

  if not conf.disabledfitnessdefaults then
    conf.disabledfitnessdefaults = true
  end
end, 'load fitness data')
-- save the fitness func list
signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/config/fitness", me.disabledfitnessfunc)
end, 'save fitness data')

-- load the rage list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/rage"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledragefunc)
  end

  if not conf.disabledragedefaults then
    conf.disabledragedefaults = true
  end
end, 'load rage data')
-- save the rage func list
signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/config/rage", me.disabledragefunc)
end, 'save rage data')

-- load the restore func list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/restore"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledrestorefunc)
  else
    tempTimer(0, function () me.disabledrestorefunc.anylimb = true; me.disabledrestorefunc.anyoneortwolimbs = true; end)
  end
end, 'load restore data')
-- save the restore func list
signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/config/restore", me.disabledrestorefunc)
end, 'save restore data')

-- load the dragonheal func list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/dragonheal"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disableddragonhealfunc)
  else
    tempTimer(0, function () me.disableddragonhealfunc.anylimb = true end)
  end
end, 'load dragonheal data')
-- save the dragonheal func list
signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/config/dragonheal", me.disableddragonhealfunc)
end, 'save dragonheal data')

for _, config in ipairs{
 {location = 'serverignore', localtable = svo.serverignore, errormsg = "re-set all of the server ignore strats"},
 {location = 'cadmusaffs', localtable = svo.me.cadmusaffs, errormsg = "re-set all of the cadmus affs"},
 {location = 'prefercustom', localtable = svo.me.curelist, errormsg = "re-set all of the custom curelist"},
} do
  -- load the config.location list
  signals.systemstart:connect(function ()
    local conf_path = getMudletHomeDir() .. "/svo/config/"..config.location

    if lfs.attributes(conf_path) then
      local ok, msg = pcall(table.load, conf_path, config.localtable)
      if not ok then
        os.remove(conf_path)
        tempTimer(10, function()
          svo.echof("Your %s serverignore file got corrupted for some reason - "
            .."I've deleted it so the system can load other stuff OK. You'll need to %s, though. (%q)",
            config.location, config.errormsg, msg)
        end)
      end
    end
		svo.setup_default_serverignore()
  end, 'load '..config.location..' data')
  
  -- save the config.location list
  signals.saveconfig:connect(function ()
    svo.tablesave(getMudletHomeDir() .. "/svo/config/"..config.location, config.localtable)
  end, 'save '.. config.location ..'data')
end


if svo.haveskillset('venom') then
  -- load the shrugging func list
  signals.systemstart:connect(function ()
    local conf_path = getMudletHomeDir() .. "/svo/config/shrugging"

    if lfs.attributes(conf_path) then
      local ok, msg = pcall(table.load,conf_path, me.disabledshruggingfunc)
      if not ok then
        os.remove(conf_path)
        tempTimer(10, function()
          svo.echof("Your shrugging strats file got corrupted for some reason - "
            .."I've deleted it so the system can load other stuff OK. "
            .."You'll need to re-set all of the shrugging strats again, though. (%q)", msg)
        end)
      end
    else
      tempTimer(0, function () me.disabledshruggingfunc.any2affs = true end)
    end
  end, 'load shrugging data')
  -- save the shrugging func list
  signals.saveconfig:connect(function ()
    svo.tablesave(getMudletHomeDir() .. "/svo/config/shrugging", me.disabledshruggingfunc)
  end, 'save shrugging data')
end

-- data for normal/trans sipping
svo.es_categories = {
  ["a caloric salve"]         = 'salve',
  ["a salve of mass"]         = 'salve',
  ["a salve of mending"]      = 'salve',
  ["a salve of restoration"]  = 'salve',
  ["an elixir of frost"]      = 'elixir',
  ["an elixir of health"]     = 'elixir',
  ["an elixir of immunity"]   = 'elixir',
  ["an elixir of levitation"] = 'elixir',
  ["an elixir of mana"]       = 'elixir',
  ["an elixir of speed"]      = 'elixir',
  ["an elixir of venom"]      = 'elixir',
  ["an epidermal salve"]      = 'salve',
  ['empty']                   = 'empty',
  ["the venom aconite"]       = 'venom',
  ["the venom camus"]         = 'venom',
  ["the venom colocasia"]     = 'venom',
  ["the venom curare"]        = 'venom',
  ["the venom darkshade"]     = 'venom',
  ["the venom delphinium"]    = 'venom',
  ["the venom digitalis"]     = 'venom',
  ["the venom epseth"]        = 'venom',
  ["the venom epteth"]        = 'venom',
  ["the venom euphorbia"]     = 'venom',
  ["the venom eurypteria"]    = 'venom',
  ["the venom gecko"]         = 'venom',
  ["the venom kalmia"]        = 'venom',
  ["the venom larkspur"]      = 'venom',
  ["the venom loki"]          = 'venom',
  ["the venom monkshood"]     = 'venom',
  ["the venom nechamandra"]   = 'venom',
  ["the venom notechis"]      = 'venom',
  ["the venom oculus"]        = 'venom',
  ["the venom oleander"]      = 'venom',
  ["the venom prefarar"]      = 'venom',
  ["the venom scytherus"]     = 'venom',
  ["the venom selarnia"]      = 'venom',
  ["the venom slike"]         = 'venom',
  ["the venom sumac"]         = 'venom',
  ["the venom vardrax"]       = 'venom',
  ["the venom vernalius"]     = 'venom',
  ["the venom voyria"]        = 'venom',
  ["the venom xentio"]        = 'venom',
}
svo.es_shortnames = {
  aconite        = "the venom aconite",
  caloric        = "a caloric salve",
  camus          = "the venom camus",
  colocasia      = "the venom colocasia",
  curare         = "the venom curare",
  darkshade      = "the venom darkshade",
  delphinium     = "the venom delphinium",
  digitalis      = "the venom digitalis",
  epidermal      = "an epidermal salve",
  epseth         = "the venom epseth",
  epteth         = "the venom epteth",
  euphorbia      = "the venom euphorbia",
  eurypteria     = "the venom eurypteria",
  frost          = "an elixir of frost",
  gecko          = "the venom gecko",
  health         = "an elixir of health",
  immunity       = "an elixir of immunity",
  kalmia         = "the venom kalmia",
  larkspur       = "the venom larkspur",
  levitation     = "an elixir of levitation",
  loki           = "the venom loki",
  mana           = "an elixir of mana",
  mass           = "a salve of mass",
  mending        = "a salve of mending",
  monkshood      = "the venom monkshood",
  nechamandra    = "the venom nechamandra",
  notechis       = "the venom notechis",
  oculus         = "the venom oculus",
  oleander       = "the venom oleander",
  prefarar       = "the venom prefarar",
  restoration    = "a salve of restoration",
  scytherus      = "the venom scytherus",
  selarnia       = "the venom selarnia",
  slike          = "the venom slike",
  speed          = "an elixir of speed",
  sumac          = "the venom sumac",
  vardrax        = "the venom vardrax",
  venom          = "an elixir of venom",
  vernalius      = "the venom vernalius",
  voyria         = "the venom voyria",
  xentio         = "the venom xentio",
  empty          = 'empty', -- so changing desired amounts knows what to use
}
svo.es_shortnamesr = {}
for k,v in pairs(svo.es_shortnames) do svo.es_shortnamesr[v] = k end

-- initialize this for the sipping tracking (the thing that decides what to fallback to)
svo.es_potions = svo.es_potions or {}
local es_potions = svo.es_potions

-- load defaults
for thing, category in pairs(svo.es_categories) do
  es_potions[category] = es_potions[category] or {}
  -- consider 1 so we don't drink the aternative on prefer* right away
  if category == 'venom' then
    es_potions[category][thing] = es_potions[category][thing] or {sips = 0, vials = 0, decays = 0}
  else
    es_potions[category][thing] = es_potions[category][thing] or {sips = 2, vials = 2, decays = 0}
  end
end

sk.arena_areas = {
  --oniar
  ["Oniar Estate"]                     = true,

  -- mhaldor
  ["the Desolate Towers"]              = true,
  ["the Skeletal Forest"]              = true,
  ["the Abandoned Catacombs"]          = true,
  ["the Volcanic Warrens"]             = true,
  -- shallam
  ["the Shallam Caverns"]              = true,
  ["the Hunter's Path"]                = true,
  ["the Hunting Grounds"]              = true,
  ["an Old Shack"]                     = true,
  ["the Catacombs"]                    = true,
  ["the Tower of Light"]               = true,
  -- cyrene
  ["the Forest of Solitude"]           = true,
  ["Muurn Falls"]                      = true,
  ["the Pantheon"]                     = true,
  ["some Dank Caverns"]                = true,
  ["the Matsuhama Arena"]              = true,
  ["the Caves in the Matsuhama Arena"] = true,
  -- hashan
  ["Damballah Lake"]                   = true,
  ["the Lisigia Village"]              = true,
  ["the Wealds of Lisigia"]            = true,
  ["the Lisigia Palace"]               = true,
  ["the Darkshade River"]              = true,
  ["the Lisigian Wastelands"]          = true,
  -- ashtan
  ["the Tomb Grounds"]                 = true,
  ["an underground river"]             = true,
  ["the Tomb of Glanos"]               = true,
  ["the Tomb Catacombs"]               = true,
  -- eleusis
  ["an unspoiled forest"]              = true,
  ["the endless wastelands"]           = true,
  ["a forgotten jungle"]               = true,
  ["the uncharted mountains"]          = true,
  -- delos
  ["the Central Arena"]                = true,
  ["the Modi River"]                   = true,
  ["the Gaian Forest"]                 = true,
  ["the Caverns of the Beasts"]        = true,
  ["the Gladiator Pit"]                = true,
  -- targ
  ["The Stadium"]                      = true,
  ["The Stands"]                       = true,
  ["The Pits"]                         = true,
}

end -- end of svo.loader.setup