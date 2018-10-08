-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

--[[  basic idea: if asked to eat something, and we a) don't have it (or not enough),
      or b) are in aeon and have it we outr it, and eat it

      otherwise just eat
  ]]
svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/rift+inv")

local rift, me, sys, sk, conf = svo.rift, svo.me, svo.sys, svo.sk, svo.conf
local pipes = svo.pipes

rift.riftcontents = {}
rift.invcontents = {}
me.riftcontents = rift.riftcontents
me.invcontents = rift.invcontents

rift.precache = {}
rift.precachedata = {}

rift.doprecache = false

rift.allherbs = {'ash', 'bayberry', 'bellwort', 'bloodroot', 'cohosh', 'echinacea', 'elm', 'ginger', 'ginseng', 'goldenseal', 'hawthorn', 'kelp', 'kola', 'kuzu', 'lobelia', 'myrrh', 'pear', 'sileris', 'skullcap', 'valerian', 'weed', 'slipper', 'irid', 'ferrum', 'stannum', 'dolomite', 'antimony', 'bisemutum', 'bellwort', 'magnesium', 'calamine', 'malachite', 'azurite', 'plumbum', 'realgar', 'arsenic', 'cohosh', 'argentum', 'calcite', 'potash', 'quicksilver', 'kelp', 'kola', 'cinnabar', 'cuprum', 'aurum', 'quartz', 'gypsum'}
rift.herbsminerals = {'antimony', 'argentum', 'arsenic', 'ash', 'aurum', 'azurite', 'bayberry', 'bellwort', 'bisemutum', 'bloodroot', 'calamine', 'calcite', 'cinnabar', 'cohosh', 'cuprum', 'dolomite', 'echinacea', 'elm', 'ferrum', 'ginger', 'ginseng', 'goldenseal', 'gypsum', 'hawthorn', 'irid', 'kelp', 'kola', 'lobelia', 'magnesium', 'malachite', 'myrrh', 'plumbum', 'potash', 'quartz', 'quicksilver', 'realgar', 'sileris', 'skullcap', 'stannum', 'valerian', 'weed'}
rift.functionalherbs = {'slipper', 'kuzu', 'pear'}

rift.herblist = {'elm', 'valerian', 'ash', 'bayberry', 'bellwort', 'bloodroot', 'cohosh', 'echinacea', 'ginger', 'ginseng', 'goldenseal', 'hawthorn', 'kelp', 'kola', 'kuzu', 'lobelia', 'irid', 'myrrh', 'pear', 'sileris', 'skullcap', 'slipper', 'weed'}
rift.curativeherbs = {'ash', 'bayberry', 'bellwort', 'bloodroot', 'cohosh', 'echinacea', 'elm', 'ginger', 'ginseng', 'goldenseal', 'hawthorn', 'irid', 'kelp', 'kola', 'lobelia', 'myrrh', 'pear', 'sileris', 'skullcap', 'valerian'}

rift.minerallist = {'ferrum', 'stannum', 'dolomite', 'antimony', 'bisemutum', 'cuprum', 'magnesium', 'calamine', 'malachite', 'azurite', 'plumbum', 'realgar', 'arsenic', 'gypsum', 'argentum', 'calcite', 'potash', 'quicksilver', 'aurum', 'quartz', 'cinnabar'}

me.herblist = rift.herblist
me.minerallist = rift.minerallist

rift.forestalvials = {'caloric', 'epidermal', 'frost', 'health', 'immunity', 'levitation', 'mana', 'mass', 'mending', 'restoration', 'speed', 'venom'}

rift.resetriftcontents = function()
  for _, herb in ipairs(rift.allherbs) do
    rift.riftcontents[herb] = 0
  end

  svo.myrift = rift.riftcontents
end

rift.resetinvcontents = function()
  for _, herb in ipairs(rift.allherbs) do
    rift.invcontents[herb] = 0
  end

  svo.myinv = rift.invcontents
end

rift.resetriftcontents()
rift.resetinvcontents()

rift.herbs_plural = {
  elm        = "(%d+) slippery elms",
  valerian   = "(%d+) valerian leaves",
  ash        = "(%d+) pieces of prickly ash bark",
  bayberry   = "(%d+) pieces of bayberry bark",
  bellwort   = "(%d+) bellwort flowers",
  bloodroot  = "(%d+) bloodroot leaves",
  cohosh     = "(%d+) cohosh roots",
  echinacea  = "(%d+) echinacea roots",
  ginger     = "(%d+) ginger roots",
  ginseng    = "(%d+) ginseng roots",
  goldenseal = "(%d+) goldenseal roots",
  hawthorn   = "(%d+) hawthorn berries",
  kelp       = "(%d+) pieces of kelp",
  kola       = "(%d+) kola nuts",
  kuzu       = "(%d+) kuzu roots",
  lobelia    = "(%d+) lobelia seeds",
  irid       = "(%d+) pieces of irid moss",
  myrrh      = "(%d+) myrrh balls",
  pear       = "(%d+) prickly pears",
  sileris    = "(%d+) sileris berries",
  skullcap   = "(%d+) skullcap flowers",
  slipper    = "(%d+) lady's slipper roots",
  weed       = "(%d+) sprigs of cactus weed",

  ferrum      = "(%d+) ferrum flakes",
  stannum     = "(%d+) stannum flakes",
  dolomite    = "(%d+) dolomite grains",
  antimony    = "(%d+) antimony flakes",
  bisemutum   = "(%d+) bisemutum chips",
  cuprum      = "(%d+) cuprum flakes",
  magnesium   = "(%d+) magnesium chips",
  calamine    = "(%d+) calamine crystals",
  malachite   = "(%d+) pinches of ground malachite",
  azurite     = "(%d+) azurite motes",
  plumbum     = "(%d+) plumbum flakes",
  realgar     = "(%d+) pinches of ground realgar",
  arsenic     = "(%d+) arsenic pellets",
  gypsum      = "(%d+) gypsum crystals",
  argentum    = "(%d+) argentum flakes",
  calcite     = "(%d+) calcite motes",
  potash      = "(%d+) potash crystals",
  quicksilver = "(%d+) quicksilver droplets",
  aurum       = "(%d+) aurum flakes",
  quartz      = "(%d+) quartz grains",
  cinnabar    = "(%d+) pinches of ground cinnabar",
}

rift.herbs_singular = {
  ["some prickly ash bark"]  = 'ash',
  ["some bayberry bark"]     = 'bayberry',
  ["a bellwort flower"]      = 'bellwort',
  ["a bloodroot leaf"]       = 'bloodroot',
  ["a black cohosh root"]    = 'cohosh',
  ["an echinacea root"]      = 'echinacea',
  ["slippery elm"]           = 'elm',
  ["a ginger root"]          = 'ginger',
  ["a ginseng root"]         = 'ginseng',
  ["a goldenseal root"]      = 'goldenseal',
  ["a hawthorn berry"]       = 'hawthorn',
  ["a piece of kelp"]        = 'kelp',
  ["a kola nut"]             = 'kola',
  ["a kuzu root"]            = 'kuzu',
  ["a lobelia seed"]         = 'lobelia',
  ["some irid moss"]         = 'irid',
  ["a ball of myrrh gum"]    = 'myrrh',
  ["a prickly pear"]         = 'pear',
  ["a sileris berry"]        = 'sileris',
  ["a skullcap flower"]      = 'skullcap',
  ["a lady's slipper root"]  = 'slipper',
  ["a valerian leaf"]        = 'valerian',
  ["a sprig of cactus weed"] = 'weed',

  ["a ferrum flake"]              = 'ferrum',
  ["a stannum flake"]             = 'stannum',
  ["a dolomite grain"]            = 'dolomite',
  ["an antimony flake"]           = 'antimony',
  ["a bisemutum chip"]            = 'bisemutum',
  ["a cuprum flake"]              = 'cuprum',
  ["a magnesium chip"]            = 'magnesium',
  ["a calamine crystal"]          = 'calamine',
  ["a pinch of ground malachite"] = 'malachite',
  ["an azurite mote"]             = 'azurite',
  ["a plumbum flake"]             = 'plumbum',
  ["a pinch of realgar crystals"] = 'realgar',
  ["an arsenic pellet"]           = 'arsenic',
  ["a gypsum crystal"]            = 'gypsum',
  ["an argentum flake"]           = 'argentum',
  ["a calcite mote"]              = 'calcite',
  ["a potash crystal"]            = 'potash',
  ["a quicksilver droplet"]       = 'quicksilver',
  ["an aurum flake"]              = 'aurum',
  ["a quartz grain"]              = 'quartz',
  ["a pinch of ground cinnabar"]  = 'cinnabar',
}

-- outr line in Achaea uses some special naming - this is formatted for it
rift.herbs_singular_sansprefix = {
  ["prickly ash bark"]    = 'ash',
  ["bayberry bark"]       = 'bayberry',
  ["bellwort flower"]     = 'bellwort',
  ["bloodroot leaf"]      = 'bloodroot',
  ["black cohosh"]        = 'cohosh',
  ['echinacea']           = 'echinacea',
  ["slippery elm"]        = 'elm',
  ["ginger root"]         = 'ginger',
  ["ginseng root"]        = 'ginseng',
  ["goldenseal root"]     = 'goldenseal',
  ["hawthorn berry"]      = 'hawthorn',
  ['kelp']                = 'kelp',
  ["kola nut"]            = 'kola',
  ["kuzu root"]           = 'kuzu',
  ["lobelia seed"]        = 'lobelia',
  ["irid moss"]           = 'irid',
  ["myrrh gum"]           = 'myrrh',
  ["prickly pear"]        = 'pear',
  ['sileris']             = 'sileris',
  ['skullcap']            = 'skullcap',
  ["lady's slipper root"] = 'slipper',
  ['valerian']            = 'valerian',
  ['weed']                = 'weed',

  ['ferrum']      = 'ferrum',
  ['stannum']     = 'stannum',
  ['dolomite']    = 'dolomite',
  ['antimony']    = 'antimony',
  ['bisemutum']   = 'bisemutum',
  ['cuprum']      = 'cuprum',
  ['magnesium']   = 'magnesium',
  ['calamine']    = 'calamine',
  ['malachite']   = 'malachite',
  ['azurite']     = 'azurite',
  ['plumbum']     = 'plumbum',
  ['realgar']     = 'realgar',
  ['arsenic']     = 'arsenic',
  ['gypsum']      = 'gypsum',
  ['argentum']    = 'argentum',
  ['calcite']     = 'calcite',
  ['potash']      = 'potash',
  ['quicksilver'] = 'quicksilver',
  ['aurum']       = 'aurum',
  ['quartz']      = 'quartz',
  ['cinnabar']    = 'cinnabar',
}

-- non-herb items - used in inra sorting. A space is used to accomodate the different materials without introducing complications in the code
rift.items_plural = {
  ["iron "]   = "(%d+) pinches of iron filings",
  ["silver "] = "(%d+) bars of silver",
  coal        = "(%d+) coal pieces",
  gold        = "(%d+) nuggets of gold",
  iron        = "(%d+) iron bars",
  lead        = "(%d+) lead beads",
  nodule      = "(%d+) nodules of copper",
  silver      = "(%d+) silver bars",
  tin         = "(%d+) chunks of tin",
  scales      = "(%d+) piles of fish scales",
  lacquer     = "(%d+) pots of lacquer",
  stone       = "(%d+) stones",
}

rift.items_singular = {
  ["a bar of silver"]        = 'silver',
  ["a bead of lead"]         = 'lead',
  ["a chunk of tin"]         = 'tin',
  ["a nodule of copper"]     = 'nodule',
  ["a piece of coal"]        = 'coal',
  ["a small nugget of gold"] = 'gold',
  ["an iron bar"]            = 'iron',
  ["a pile of fish scales"]  = 'scales',
  ["a small pot of lacquer"] = 'lacquer',
  ["a block of stone"]       = 'stone',
}

rift.herb_conversions = {
  ash        = 'stannum',
  bayberry   = 'arsenic',
  bellwort   = 'cuprum',
  bloodroot  = 'magnesium',
  cohosh     = 'gypsum',
  echinacea  = 'dolomite',
  elm        = 'cinnabar',
  ginger     = 'antimony',
  ginseng    = 'ferrum',
  goldenseal = 'plumbum',
  hawthorn   = 'calamine',
  irid       = 'potash',
  kelp       = 'aurum',
  kola       = 'quartz',
  lobelia    = 'argentum',
  myrrh      = 'bisemutum',
  pear       = 'calcite',
  sileris    = 'quicksilver',
  skullcap   = 'azurite',
  valerian   = 'realgar',
}

rift.vial_conversions = {
  caloric     = 'exothermic',
  epidermal   = 'sensory',
  frost       = 'endothermia',
  health      = 'vitality',
  immunity    = 'antigen',
  levitation  = 'hovering',
  mana        = 'mentality',
  mass        = 'density',
  mending     = 'renewal',
  restoration = 'reconstructive',
  speed       = 'haste',
  venom       = 'toxin',
}

function svo.intlen(number)
  return number == 0 and 1 or math.floor(math.log10(number)+1)
end

rift.update_riftlabel = function()
  if not svo.riftlabel or svo.riftlabel.hidden then return end

  local count = 0
  local tbl = {}
  local columncount = svo.conf.riftlabelcolumns or 3
  local charwidth = 20

  for _, j in pairs(rift.herbsminerals) do
    count = count + 1

    tbl[#tbl+1] = string.format([[<font style="color:grey;">%s</font>%s%d<font style="color:grey;">/</font>%d ]], j, string.rep("&nbsp;", charwidth - #j- svo.intlen(rift.invcontents[j]) - svo.intlen(rift.riftcontents[j])), rift.invcontents[j], rift.riftcontents[j])
    if count % columncount == 0 then tbl[#tbl+1] = "<br />" end
  end

  -- fill up the rest with spaces for alignment
  if count % columncount ~= 0 then
    -- insert spaces for each column (20 chars default) + 1 between each column
    local spacesneeded = (columncount - (count % columncount)) * (charwidth+1)
    tbl[#tbl+1] = string.rep("&nbsp;", spacesneeded)
  end

  echo("svo.riftlabel", string.format([[<center><p style="font-size: ]]..(svo.conf.herbstatsize and svo.conf.herbstatsize or 9)..[[px; color:white; font-weight:;">%s</p></center>]], table.concat(tbl)))
end

rift.outr = function (what)
  if not sys.canoutr then return end

  if (rift.precache[what] and rift.precache[what] == 0) or not rift.invcontents[what] or not rift.precache[what] or (rift.invcontents[what] and rift.precache[what] and (rift.invcontents[what] - 1 >= rift.precache[what])) then
    send("outr " .. what, svo.conf.commandecho)
  else
    send("outr " .. (rift.precache[what] - rift.invcontents[what] + 1) .. " " .. what, svo.conf.commandecho)
  end

  -- allow other outrs to catch up, then re-check again
  if sys.blockoutr then killTimer(sys.blockoutr); sys.blockoutr = nil end
  sys.blockoutr = tempTimer(sys.wait + svo.syncdelay(), function () sys.blockoutr = nil; svo.debugf("sys.blockoutr expired") svo.make_gnomes_work() end)
  svo.debugf("sys.blockoutr setup: ", debug.traceback())
end

rift.checkprecache = function()
  rift.doprecache = false

  for herb, _ in pairs(rift.precache) do
    -- if we have addiction, then only precache 1, otherwise, however much is needed
    if rift.precache[herb] ~= 0 and rift.riftcontents[herb] ~= 0 and (not svo.affs.addiction and (rift.invcontents[herb] < rift.precache[herb]) or (rift.invcontents[herb] == 0)) then
      rift.doprecache = true; return
    end
  end
end

-- used by skeleton's check_herb to see that you can eat something. It checks the appropriate herb in inv if we can't outr
-- takes in dict.<aff>.herb as an argument
svo.signals.curemethodchanged:connect(function ()
  if svo.conf.curemethod == 'conconly' then
    sk.can_eat_for = function (aff)
      return (rift.invcontents[aff.eatcure[1]] > 0)
    end
  elseif svo.conf.curemethod == 'transonly' then
    sk.can_eat_for = function (aff)
      return (rift.invcontents[aff.eatcure[2]] > 0)
    end
  else -- handles nil and prefer*s for curemethod
    sk.can_eat_for = function (aff)
      return (rift.invcontents[aff.eatcure[1]] > 0) or (rift.invcontents[aff.eatcure[2]] > 0)
    end
  end
end)

local function siprandom(what)
  if not svo.es_vialids or not svo.es_vialids[what] or not svo.es_vialids[what][1] then return what end

  return svo.es_vialids[what][math.random(#svo.es_vialids[what])]
end

-- determine the sip method. gets a table as arg with two things - the conc and trans cure
svo.signals.curemethodchanged:connect(function ()
  svo.sip = function (what)
    local use = what.sipcure[1]
    if conf.siprandom then use = siprandom(use) end
    send("sip "..use, conf.commandecho)
    sys.last_used[what.name] = use
  end
end)

-- determine the apply method
svo.signals.curemethodchanged:connect(function ()
  svo.apply = function (what, whereto)
    whereto = whereto or ""
    local use = what.applycure[1]
    send("apply "..use..whereto, conf.commandecho)
    sys.last_used[what.name] = use
  end
end)

-- used to determine what to eat, and set what we've eaten
svo.signals.curemethodchanged:connect(function ()
  if conf.curemethod == 'conconly' then
    sk.synceat = function(what)
      local use = what.eatcure[1]
      if rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        sys.last_used[what.name] = use
      else
        rift.outr(use)
      end
    end
    sk.asynceat = function(what)
      local use = what.eatcure[1]
      if rift.invcontents[use] and rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        rift.outr(use)
      else
        rift.outr(use)
        send("eat " .. use, conf.commandecho)
      end
      sys.last_used[what.name] = use
    end

  elseif conf.curemethod == 'transonly' then
    sk.synceat = function(what)
      local use = what.eatcure[2]
      if rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        sys.last_used[what.name] = use
      else
        rift.outr(use)
      end
    end
    sk.asynceat = function(what)
      local use = what.eatcure[2]
      if rift.invcontents[use] and rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        rift.outr(use)
      else
        rift.outr(use)
        send("eat " .. use, conf.commandecho)
      end
      sys.last_used[what.name] = use
    end

  elseif conf.curemethod == nil or conf.curemethod == 'preferconc' then
    sk.synceat = function(what)
      local use, use2 = what.eatcure[1], what.eatcure[2]
      -- if we don't have the conc cure in inv, but have the alchemy one, use alchemy
      if (not (rift.invcontents[use] > 0) and (rift.invcontents[use2] > 0))
        -- or if we don't have the conc cure in rift either, use alchemy
        or not (rift.riftcontents[use] > 0) then
          use = use2
      end

      if rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        sys.last_used[what.name] = use
      else
        rift.outr(use)
      end
    end
    sk.asynceat = function(what)
      local use, use2 = what.eatcure[1], what.eatcure[2]
      -- if we don't have the conc cure in inv, but have the alchemy one, use alchemy
      if (not (rift.invcontents[use] > 0) and (rift.invcontents[use2] > 0))
        -- or if we don't have the conc cure in rift either, use alchemy
        or not (rift.riftcontents[use] > 0) then
          use = use2
      end

      if rift.invcontents[use] and rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        rift.outr(use)
      else
        rift.outr(use)
        send("eat " .. use, conf.commandecho)
      end
      sys.last_used[what.name] = use
    end

  elseif conf.curemethod == 'prefertrans' then
    -- should eat trans if it's in inv
    -- should eat trans if it's in the rift and no conc in inv
    sk.synceat = function(what)
      -- check if we should use trans
      local use, use2 = what.eatcure[1], what.eatcure[2]
      if (rift.invcontents[use2] > 0)
        or (not (rift.invcontents[use] > 0) and (rift.riftcontents[use2] > 0)) then
          use = use2
      end

      if rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        sys.last_used[what.name] = use
      else
        rift.outr(use)
      end
    end
    sk.asynceat = function(what)
      local use, use2 = what.eatcure[1], what.eatcure[2]
      if (rift.invcontents[use2] > 0)
        or (not (rift.invcontents[use] > 0) and (rift.riftcontents[use2] > 0)) then
          use = use2
      end

      if rift.invcontents[use] and rift.invcontents[use] > 0 then
        send("eat " .. use, conf.commandecho)
        rift.outr(use)
      else
        rift.outr(use)
        send("eat " .. use, conf.commandecho)
      end
      sys.last_used[what.name] = use
    end

  elseif conf.curemethod == 'prefercustom' then
    -- should eat trans if it's in inv
    -- should eat trans if it's in the rift and no conc in inv
    sk.synceat = function(what)
      if me.curelist[what.eatcure[1]] == what.eatcure[1] then
        local use, use2 = what.eatcure[1], what.eatcure[2]
        -- if we don't have the conc cure in inv, but have the alchemy one, use alchemy
        if (not (rift.invcontents[use] > 0) and (rift.invcontents[use2] > 0))
          -- or if we don't have the conc cure in rift either, use alchemy
          or not (rift.riftcontents[use] > 0) then
            use = use2
        end

        if rift.invcontents[use] > 0 then
          send("eat " .. use, conf.commandecho)
          sys.last_used[what.name] = use
        else
          rift.outr(use)
        end
      else
        local use, use2 = what.eatcure[1], what.eatcure[2]
        if (rift.invcontents[use2] > 0)
          or (not (rift.invcontents[use] > 0) and (rift.riftcontents[use2] > 0)) then
            use = use2
        end

        if rift.invcontents[use] > 0 then
          send("eat " .. use, conf.commandecho)
          sys.last_used[what.name] = use
        else
          rift.outr(use)
        end
      end
    end
    sk.asynceat = function(what)
      if me.curelist[what.eatcure[1]] == what.eatcure[1] then
        local use, use2 = what.eatcure[1], what.eatcure[2]
        -- if we don't have the conc cure in inv, but have the alchemy one, use alchemy
        if (not (rift.invcontents[use] > 0) and (rift.invcontents[use2] > 0))
          -- or if we don't have the conc cure in rift either, use alchemy
          or not (rift.riftcontents[use] > 0) then
            use = use2
        end

        if rift.invcontents[use] and rift.invcontents[use] > 0 then
          send("eat " .. use, conf.commandecho)
          rift.outr(use)
        else
          rift.outr(use)
          send("eat " .. use, conf.commandecho)
        end
        sys.last_used[what.name] = use
      else
        local use, use2 = what.eatcure[1], what.eatcure[2]
        if (rift.invcontents[use2] > 0)
          or (not (rift.invcontents[use] > 0) and (rift.riftcontents[use2] > 0)) then
            use = use2
        end

        if rift.invcontents[use] and rift.invcontents[use] > 0 then
          send("eat " .. use, conf.commandecho)
          rift.outr(use)
        else
          rift.outr(use)
          send("eat " .. use, conf.commandecho)
        end
        sys.last_used[what.name] = use
      end
    end

    -- disabled for now, because tracking which herb we used for an action is problematic
  -- elseif conf.curemethod == 'auto' then
  --   sk.synceat = function(what)
  --     -- if we have the alchemy cure, use it, otherwise stick to usual
  --     local haveusual, havealchemy = rift.invcontents[what], rift.invcontents[herb_conversions[what]]
  --     if haveusual and havealchemy then
  --       what = (math.random(1,2) == 1) and what or herb_conversions[what]
  --     elseif not haveusual then
  --       what = herb_conversions[what]
  --     end

  --     if rift.invcontents[what] > 0 then
  --       send("eat " .. what, conf.commandecho)
  --     else
  --       rift.outr(what)
  --     end
  --   end
  --   sk.asynceat = function(what)
  --     local haveusual, havealchemy = rift.invcontents[what], rift.invcontents[herb_conversions[what]]
  --     if haveusual and havealchemy then
  --       what = (math.random(1,2) == 1) and what or herb_conversions[what]
  --     elseif not haveusual then
  --       what = herb_conversions[what]
  --     end

  --     if rift.invcontents[what] and rift.invcontents[what] > 0 then
  --       send("eat " .. what, conf.commandecho)
  --       rift.outr(what)
  --     else
  --       rift.outr(what)
  --       send("eat " .. what, conf.commandecho)
  --     end
    -- end
  end

  -- update the actual 'eat' function
  sk.checkaeony()
  svo.signals.aeony:emit()
end)

svo.signals.systemstart:connect(function()
  svo.signals.curemethodchanged:emit()
end)

svo.signals.aeony:connect(function ()
  if sys.sync then
    svo.eat = sk.synceat
  else
    svo.eat = sk.asynceat
  end
end)

local smoke_herb_conversions = {
  elm      = 'cinnabar',
  skullcap = 'malachite',
  valerian = 'realgar',
}

-- pipes don't need to be refilled that often, so we'll do the herb selection realtime instead of recompiling this huge monster all the time
function sk.asyncfill(what, where)
  local orig = what

  -- work out if we need to change what to its alternative
  if conf.curemethod ~= 'conconly' and (

    conf.curemethod == 'transonly' or

    ((conf.curemethod == 'preferconc' or conf.curemethod == nil) and
      -- we don't have in forestal inventory, but do have alchemy in inventory, use alchemy
       (not (rift.invcontents[what] > 0) and (rift.invcontents[smoke_herb_conversions[what]] > 0)) or
        -- or if we don't have the conc cure in rift either, use alchemy
       (not (rift.riftcontents[what] > 0))) or

    (conf.curemethod == 'prefertrans' and -- we *do* have the trans available
      (rift.invcontents[smoke_herb_conversions[what]] > 0
        or (not (rift.invcontents[what] > 0) and (rift.riftcontents[smoke_herb_conversions[what]] > 0)))) or

    -- prefercustom, and we either prefer alchy and have it, or prefer conc and don't have it
    (conf.curemethod == 'prefercustom' and
      ((me.curelist[what] == smoke_herb_conversions[what] and rift.riftcontents[smoke_herb_conversions[what]] > 0)
        or
       (me.curelist[what] == what and rift.riftcontents[what] <= 0)
      )
    )) then
      what = smoke_herb_conversions[what]
  end

  sys.last_used['fill'..orig..'_physical'] = what
  pipes[orig].filledwith = what

  if rift.invcontents[what] > 0 then
    if pipes[orig].puffs > 0 then
      if not svo.defc.selfishness then
        send("empty "..where, conf.commandecho)
      else
        for _ = 1, (pipes[orig].puffs + 1) do
          send("smoke "..where, conf.commandecho)
        end
      end
    end

    send("put " .. what .. " in " .. where, conf.commandecho)
    rift.outr(what)
  else
    rift.outr(what)
    if pipes[orig].puffs > 0 then
      if not svo.defc.selfishness then
        send("empty "..where, conf.commandecho)
      else
        for _ = 1, (pipes[orig].puffs + 1) do
          send("smoke "..where, conf.commandecho)
        end
      end
    end
    send("put " .. what .. " in " .. where, conf.commandecho)
  end
end

function sk.syncfill(what, where)
  local orig = what
  -- work out if we need to change what to its alternative
  if conf.curemethod ~= 'conconly' and (

    conf.curemethod == 'transonly' or

    ((conf.curemethod == 'preferconc' or conf.curemethod == nil) and
       (not (rift.invcontents[what] > 0) and (rift.invcontents[smoke_herb_conversions[what]] > 0))
        -- or if we don't have the conc cure in rift either, use alchemy
        or not (rift.riftcontents[what] > 0)) or

    (conf.curemethod == 'prefertrans' and
      (rift.invcontents[smoke_herb_conversions[what]] > 0)
        or (not (rift.invcontents[what] > 0) and (rift.riftcontents[smoke_herb_conversions[what]] > 0))) or

    -- prefercustom, and we either prefer alchy and have it, or prefer conc and don't have it
    (conf.curemethod == 'prefercustom' and (
      (me.curelist[what] == what and rift.riftcontents[what] <= 0)
        or
      (me.curelist[what] == smoke_herb_conversions[what] and rift.riftcontents[smoke_herb_conversions[what]] > 0)
    ))) then
      what = smoke_herb_conversions[what]
  end

  sys.last_used['fill'..orig..'_physical'] = what
  pipes[orig].filledwith = what

  if pipes[orig].puffs > 0 then
    if svo.defc.selfishness then svo.echof("Problem - can't refill while selfish :/") return end
    send("empty "..where, conf.commandecho)
  elseif rift.invcontents[what] > 0 then
    send("put " .. what .. " in " .. where, conf.commandecho)
  else
    rift.outr(what)
  end
end

svo.signals.aeony:connect(function ()
  if sys.sync then
    svo.fillpipe = sk.syncfill
  else
    svo.fillpipe = sk.asyncfill
  end
end)


function svo.riftline()
  for i = 1, #matches, 3 do
    local amount = tonumber(matches[i+1])
    local rawherbstring, herb = matches[i+2], false

    -- Achaea's rift doesn't use standard singular naming or even the short names,
    -- so substring find which herb is it
    for _, herbi in ipairs(rift.allherbs) do
      if rawherbstring:find("%f[%a]"..herbi.."%f[%A]") then
        herb = herbi
        break
      end
    end

    if herb and amount then
      rift.riftcontents[herb] = amount
    end
  end

  rift.update_riftlabel()
end

function svo.showrift()
  display(rift.riftcontents)
end

function svo.showinv()
  display(rift.invcontents)
end

function svo.showprecache()
  local count = 1

  local function makelink(herb, sign)
    if sign == "-" and rift.precache[herb] == 0 then
      echo " "
    elseif sign == "+" then
      echoLink(sign, [[svo.setprecache("]]..herb..[[", 1, 'add', nil, true)]], sign .. " the " .. herb .. " amount")
    elseif sign == "-" then
      echoLink(sign, [[svo.setprecache("]]..herb..[[", 1, 'subtract', nil, true)]], sign .. " the " .. herb .. " amount")
    else
      echo " "
    end

    return ""
  end

--[[  moveCursor('main', 0, getLastLineNumber('main'))
  debugf("line: " .. getCurrentLine() .. ", latest: " .. getLastLineNumber('main'))
  if getCurrentLine() == "-" or getCurrentLine() == " " then
    insertText(" ")
    for i = 1, 1000 do deleteLine()
    debugf('deleting') end
  end]]
  svo.echof("Herb pre-cache list (%s defences):", svo.defs.mode)

  local t = {}; for herb in pairs(rift.precache) do t[#t+1] = herb end; table.sort(t)
  for i = 1, #t do
    local herb, amount = t[i], rift.precache[t[i]]
  -- for herb, amount in pairs(rift.precache) do
    if count % 3 ~= 0 then
      decho(string.format("<153,204,204>[<91,134,214>%d<153,204,204>%s%s] %-"..(svo.intlen(amount) == 1 and '23' or '22')..'s', amount, makelink(herb, "+"), makelink(herb, "-"), herb))
    else
      decho(string.format("<153,204,204>[<91,134,214>%d<153,204,204>%s%s] %s", amount, makelink(herb, "+"), makelink(herb, "-"), herb)) end

    if count % 3 == 0 then echo("\n") end
    count = count + 1
  end

--[[  moveCursor('main', 0, getLastLineNumber('main'))
  moveCursor('main', #getCurrentLine(), getLastLineNumber('main'))
  insertText("\n-\n")]]
  echo"\n"
  svo.showprompt()
end

function svo.setprecache(herb, amount, flag, echoback, show_list)
  local sendf
  if echoback then sendf = svo.echof else sendf = svo.errorf end

  svo.assert(rift.precache[herb], "what herb do you want to set a precache amount for?", sendf)

  if flag == 'add' then
    rift.precache[herb] = rift.precache[herb] + amount
  elseif flag == 'subtract' then
    rift.precache[herb] = rift.precache[herb] - amount
    if rift.precache[herb] < 0 then rift.precache[herb] = 0 end
  elseif not flag or flag == 'set' then
    rift.precache[herb] = amount
  end

  if echoback then
    svo.echof("Will keep at least %d of %s out in the inventory now.", rift.precache[herb], herb)
  elseif show_list then
    svo.showprecache()
  end
  rift.checkprecache()
end

function svo.invline()
  rift.resetinvcontents()

  -- lowercase as the first letter is capitalised
  local line = line:lower()
  local tabledline = line:split(", ")

  -- strip out the last 'and'
  if tabledline[#tabledline]:starts("and ") then
    tabledline[#tabledline] = tabledline[#tabledline]:gsub("^and ", '')
  end

  -- for everything we got in our inv
  for i = 1, #tabledline do
    local riftable = tabledline[i]
    if riftable:sub(-1) == "." then riftable = riftable:sub(1,#riftable - 1) end -- kill trailing dot

    -- tally up rift.herbs_singular items
    if rift.herbs_singular[riftable] then
      rift.invcontents[rift.herbs_singular[riftable]] = rift.invcontents[rift.herbs_singular[riftable]] + 1
    end

    -- tally up rift.herbs_plural items
    for k,l in pairs(rift.herbs_plural) do
      local result = riftable:match(l)
      if result then
        rift.invcontents[k] = rift.invcontents[k] + tonumber(result)
      end
    end
  end

  rift.update_riftlabel()
  rift.checkprecache()
end

function svo.riftremoved()
  local removed = tonumber(matches[2])
  local what = rift.herbs_singular_sansprefix[matches[3]]
  local inrift = tonumber(matches[4])

  if not (what and removed and inrift) then return end

  if rift.riftcontents[what] then rift.riftcontents[what] = inrift end
  if rift.invcontents[what] then rift.invcontents[what] = rift.invcontents[what] + removed end

  rift.update_riftlabel()

  svo.signals.removed_from_rift:emit(removed, what, inrift)

  -- don't add if not doing it
  svo.checkaction(svo.dict.doprecache.misc, false)
  if svo.actions.doprecache_misc then
    svo.lifevision.add(svo.actions.doprecache_misc.p)
  end
end

function svo.pocketbelt_added()
  local removedamount = tonumber(matches[2])
  local what = matches[3]
  if not rift.invcontents[what] then return end

  rift.invcontents[what] = rift.invcontents[what] - removedamount
end

function svo.pocketbelt_removed()
  local removedamount = tonumber(matches[2])
  local what = matches[3]
  if not rift.invcontents[what] then return end

  rift.invcontents[what] = rift.invcontents[what] + removedamount
end

function svo.riftadded()
  local removed = tonumber(matches[2])
  local what = rift.herbs_singular_sansprefix[matches[3]]
  if not what then return end
  local inrift = tonumber(matches[4])

  if rift.riftcontents[what] then rift.riftcontents[what] = inrift end
  if rift.invcontents[what] then rift.invcontents[what] = rift.invcontents[what] - removed end
  if rift.invcontents[what] and rift.invcontents[what] < 0 then rift.invcontents[what] = 0 end

  rift.update_riftlabel()
  rift.checkprecache()
end

function svo.riftnada()
  local what = matches[2]
  if rift.invcontents[what] then rift.invcontents[what] = 0 end

  rift.update_riftlabel()
  rift.checkprecache()
end

function svo.riftate()
  -- if conf.aillusion and not (usingbal'herb' or usingbal'moss') then
  --   resetFormat()
  --   echoLink(" (i)", '', "Precache considered this to be an illusion (because the system isn't eating anything right now) and didn't count the herb used", true)
  --   return
  -- end

  local what = matches[2]

  if not rift.herbs_singular[what] then return end

  if not svo.conf.arena then
    rift.invcontents[rift.herbs_singular[what]] = rift.invcontents[rift.herbs_singular[what]] - 1
    if rift.invcontents[rift.herbs_singular[what]] < 0 then rift.invcontents[rift.herbs_singular[what]] = 0 end
  end

  rift.update_riftlabel()
  rift.checkprecache()
end

do
  local oldCL = createLabel
  function createLabel(name, posX, posY, width, height, fillBackground)
    oldCL(name, 0, 0, 0, 0, fillBackground)
    moveWindow(name, posX, posY)
    resizeWindow(name, width, height)
  end
end

function svo.toggle_riftlabel(toggle)
  if (type(toggle) == 'nil' and svo.riftlabel.hidden) or (type(toggle) ~= 'nil' and toggle) then
    svo.riftlabel:show()
    rift.update_riftlabel()
    svo.echof("Spawned the herbstat window.")
    svo.conf.riftlabel = true
    raiseEvent("svo config changed", 'riftlabel')
  elseif (type(toggle) == 'nil' and not svo.riftlabel.hidden) or (type(toggle) ~= 'nil' and not toggle) then
    svo.riftlabel:hide()
    svo.echof("Hid the herbstat window.")
    svo.conf.riftlabel = false
    raiseEvent("svo config changed", 'riftlabel')
  end
end

svo.signals.systemstart:add_post_emit(function ()
  if lfs.attributes(getMudletHomeDir() .. "/svo/rift+inv/rift") then
    table.load(getMudletHomeDir() .. "/svo/rift+inv/rift", rift.riftcontents)
  end
  if lfs.attributes(getMudletHomeDir() .. "/svo/rift+inv/inv") then
    table.load(getMudletHomeDir() .. "/svo/rift+inv/inv", rift.invcontents)
  end

  -- reset, because we can't have herbs in inv at login
  rift.resetinvcontents()

  for mode, _ in pairs(svo.defdefup) do
    rift.precachedata[mode] = {}

    for _,herb in pairs(rift.herbsminerals) do
      rift.precachedata[mode][herb] = 0
    end

    if mode == 'combat' then
      rift.precachedata[mode].irid = 1
      rift.precachedata[mode].kelp = 1
      rift.precachedata[mode].bloodroot = 1
    end
  end



  local tmp = {}
  if lfs.attributes(getMudletHomeDir() .. "/svo/rift+inv/precachedata") then
    table.load(getMudletHomeDir() .. "/svo/rift+inv/precachedata", tmp)
    svo.update(rift.precachedata, tmp)
    rift.precache = rift.precachedata[svo.defs.mode]

    -- moss was removed, get rid of it
    for _, m in pairs(rift.precachedata) do
      if m.moss then m.moss = nil end
    end
  end
  rift.update_riftlabel()
end)

svo.signals.enablegmcp:connect(function()
  sendGMCP([[Core.Supports.Add ["IRE.Rift 1"] ]])
end)

svo.signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/rift+inv/rift", rift.riftcontents)
  svo.tablesave(getMudletHomeDir() .. "/svo/rift+inv/inv", rift.invcontents)
  svo.tablesave(getMudletHomeDir() .. "/svo/rift+inv/precachedata", rift.precachedata)
end)


sk.checkaeony()
svo.signals.aeony:emit()

