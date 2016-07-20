-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

version = "$(version)"

#if DEBUG_actions then
  if Logger then Logger:LogSection("svof", {"timestamp", split = 5000, "keepOpen"}) end
#end

local luanotify = {}
luanotify.signal = require("notify.signal")

local lfs = require "lfs"

local debug = require "debug"

openURL = openURL or openUrl
-- !!
local pl = {}
pl.pretty     = require "pl.pretty"
pl.config     = require "pl.config"
pl.dir        = require "pl.dir"
pl.string     = require "pl.stringx"
pl.OrderedMap = require "pl.OrderedMap"
pl.tablex     = require "pl.tablex"

local phpTable
phpTable = function (...) -- abuse to: http://richard.warburton.it
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

function ripairs(t)
  local function ripairs_it(t,i)
    i=i-1
    local v=t[i]
    if v==nil then return v end
    return i,v
  end
  return ripairs_it, t, #t+1
end

local function deepcopy(object)
  local lookup_table = {}
  local function _copy(object)
      if type(object) ~= "table" then
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

local affs        = {}
local balanceless = {}
local cp          = {}
local lifevision  = {}
local signals     = {}
local sps         = {}
local sys         = {}

conf             = {}
config           = {}
defc             = {} -- current defences
defs             = {}
dragonheal       = {} -- stores dragonheal curing strats
lifep            = {}
lifevision.l     = pl.OrderedMap()
paragraph_length = 0
restore          = {}
shrugging        = {} -- stores shrugging curing strats
sp               = {} -- parry
sp_config        = {}
stats            = {}
tree             = {}
rage             = {}
fitness          = {}
valid            = {}
watch            = {}
gaffl            = {}
gdefc            = {}


local actions, sk, vm, cn, cnrl = false, {}, {}, {}, {}

reset = {}
prio = {}
local affmt = {
  __tostring = function (self)
      local result = {}
      for i,k in pairs(self) do
        if k.p.count then
          result[#result+1] = i .. ": " ..getStopWatchTime(k.sw).."s (" .. k.p.count .. ")"
        else
          result[#result+1] = i .. ": " ..getStopWatchTime(k.sw).."s"
        end
      end

      return table.concat(result, ", ")
  end
}
setmetatable(affs, affmt)

affl = affl or {}


serverignore = {}
ignore = {}

-- has to be here, before the first dict reference in code, so it counts it as a local and uses this one properly
local dict

local oldecho = conf.commandecho
signals.aeony = luanotify.signal.new()
signals.sync = luanotify.signal.new()

signals.dragonform = luanotify.signal.new()

local haddragonform = false
signals.dragonform:add_post_emit(function()
  if defc.dragonform and not haddragonform then
    raiseEvent"svo got dragonform"
    haddragonform = true
  elseif not defc.dragonform and haddragonform then
    raiseEvent"svo lost dragonform"
    haddragonform = false
  end
end)

signals.canoutr = luanotify.signal.new()
signals.canoutr:connect(function()
  if (affs.webbed or affs.bound or affs.transfixed or affs.roped or affs.impale or ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))) then
    sys.canoutr = false
    me.canoutr = false
  else
    sys.canoutr = true
    me.canoutr = true
  end
end)


signals.removed_from_rift = luanotify.signal.new()
signals.moved = luanotify.signal.new()

signals.systemstart = luanotify.signal.new()

signals.systemstart:connect(function() signals.canoutr:emit() end) -- setup the variables

#if DEBUG then
signals.systemstart:connect(function ()
 --~ profiler = newProfiler()
 --~ profiler:start()
end)
#end

signals.quit = luanotify.signal.new()
signals.connected = luanotify.signal.new()
#if DEBUG then
signals.quit:connect(function ()
  if Logger then Logger:CloseLog("svo") end
end)
#end
signals.quit:add_pre_emit(function () signals.saveconfig:emit() end)
signals.quit:add_pre_emit(function () raiseEvent "svo quit" end)
signals.systemend = luanotify.signal.new()

signals.donedefup = luanotify.signal.new()

-- gmcp ones
signals.gmcpcharname = luanotify.signal.new()
signals.gmcpcharname:connect(function ()
  signals.enablegmcp:emit()
end)
signals.gmcproominfo        = luanotify.signal.new()
signals.gmcpcharstatus      = luanotify.signal.new()
signals.gmcpcharitemslist   = luanotify.signal.new()
signals.gmcpcharitemslist:connect(function()
  if not gmcp.Char.Items.List.location then debugf("(GMCP problem) location field is missing from Achaea's response.") return end
  if gmcp.Char.Items.List.location ~= "inv" then return end
  me.inventory = deepcopy(gmcp.Char.Items.List.items)
end)
signals.gmcpcharitemsadd    = luanotify.signal.new()
signals.gmcpcharitemsadd:connect(function()
  if not gmcp.Char.Items.Add.location then debugf("(GMCP problem) location field is missing from Achaea's response.") return end
  if gmcp.Char.Items.Add.location ~= "inv" then return end
  me.inventory[#me.inventory + 1] = deepcopy(gmcp.Char.Items.Add.item)
end)
signals.gmcpcharskillsinfo  = luanotify.signal.new()
signals.gmcpcharskillslist  = luanotify.signal.new()
signals.gmcpcharitemsupdate = luanotify.signal.new()
signals.gmcpcharitemsupdate:connect(function()
  if not gmcp.Char.Items.Update.location then debugf("(GMCP problem) location field is missing from Achaea's response.") return end
  if gmcp.Char.Items.Update.location ~= "inv" then return end
  local update = gmcp.Char.Items.Update.item
  for i, item in ipairs(me.inventory) do
    if item.id == update.id then
      me.inventory[i] = deepcopy(gmcp.Char.Items.Update.item)
      break
    end
  end
end)
signals.gmcpcharitemsremove = luanotify.signal.new()
signals.gmcpcharitemsremove:connect(function()
  if not gmcp.Char.Items.Remove.location then debugf("(GMCP problem) location field is missing from Achaea's response.") return end
  if gmcp.Char.Items.Remove.location ~= "inv" then return end
  local remove = gmcp.Char.Items.Remove.item
  for i, item in ipairs(me.inventory) do
    if item.id == remove.id then
      table.remove(me.inventory, i)
      break
    end
  end
end)
signals.gmcpcharvitals      = luanotify.signal.new()
signals.gmcpiretimelist = luanotify.signal.new()
signals.gmcpiretimelist:connect(function()
  me.gametime = deepcopy(gmcp.IRE.Time.List)
end)
signals.gmcpiretimeupdate = luanotify.signal.new()
signals.gmcpiretimeupdate:connect(function()
  me.gametime = me.gametime or {}
  for k, v in pairs(gmcp.IRE.Time.Update) do
    me.gametime[k] = v
  end
end)

signals.gmcpcharafflictionslist = luanotify.signal.new()
signals.gmcpcharafflictionsremove = luanotify.signal.new()
signals.gmcpcharafflictionsadd = luanotify.signal.new()

signals.gmcpchardefenceslist = luanotify.signal.new()
signals.gmcpchardefencesremove = luanotify.signal.new()
signals.gmcpchardefencesadd = luanotify.signal.new()


signals.gmcpcharafflictionsadd:connect(function()
  local thisaff = gmcp.Char.Afflictions.Add.name
  if thisaff:sub(-4) == " (1)" then thisaff = thisaff:sub(1, -5) end
  gaffl[thisaff] = true
  if conf.gmcpaffechoes then echof("Gained aff %s", thisaff) end
  if dict.sstosvoa[thisaff] then
    addaff(dict[dict.sstosvoa[thisaff]])
  end
end)

signals.gmcpcharafflictionsremove:connect(function()
  local thisaff = gmcp.Char.Afflictions.Remove[1]
  gaffl[thisaff] = nil
  if conf.gmcpdefechoes then echof("Cured aff %s", thisaff) end
  if dict.sstosvoa[thisaff] then
    removeaff(dict.sstosvoa[thisaff])
  end
end)

signals.gmcpcharafflictionslist:connect(function()
  gaffl = {}
  local preaffl = {}
  for key, val in ipairs(affl) do preaffl[val] = true end
  
  for index, val in ipairs(gmcp.Char.Afflictions.List) do
    local thisaff = val.name
    if thisaff:sub(-4) == " (1)" then thisaff = thisaff:sub(1, -5) end  
    gaffl[thisaff] = true
    if preaffl[thisaff] then
      preaffl[thisaff] = false
    elseif dict.sstosvoa[thisaff] then
      addaff(dict[dict.sstosvoa[thisaff]])
    end
  end
  
  for key, val in pairs(preaffl) do
    if val and dict.svotossa[thisaff] then removeaff(key) end
  end
end)


signals.gmcpchardefencesadd:connect(function()
  thisdef = gmcp.Char.Defences.Add.name
  gdefc[thisdef] = true
  if conf.gmcpdefechoes then echof("Gained def "..thisdef) end
  if dict.sstosvod[thisdef] then
    if type(defs["got_"..dict.sstosvod[thisdef]]) == "function" then
      defs["got_"..dict.sstosvod[thisdef]]()
    else
      echoLink("(e!)", [[echo("The problem was: got_ function was ]]..type(defs["got_"..dict.sstosvod[thisdef]])..[[ for defence ]]..dict.sstosvod[thisdef]..[[ (gmcp:]]..thisdef..[[)")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
    end
  end
end)

signals.gmcpchardefencesremove:connect(function()
  thisdef = gmcp.Char.Defences.Remove[1]
  gdefc[thisdef] = nil
  if conf.gmcpdefechoes then echof("Lost def "..thisdef) end
  if dict.sstosvod[thisdef] then
    if type(defs["lost_"..dict.sstosvod[thisdef]]) == "function" then
      defs["lost_"..dict.sstosvod[thisdef]]()
    else
      echoLink("(e!)", [[echo("The problem was: lost_ function was ]]..type(defs["lost_"..dict.sstosvod[thisdef]])..[[ for defence ]]..dict.sstosvod[thisdef]..[[ (gmcp:]]..thisdef..[[)")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
    end
  end
end)

signals.gmcpchardefenceslist:connect(function()
  gdefc = {}
  local predefs = deepcopy(defc)
  for index, val in ipairs(gmcp.Char.Defences.List) do
    thisdef = val.name
    gdefc[thisdef] = true
    if dict.sstosvod[thisdef] then
      if predefs[dict.sstosvod[thisdef]] then
        predefs[dict.sstosvod[thisdef]] = false
      elseif type(defs["got_"..dict.sstosvod[thisdef]]) == "function" then
        defs["got_"..dict.sstosvod[thisdef]]()
      else
        echoLink("(e!)", [[echo("The problem was: got_ function was ]]..type(defs["got_"..dict.sstosvod[thisdef]])..[[ for defence ]]..dict.sstosvod[thisdef]..[[ (gmcp:]]..thisdef..[[)")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
      end
    end
  end
  for defname, val in pairs(predefs) do
    if val == true and dict.sstosvod[defname] then 
      if type(defs["lost_"..dict.sstosvod[defname]]) == "function" then
        defs["lost_"..dict.sstosvod[defname]]()
      else
        echoLink("(e!)", [[echo("The problem was: lost_ function was ]]..type(defs["lost_"..dict.sstosvod[defname]])..[[ for defence ]]..dict.sstosvod[defname]..[[ (gmcp:]]..defname..[[)")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
      end
    end
  end
end)

-- make a 'signals bank' that remembers all gmcp events that happend before the prompt. reset on prompt. check it for stuff when necessary.
-- have the herb out signal be remembers on it's own & verified by the syste

do
  local oldnum, oldarea
  signals.gmcproominfo:connect(function (...)
    if oldnum ~= gmcp.Room.Info.num then
      signals.newroom:emit(_G.gmcp.Room.Info.name)
      oldnum = gmcp.Room.Info.num
    end

    signals.anyroom:emit(_G.gmcp.Room.Info.name)

    if oldarea ~= gmcp.Room.Info.area then
      signals.newarea:emit(_G.gmcp.Room.Info.area)
      oldarea = gmcp.Room.Info.area
    end
  end)
end

-- atcp ones
signals.charname = luanotify.signal.new()
signals.roombrief = luanotify.signal.new()

do
  local oldnum
  signals.roombrief:connect(function (...)
    if oldnum ~= atcp.RoomNum then
      signals.newroom:emit(({...})[1])
      oldnum = atcp.RoomNum
    end

    signals.anyroom:emit(({...})[1])
  end)
end

-- general ones
signals.relogin = luanotify.signal.new()
signals.enablegmcp = luanotify.signal.new()
signals.enablegmcp:add_post_emit(function ()
  logging_in = false
  if not sys.enabledgmcp then
    sys.enabledgmcp = true
  else
    signals.relogin:emit()
    echof("Welcome back!")
    -- defs.quietswitch("basic")
  end
  -- app("off", true) -- this triggers a dict() run too early before login
  if dont_unpause_login then dont_unpause_login = nil
  else conf.paused = false end

  innews = false
end)
tempBeginOfLineTrigger("Rapture Runtime Environment", [[svo.logging_in = true]])

signals.newroom = luanotify.signal.new()
signals.newarea = luanotify.signal.new()
signals.anyroom = luanotify.signal.new()
signals.changed_maxhealth = luanotify.signal.new()
signals.changed_maxhealth:connect(function (old, new) -- can't use add_post_emit, as that doesn't pass arguments down
  if not string.find(debug.traceback(), "Alias", 1, true) then
    if not (old and new) or (old and old == 1) then
      echof("Your max health changed to %dh.", stats.maxhealth)
    elseif old > new then
      echof("Your max health decreased by %dh/%d%% to %d.", (old-new), 100-math.floor((100/old)*new), new)
    else
      echof("Your max health increased by %dh/%d%% to %d.", (new-old), (math.floor((100/old)*new)-100), new)

      -- track stain
      sk.gotmaxhealth = true
      prompttrigger("check stain expiring", function()
        if paragraph_length == 0 and sk.gotmaxhealth and sk.gotmaxmana and affs.stain then
          removeaff("stain")
          echof("I think stain faded.")
        end
        sk.gotmaxhealth, sk.gotmaxmana = nil, nil
      end)
    end
  end
end)
signals.changed_maxmana = luanotify.signal.new()
signals.changed_maxmana:connect(function (old, new)
  if not string.find(debug.traceback(), "Alias", 1, true) then
    if not (old and new) or (old and old == 1) then
      echof("Your max mana changed to %dm.", stats.maxmana)
    elseif old > new then
      echof("Your max mana decreased by %dm/%d%% to %d.", (old-new), 100-math.floor((100/old)*new), new)
    else
      echof("Your max mana increased by %dm/%d%% to %d.", (new-old), (math.floor((100/old)*new)-100), new)

      sk.gotmaxmana = true
      prompttrigger("check stain expiring", function()
        if paragraph_length == 0 and sk.gotmaxhealth and sk.gotmaxmana and affs.stain then
          removeaff("stain")
          echof("I think stain faded.")
        end
        sk.gotmaxhealth, sk.gotmaxmana = nil, nil
      end)
    end
  end
end)

signals.before_prompt_processing    = luanotify.signal.new()
signals.after_prompt_processing     = luanotify.signal.new()
signals.after_lifevision_processing = luanotify.signal.new()

signals.curedwith_focus             = luanotify.signal.new()
signals.curemethodchanged           = luanotify.signal.new()
signals.limbhit                     = luanotify.signal.new()
signals.loadconfig                  = luanotify.signal.new()
signals.orgchanged                  = luanotify.signal.new()
signals.saveconfig                  = luanotify.signal.new()
signals.sysdatasendrequest          = luanotify.signal.new()
#if skills.healing then
signals.healingskillchanged         = luanotify.signal.new()
#end
#if skills.metamorphosis then
signals.morphskillchanged           = luanotify.signal.new()
#end

signals.saveconfig:add_post_emit(function ()
  echo"\n"
  echof("Saved system settings.")
end)

signals.loadedconfig                 = luanotify.signal.new()
signals.svogotaff                    = luanotify.signal.new()
signals.svolostaff                   = luanotify.signal.new()
signals.sysexitevent                 = luanotify.signal.new()
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
#if skills.healing then
conf.ai_resethealingbal        = 7   -- resets at 2s for healing allies, near 4s for healing yourself, and offensive skills as inbetween
#end
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

conf.changestype          = "shortpercent"

conf.paused               = false
conf.lag                  = 0
sys.wait                  = 0.7 -- for lag
conf.aillusion            = true -- on by deafult, disable it if necessary
conf.keepup               = true

conf.burstmode            = "empty"
conf.slowcurecolour       = "blue"
conf.hinderpausecolour    = "orange"

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
conf.commandechotype      = "fancy"
conf.warningtype          = "right"

conf.autoreject           = "white"
conf.doubledo             = false

conf.ridingskill          = "mount"
conf.ridingsteed          = "pony"

conf.screenwidth          = 100
conf.refillat             = 1
conf.waitherbai           = true
conf.noeqtimeout          = 5

conf.autoslick            = true
conf.showbaltimes         = true
conf.showafftimes         = true

conf.steedfollow          = true
conf.autoclasses          = true

conf.ccto                 = "pt"
conf.repeatcmd            = 0

#if skills.healing then
conf.usehealing           = "partial"
#end

#if skills.kaido then
conf.transmute            = "supplement"
conf.transmuteamount      = 70
#end

#if skills.devotion then
conf.bloodswornoff        = 30
#end

conf.gagclot              = true
conf.gagrelight           = false
conf.relight              = true

conf.passive_eqloss       = 10

conf.highlightparryfg     = "white"
conf.highlightparrybg     = "blue"

conf.autotsc              = true
conf.ignoresinglebites    = false

conf.medprone             = false
conf.unmed                = false

conf.pagelength           = 20
conf.treebalance          = 0

conf.healthaffsabove      = 70

conf.batch                = true

conf.curemethod = "conconly"
signals.systemstart:add_post_emit(function()
  if not conf.curemethod or conf.curemethod == "auto" then
    conf.curemethod = "conconly"
  end
end)

conf.ninkharsag = true

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

-- the in-game custom prompt needs to show the game target and game target hp, since that isn't available in GMCP at the moment, as well as any class-specific balances and values
#if not skills.weaponmastery then
sys.ingamecustomprompt ="CONFIG PROMPT CUSTOM *hh, *mm, *ee, *ww *t*T *b*d*c-*r-s*s-"
#else
-- account for ferocity
sys.ingamecustomprompt ="CONFIG PROMPT CUSTOM *hh, *mm, *ee, *ww *t*T *b*d*c-*r-k*k-s*s-"
#end
-- used in lyre actions to prevent doubledo from activating - since that'd destroy the lyre right away
sys.sendonceonly = false

-- a map that has possible commands linked to dict.action.balance entries
sys.input_to_actions = {}
-- a map that stores dict.action.balance.name
sys.last_used = {}

$(
local paths = {}; paths.oldpath = package.path; package.path = package.path..";./?.lua;./bin/?.lua;"; local pretty = require "pl.pretty"; package.path = paths.oldpath

_put("sys.downloadurl = ".. pretty.write(url))
)

---

danaeusaffs = {"agoraphobia", "claustrophobia", "dizziness", "epilepsy", "hypersomnia", "vertigo"}
nemesisaffs = {"agoraphobia", "recklessness", "confusion", "masochism", "loneliness"}
scragaffs   = {"clumsiness", "healthleech", "lethargy", "sensitivity", "haemophilia", "darkshade"}

---

stats.nextlevel,
stats.currenthealth, stats.maxhealth,
stats.currentmana, stats.maxmana,
stats.currentendurance, stats.maxendurance,
stats.currentwillpower, stats.maxwillpower = 1,1,1,1,1,1,1,1,1

#if skills.kaido then
stats.kai = 0
#end

---
me = {}
me.skills = {}
me.wielded = {}
me.oldhealth = 0

$(
local paths = {}; paths.oldpath = package.path; package.path = package.path..";./?.lua;./bin/?.lua;"; local pretty = require "pl.pretty"; local stringx = require "pl.stringx"; local tablex = require "pl.tablex"; package.path = paths.oldpath

_put(string.format("me.class = \"%s\"\n", type(class) == "string" and stringx.title(class) or table.concat(tablex.imap(stringx.title, class), ", ")))
_put("me.skills = ".. pretty.write(skills))
)

me.doqueue = {repeating = false}
me.dofreequeue = {}
me.dopaused = false
me.lustlist = {} -- list if names not to add lovers aff for
me.lasthitlimb = "head" -- last hit limb
me.disableddragonhealfunc = {}
me.disabledrestorefunc    = {}
#if skills.venom then
me.disabledshruggingfunc  = {}
#end
me.disabledtreefunc       = {}
me.disabledragefunc       = {}
me.disabledfitnessfunc       = {}
me.unparryables = {}
me.focusedknights = {}
me.locks = {}
me.curelist = {
  ash         = "ash",
  bayberry    = "bayberry",
  bellwort    = "bellwort",
  bloodroot   = "bloodroot",
  caloric     = "caloric",
  cohosh      = "cohosh",
  echinacea   = "echinacea",
  elm         = "elm",
  epidermal   = "epidermal",
  frost       = "frost",
  ginger      = "ginger",
  ginseng     = "ginseng",
  goldenseal  = "goldenseal",
  hawthorn    = "hawthorn",
  health      = "health",
  immunity    = "immunity",
  irid        = "irid",
  kelp        = "kelp",
  kola        = "kola",
  levitation  = "levitation",
  lobelia     = "lobelia",
  mana        = "mana",
  mass        = "mass",
  mending     = "mending",
  myrrh       = "myrrh",
  pear        = "pear",
  restoration = "restoration",
  sileris     = "sileris",
  skullcap    = "skullcap",
  speed       = "speed",
  valerian    = "valerian",
  venom       = "venom",
}


me.cadmusaffs = me.cadmusaffs or {
  ["agoraphobia"]    = false,
  ["anorexia"]       = true,
  ["claustrophobia"] = false,
  ["confusion"]      = false,
  ["dizziness"]      = false,
  ["epilepsy"]       = false,
  ["fear"]           = false,
  ["generosity"]     = false,
  ["loneliness"]     = false,
  ["masochism"]      = false,
  ["pacifism"]       = false,
  ["recklessness"]   = true,
  ["shyness"]        = false,
  ["stupidity"]      = true,
  ["unknownmental"]  = false,
  ["vertigo"]        = false,
  ["weakness"]       = false,
}

me.inventory = {}
---

#if not skills.shindo then
disableTrigger("Shindo defences")
#else
enableTrigger("Shindo defences")
#end

#if not skills.kaido then
disableTrigger("Kaido defences")
#else
enableTrigger("Kaido defences")
#end

#if not skills.tekura then
disableTrigger("Tekura balances")
#else
enableTrigger("Tekura balances")
#end

#if class == "druid" then
enableTrigger("Hydra balance")
#else
disableTrigger("Hydra balance")
#end

#if skills.voicecraft then
enableTrigger("Voice balance")
#else
disableTrigger("Voice balance")
#end

#if skills.chivalry or skills.shindo or skills.kaido or skills.metamorphosis then
enableTrigger("Fitness balance")
#else
disableTrigger("Fitness balance")
#end

#if skills.chivalry then
enableTrigger("Rage balance")
#else
disableTrigger("Rage balance")
#end

#if skills.weaponmastery then
enableTrigger("Two-hander recover footing")
#else
disableTrigger("Two-hander recover footing")
#end

#if skills.domination then
enableTrigger("Domination entities balance")
#else
disableTrigger("Domination entities balance")
#end

#if skills.venom then
enableTrigger("Shrugging balance")
#else
disableTrigger("Shrugging balance")
#end

#if skills.healing or skills.elementalism then
enableTrigger("Healing + Elementalism channels")
#else
disableTrigger("Healing + Elementalism channels")
#end

#if skills.elementalism then
enableAlias("Elementalism aliases")
#else
disableAlias("Elementalism aliases")
#end

#if skills.spirituality then
enableTrigger("Spirituality defences")
enableAlias("Spirituality aliases")
#else
disableTrigger("Spirituality defences")
disableAlias("Spirituality aliases")
#end

#if skills.propagation then
enableTrigger("Propagation defences")
#else
disableTrigger("Propagation defences")
#end

#if skills.necromancy then
enableTrigger("Necromancy defences")
#else
disableTrigger("Necromancy defences")
#end

#if not skills.occultism then
disableTrigger("Occultism defences")
#else
enableTrigger("Occultism defences")
#end

#if not skills.alchemy then
disableTrigger("Alchemy defences")
#else
enableTrigger("Alchemy defences")
#end

#if not skills.groves then
disableTrigger("Groves defences")
#else
enableTrigger("Groves defences")
#end

#if not skills.harmonics then
disableTrigger("Harmonics defences")
#else
enableTrigger("Harmonics defences")
#end

#if not skills.healing then
disableTrigger("Healing balance")
#else
enableTrigger("Healing balance")
#end

#if not skills.physiology then
disableTrigger("Humour balance")
#else
enableTrigger("Humour balance")
#end

local prompt_stats

local defences = {}
local defs_data
local oldsend
local defupfinish, process_defs
local doingaction, checkaction, checkany, killaction, actions_performed, bals_in_use, usingbal, doaction, actionfinished
local wait_tbl

local index_map = pl.tablex.index_map

local addaff, removeaff, checkanyaffs, updateaffcount

local lostbal_focus, lostbal_herb, lostbal_salve, lostbal_purgative, lostbal_sip
sk.salvetick, sk.herbtick, sk.focustick, sk.teatick, sk.purgativetick, sk.siptick, sk.mosstick, sk.dragonhealtick, sk.smoketick, sk.voicetick = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#if skills.healing then
sk.healingtick = 0
#end
#if skills.venom then
sk.shruggingtick = 0
#end
#if skills.chivalry or skills.shindo or skills.kaido or skills.metamorphosis then
sk.fitnesstick = 0
#end
#if skills.chivalry then
sk.ragetick = 0
#end
#if skills.weaponmastery then
sk.didfootingattack = false
#end

sk.diag_list = {}
sk.priosbeforechange = {}
 -- caches prio changes, so none need to happen on holes in svo's prios
sk.priochangecache = { special = {} }
-- queue of commands to batch into a serverside alias for curing
sk.sendqueue = {}
-- keep track of the length of the command - max command length in Achaea is 2048
sk.sendqueuel = 18 -- 'setalias multicmd ' is 24 characters
sk.achaea_command_max_length = 2048

-- a buffer to keep track of the commands the system has sent
sk.systemscommands = {}

local clear_balance_prios, clear_sync_prios

local herb_cure, smoke_cure, focus_cure, sip_cure
local promptcount, lastpromptnumber = 0, 0

local config_dict, vecho

local make_prio_table, make_sync_prio_table

local findbybal, findbybals, will_take_balance


local make_gnomes_work, send_in_the_gnomes, make_gnomes_work_async, make_gnomes_work_sync

local apply_cure, sacid, eat, sip, apply

local send = _G.send

local update

-- possible afflictions that need to go through a check first
local affsp = {}

local rift, pipes = {}, {}

local check_focus, check_salve, check_sip, check_purgative, check_herb, check_moss, check_misc, check_balanceless_acts, check_balanceful_acts, check_smoke

local generics_enabled, generics_enabled_for_blackout, generics_enabled_for_passive, enable_generic_trigs, disable_generic_trigs, check_generics

local passive_cure_paragraph

local sp_checksp, sp_limbs

local install = {}

local life = {}
echos, echosd = {}, {}

sk.ignored_defences, sk.ignored_defences_map = {}, {}
sk.zeromana = false

pflags = {}


signals.svogotaff:connect(function(isloki)
  if dict.svotossa[isloki] and not gaffl[dict.svotossa[isloki]] then
    echof("Svo caught "..isloki.." ("..dict.svotossa[isloki].."), predicting for serverside.")
    send("CURING PREDICT "..dict.svotossa[isloki])
  end
end)


local function assert(condition, msg, extra)
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
    signals.sysdatasendrequest:unblock(cnrl.processcommand)

    -- kill actions prior to this, so we can do aeon
    local to_kill = {}
    for k,v in actions:iter() do
      if v.p.balance ~= "waitingfor" and v.p.balance ~= "aff" and v.p.balance ~= "gone" and v.p.name ~= "aeon_smoke" and v.p.name ~= "checkslows_misc" and v.p.name ~= "touchtree_misc" then -- don't kill aeon_smoke: if we do, we double-smoke. instead, since smoke is started before sync is set: add a customwait delay. Don't kill tree touching either, could help for asthma
        to_kill[#to_kill+1] = dict[v.p.action_name][v.p.balance]
      end
    end

    for _, action in ipairs(to_kill) do
      killaction(action)
    end

    echo("\n")
    echof("%s mode enabled.", (math.random(1, 20) == 20 and "Matrix" or "Slow curing"))

    if conf.autotsc then
      if affs.retardation then
        conf.blockcommands = false -- bypass config.set, because that calls gnomes for us
        echo"\n" echof(" (autotsc) - command overrides enabled.")
      elseif affs.aeon then
        conf.blockcommands = true
        echo"\n" echof(" (autotsc) - command denies enabled.")
      end
    end
  elseif sys.sync and not (affs.aeon or affs.retardation) then
    conf.commandecho = oldecho
    sys.sync = false
    signals.sync:emit()
    signals.sysdatasendrequest:block(cnrl.processcommand)
    echo("\n")
    echof("Slow curing mode disabled.")
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
end);

#if skills.metamorphosis then
  (tempExactMatchTrigger or tempTrigger)("You take a deep breath and realise your error - you sputter and engulf yourself in fire!",
    [[svo.valid.simpleablaze()]]);

  tempRegexTrigger([[^Your soul quakes and shifts as the spirits depart, leaving you .+ once more\.$]],
    [[
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"} do
        if svo.defc[morph] then svo.defs["lost_"..morph]() end
      end
    ]]);

  tempRegexTrigger([[^You remain in .+ form, dolt\.$]],
    [[
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"} do
        if svo.defc[morph] then svo.defs["lost_"..morph]() end
      end
    ]]);

  tempRegexTrigger([[^You are already in .+ form\.$]],
    [[
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"} do
        if svo.defc[morph] then svo.defs["lost_"..morph]() end
      end
    ]]);

  tempRegexTrigger([[^You writhe in spiritual torment as the creature spirit is torn from your soul \- you are .+ once more\.$]],
    [[
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"} do
        if svo.defc[morph] then svo.defs["lost_"..morph]() end
        svo.valid.simplecantmorph()
      end
    ]]);

  (tempExactMatchTrigger or tempTrigger)("You cannot possibly morph again so soon.", "svo.valid.simplecantmorph()");

  (tempExactMatchTrigger or tempTrigger)("You feel your bond with the animal spirits strengthen, allowing you to morph once again.",
    [[svo.valid.cantmorph_woreoff()]]);
#end

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
color_table.a_darkyellow  = {0, 179, 0}
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
  local toomany, types = {}, {"alias", "trigger"} -- add scripts when exists() function supports it

  for _, type in ipairs(types) do
    if exists("svo", type) > 1 then
      toomany[#toomany+1] = type
    end
  end

  if #toomany == 0 then return end

  tempTimer(10, function () echof("Warning! You have multiple %s svo folders while you only should have one per aliases, triggers, etc. Delete the extra ones.", table.concat(toomany, ", ")) end)
end)

-- fix iffy table.save
function table.save( sfile, t )
	local tables = {}
	table.insert( tables, t )
	local lookup = { [t] = 1 }
	local file, msg = io.open( sfile, "w" )
	if not file then return nil, msg end

	file:write( "return {" )
	for i,v in ipairs( tables ) do
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
    update(me.lustlist, t)
  end
end)

signals.saveconfig:connect(function () table.save(getMudletHomeDir() .. "/svo/config/lustlist", me.lustlist) end)

-- load the ignore list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/ignore"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    update(ignore, t)
  end

  ignore.checkparalysis = true
end)

signals.saveconfig:connect(function () table.save(getMudletHomeDir() .. "/svo/config/ignore", ignore) end)

-- load the locatelist
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/locatelist"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    me.locatelist = me.locatelist or {} -- make sure it's initialized
    update(me.locatelist, t)
  end
end)
signals.saveconfig:connect(function () me.locatelist = me.locatelist or {}; table.save(getMudletHomeDir() .. "/svo/config/locatelist", me.locatelist) end)

-- load the watchfor list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/watchfor"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    me.watchfor = me.watchfor or {} -- make sure it's initialized
    update(me.watchfor, t)
  end
end)
signals.saveconfig:connect(function () me.watchfor = me.watchfor or {}; table.save(getMudletHomeDir() .. "/svo/config/watchfor", me.watchfor) end)

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
end)
-- save the tree func list
signals.saveconfig:connect(function ()
  table.save(getMudletHomeDir() .. "/svo/config/tree", me.disabledtreefunc)
end)

-- load the fitness list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/fitness"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledfitnessfunc)
  end

  if not conf.disabledfitnessdefaults then
    conf.disabledfitnessdefaults = true
  end
end)
-- save the fitness func list
signals.saveconfig:connect(function ()
  table.save(getMudletHomeDir() .. "/svo/config/fitness", me.disabledfitnessfunc)
end)

-- load the rage list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/rage"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledragefunc)
  end

  if not conf.disabledragedefaults then
    conf.disabledragedefaults = true
  end
end)
-- save the rage func list
signals.saveconfig:connect(function ()
  table.save(getMudletHomeDir() .. "/svo/config/rage", me.disabledragefunc)
end)

-- load the restore func list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/restore"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disabledrestorefunc)
  else
    tempTimer(0, function () me.disabledrestorefunc.anylimb = true; me.disabledrestorefunc.anyoneortwolimbs = true; end)
  end
end)
-- save the restore func list
signals.saveconfig:connect(function ()

  table.save(getMudletHomeDir() .. "/svo/config/restore", me.disabledrestorefunc)
end)

-- load the dragonheal func list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/dragonheal"

  if lfs.attributes(conf_path) then
    table.load(conf_path, me.disableddragonhealfunc)
  else
    tempTimer(0, function () me.disableddragonhealfunc.anylimb = true end)
  end
end)
-- save the dragonheal func list
signals.saveconfig:connect(function ()

  table.save(getMudletHomeDir() .. "/svo/config/dragonheal", me.disableddragonhealfunc)
end)

#for _, config in ipairs{
# {location = "serverignore", localtable = "serverignore", errormsg = "re-set all of the shrugging strats"},
# {location = "cadmusaffs", localtable = "me.cadmusaffs", errormsg = "re-set all of the cadmus affs"},
# {location = "prefercustom", localtable = "me.curelist", errormsg = "re-set all of the custom curelist"},
#} do
-- load the $(config.location) list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/$(config.location)"

  if lfs.attributes(conf_path) then
    local ok, msg = pcall(table.load, conf_path, $(config.localtable))
    if not ok then
      os.remove(conf_path)
      tempTimer(10, function()
        echof("Your $(config.location) serverignore file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to $(config.errormsg), though. (%q)", msg)
      end)
    end
  end
end)
-- save the $(config.location) list
signals.saveconfig:connect(function ()
  table.save(getMudletHomeDir() .. "/svo/config/$(config.location)", $(config.localtable))
end)

#end


#if skills.venom then
-- load the shrugging func list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/shrugging"

  if lfs.attributes(conf_path) then
    local ok, msg = pcall(table.load,conf_path, me.disabledshruggingfunc)
    if not ok then
      os.remove(conf_path)
      tempTimer(10, function()
        echof("Your shrugging strats file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to re-set all of the shrugging strats again, though. (%q)", msg)
      end)
    end
  else
    tempTimer(0, function () me.disabledshruggingfunc.any2affs = true end)
  end
end)
-- save the shrugging func list
signals.saveconfig:connect(function ()

  table.save(getMudletHomeDir() .. "/svo/config/shrugging", me.disabledshruggingfunc)
end)
#end

-- data for normal/trans sipping
es_categories = {
  ["a caloric salve"]         = "salve",
  ["a salve of mass"]         = "salve",
  ["a salve of mending"]      = "salve",
  ["a salve of restoration"]  = "salve",
  ["an elixir of frost"]      = "elixir",
  ["an elixir of health"]     = "elixir",
  ["an elixir of immunity"]   = "elixir",
  ["an elixir of levitation"] = "elixir",
  ["an elixir of mana"]       = "elixir",
  ["an elixir of speed"]      = "elixir",
  ["an elixir of venom"]      = "elixir",
  ["an epidermal salve"]      = "salve",
  ["empty"]                   = "empty",
  ["the venom aconite"]       = "venom",
  ["the venom camus"]         = "venom",
  ["the venom colocasia"]     = "venom",
  ["the venom curare"]        = "venom",
  ["the venom darkshade"]     = "venom",
  ["the venom delphinium"]    = "venom",
  ["the venom digitalis"]     = "venom",
  ["the venom epseth"]        = "venom",
  ["the venom epteth"]        = "venom",
  ["the venom euphorbia"]     = "venom",
  ["the venom eurypteria"]    = "venom",
  ["the venom gecko"]         = "venom",
  ["the venom kalmia"]        = "venom",
  ["the venom larkspur"]      = "venom",
  ["the venom loki"]          = "venom",
  ["the venom monkshood"]     = "venom",
  ["the venom nechamandra"]   = "venom",
  ["the venom notechis"]      = "venom",
  ["the venom oculus"]        = "venom",
  ["the venom oleander"]      = "venom",
  ["the venom prefarar"]      = "venom",
  ["the venom scytherus"]     = "venom",
  ["the venom selarnia"]      = "venom",
  ["the venom slike"]         = "venom",
  ["the venom sumac"]         = "venom",
  ["the venom sumac"]         = "venom",
  ["the venom vardrax"]       = "venom",
  ["the venom vernalius"]     = "venom",
  ["the venom voyria"]        = "venom",
  ["the venom xentio"]        = "venom",
}
es_shortnames = {
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
  sumac          = "the venom sumac",
  vardrax        = "the venom vardrax",
  venom          = "an elixir of venom",
  vernalius      = "the venom vernalius",
  voyria         = "the venom voyria",
  xentio         = "the venom xentio",
  empty          = "empty", -- so changing desired amounts knows what to use
}
es_shortnamesr = {}
for k,v in pairs(es_shortnames) do es_shortnamesr[v] = k end

-- initialize this for the sipping tracking (the thing that decides what to fallback to)
es_potions = es_potions or {}

-- load defaults
for thing, category in pairs(es_categories) do
  es_potions[category] = es_potions[category] or {}
  -- consider 1 so we don't drink the aternative on prefer* right away
  if category == "venom" then
    es_potions[category][thing] = es_potions[category][thing] or {sips = 0, vials = 0, decays = 0}
  else
    es_potions[category][thing] = es_potions[category][thing] or {sips = 2, vials = 2, decays = 0}
  end
end

sk.arena_areas = {
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

