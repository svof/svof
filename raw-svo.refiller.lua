-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local conf = svo.conf

svo.rf_debug = false

-- format: {p = {potion = { normal = #, arty = 0/#}}, currentorder = ""}
-- this stores the total order that we need to do
svo.rf_refilling = false

-- format: 'potion'
-- this stores the current potion that we're doing of the whole order

-- need a variable to handle either remedies or toxicology transcendence
svo.rf_currenttrans = svo.rf_currenttrans or false

conf.potid = conf.potid or 'pot'
svo.config.setoption('potid', {
  type = 'string',
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("refiller: ", "", "svo Refiller", true)
    fg(defaultcolour) echo("Pot to use is ")
    fg('a_cyan') echoLink((conf.potid or 'pot'), "printCmdLine 'vconfig potid pot###'", "Click to set the pot ID to use for brewing in", true)
    fg(defaultcolour) echo("; storing your vials in")
    fg('a_cyan') echoLink(" "..(conf.packid or 'pack'), "printCmdLine'vconfig packid '", "Click to set the pack ID to stuff your vials into when you do 'putvials'", true)
    fg(defaultcolour) echo(".\n")
  end,
  onset = function ()
    svo.echof("Okay, will brew in the %s item.", conf.potid)
  end
})

conf.packid = conf.packid or 'pack'
svo.config.setoption('packid', {
  type = 'string',
  onset = function ()
    svo.echof("Okay, will store vials in %s when you do 'putvials'. Doing 'getvials' will get them back out.", conf.packid)
  end
})

local concoctions = {
  epidermal = {
    ['kuzu'] = 2,
    ['bloodroot'] = 1,
    ['hawthorn'] = 1,
    ['ginseng'] = 1
  },
  immunity = {
    ['sac'] = 1,
    ['ash'] = 1,
    ['echinacea'] = 2,
  },
  mana = {
    ['slipper'] = 1,
    ['bellwort'] = 1,
    ['hawthorn'] = 1,
    ['bloodroot'] = 1,
  },
  health = {
    ['valerian'] = 1,
    ['goldenseal'] = 1,
    ['ginseng'] = 1,
    ['myrrh'] = 1,
  },
  venom = {
    ['sac'] = 1,
    ['cohosh'] = 1,
    ['kelp'] = 1,
    ['skullcap'] = 1,
  },
  frost = {
    ['kelp'] = 1,
    ['pear'] = 1,
    ['ginseng'] = 1,
  },
  levitation = {
    ['kelp'] = 2,
    ['pear'] = 1,
    ['eaglefeather'] = 1,
  },
  mending = {
    ['ginger'] = 2,
    ['diamonddust'] = 1,
    ['kelp'] = 1,
    ['kuzu'] = 1,
  },
  mass = {
    ['moss'] = 1,
    ['bloodroot'] = 1,
    ['diamonddust'] = 1,
    ['kuzu'] = 1,
  },
  speed = {
    ['skin'] = 2,
    ['goldenseal'] = 1,
    ['kuzu'] = 1,
    ['ginger'] = 1,
  },
  restoration = {
    ['kuzu'] = 2,
    ['valerian'] = 1,
    ['bellwort'] = 1,
    ['gold'] = 2,
  },
  caloric = {
    ['kuzu'] = 2,
    ['kelp'] = 2,
    ['valerian'] = 1,
    ['bellwort'] = 1
  }
}

local toxins = {
  xentio = {
    ['kelp'] = 2,
    ['bloodroot'] = 1,
    ['blueink'] = 1
  },
  oleander = {
    ['bayberry'] = 1,
    ['ginseng'] = 1,
    ['blueink'] = 1
  },
  eurypteria = {
    ['lobelia'] = 1,
    ['goldenseal'] = 1,
    ['redink'] = 1
  },
  kalmia = {
    ['bloodroot'] = 1,
    ['ginseng'] = 1,
    ['moss'] = 1,
    ['redink'] = 1,
    ['blueink'] = 1
  },
  digitalis = {
    ['bellwort'] = 1,
    ['lobelia'] = 1,
    ['redink'] = 1
  },
  darkshade = {
    ['bloodroot'] = 1,
    ['ginseng'] = 1,
    ['kelp'] = 1,
    ['redink'] = 1
  },
  curare = {
    ['bloodroot'] = 1,
    ['bellwort'] = 1,
    ['greenink'] = 1
  },
  epteth = {
    ['valerian'] = 1,
    ['bellwort'] = 1,
    ['yellowink'] = 1
  },
  prefarar = {
    ['bloodroot'] = 1,
    ['ginseng'] = 1,
    ['purpleink'] = 1
  },
  monkshood = {
    ['valerian'] = 1,
    ['bellwort'] = 1,
    ['redink'] = 1
  },
  euphorbia = {
    ['kelp'] = 1,
    ['goldenseal'] = 1,
    ['greenink'] = 1
  },
  colocasia = {
    ['bayberry'] = 1,
    ['hawthorn'] = 1,
    ['blueink'] = 1
  },
  oculus = {
    ['bayberry'] = 1,
    ['goldenseal'] = 1,
    ['redink'] = 1
  },
  vernalius = {
    ['kelp'] = 2,
    ['goldenseal'] = 1,
    ['purpleink'] = 1
  },
  epseth = {
    ['valerian'] = 1,
    ['bellwort'] = 1,
    ['purpleink'] = 1
  },
  larkspur = {
    ['goldenseal'] = 2,
    ['kelp'] = 1,
    ['blueink'] = 1
  },
  slike = {
    ['ginseng'] = 2,
    ['elm'] = 1,
    ['greenink'] = 1
  },
  voyria = {
    ['ginseng'] = 3,
    ['skullcap'] = 2,
    ['goldenseal'] = 2,
    ['goldink'] = 1,
    ['redink'] = 1
  },
  delphinium = {
    ['bellwort'] = 2,
    ['goldenseal'] = 1,
    ['blueink'] = 1
  },
  vardrax = {
    ['skullcap'] = 1,
    ['elm'] = 1,
    ['ginseng'] = 1,
    ['greenink'] = 1
  },
  loki = {
    ['goldenseal'] = 2,
    ['kelp'] = 2,
    ['bloodroot'] = 2,
    ['ginseng'] = 1,
    ['yellowink'] = 2
  },
  aconite = {
    ['goldenseal'] = 2,
    ['lobelia'] = 1,
    ['yellowink'] = 1
  },
  selarnia = {
    ['lobelia'] = 1,
    ['bloodroot'] = 1,
    ['goldink'] = 1
  },
  gecko = {
    ['valerian'] = 1,
    ['bloodroot'] = 1,
    ['kelp'] = 1,
    ['purpleink'] = 1
  }
}

local function outr(what, amount)
  if what == 'gold' then
    svo.sendc("get "..amount.." gold from "..conf.packid, svo.rf_debug)
    return
  end

  if amount == 1 then svo.sendc("outr "..what, svo.rf_debug)
  else svo.sendc("outr "..amount.." "..what, svo.rf_debug) end
end

local function inpot(what, amount, pot)

  while amount > 50 do
    svo.sendc("inpot 50 "..what.." in "..pot, svo.rf_debug)
    amount = amount - 50
  end

  if amount == 1 then
    svo.sendc("inpot "..what.." in "..pot, svo.rf_debug)
  else
    svo.sendc("inpot "..amount.. " "..what.." in "..pot, svo.rf_debug)
  end
end

function svo.rf_fillpot(potion, fills, pot)
  svo.assert(potion and fills, "rf_fillpot: need to supply both what to brew and what amount to brew")

  -- 1 set of ingredients = 1 fill

  -- Have to change this. If I don't, it's going to be a massive
  -- rewrite of the entire refilling system, with lots of duplicate functions
  -- just to accomodate toxins.
  --svo.assert(concoctions[potion], "rf_fillpot: don't know about such a potion")
  if not concoctions[potion] and not toxins[potion] then
    svo.assert(false, "svo.rf_fillpot: don't know about such a potion")
  end

  for item, amount in pairs(concoctions[potion]) do
    outr(item, amount * fills)
    inpot(item, amount * fills, pot or conf.potid)
  end
end

function svo.rf_boilpot(pot)
  pot = pot or conf.potid

  svo.rf_wait_to_boil = tempTimer(getNetworkLatency()+1, function ()
    if not svo.defc.selfishness then
      svo.sendc("boil "..pot.." for "..tostring(svo.rf_refilling.currentorder), svo.rf_debug)
    else
      svo.sendc('generosity', svo.rf_debug)
      svo.rf_temptrigger = tempExactMatchTrigger("You have recovered equilibrium.", "killTrigger(svo.svo.rf_temptrigger); svo.sendc('boil "..pot.." for "..tostring(svo.rf_refilling.currentorder).."', svo.svo.rf_debug)")
    end
  end)
end

function svo.rf_magichappened()
  if not svo.rf_refilling then return end

  svo.doadd(function()
    if svo.rf_refilling.currentorderdata then
      for _ = 1, svo.rf_refilling.currentorderdata.arty do
        svo.rf_fillarty()
      end

      for _ = 1, (svo.rf_refilling.currentorderdata.normal - svo.rf_refilling.currentorderdata.arty) do
        svo.rf_fillnext()
      end
    end

    echo'\n' svo.rf_nextpotion()
  end)
end

function svo.rf_fillnext()
  if not svo.rf_refilling then return end

  svo.sendc("fill emptyvial from "..conf.potid.." "..(svo.rf_currenttrans and 4 or 5).." times", svo.rf_debug)
end

function svo.rf_fillarty()
  if not svo.rf_refilling then return end

  if not svo.rf_arties[1] then
    svo.missing_arty = (svo.missing_arty or 0) + 1
    svo.prompttrigger("warn of missing arties", function()
      svo.echof("You're missing %s artefact vials that were needed in the order, fyi.", svo.missing_arty)
      svo.missing_arty = nil
    end)
    return
  end

  svo.sendc("fill "..table.remove(svo.rf_arties).." from "..conf.potid.." "..(svo.rf_currenttrans and 2 or 3).." times", svo.rf_debug)
end

function svo.rf_cancel()
  svo.rf_refilling = nil
  svo.undoall()
  svo.echof("Cancelled refilling.")
end

function svo.rf_refill(what)
  what = what:split(",")
  local needarties

  svo.rf_refilling = { p = {}, currentorder = false, currentorderdata = false}
  for i = 1, #what do
    what[i] = what[i]:trim()
    local amount, potion
    if what[i]:find("^(%d+) (%w+)") then
      amount, potion = what[i]:match("^(%d+) (%w+)")
    elseif what[i]:find("^(%w+)") then
      amount, potion = 1, what[i]:match("^(%w+)")
    end

    if not concoctions[potion] and not toxins[potion] then
      svo.echof("Don't know the ingredients for a '%s' potion :|", tostring(potion))
    else
      svo.rf_refilling.p[potion] = {normal = tonumber(amount)}
      svo.rf_refilling.p[potion].arty = tonumber(what[i]:match("(%d+) arty$") or 0)

      if svo.rf_refilling.p[potion].arty > 0 then
        needarties = true
      end

      if svo.rf_refilling.p[potion].arty > svo.rf_refilling.p[potion].normal then
        svo.echof("You can't have only %s refills of %s, and %s of them into artefact vials... going to assume you wanted %s %s refills total.", svo.rf_refilling.p[potion].normal, potion, svo.rf_refilling.p[potion].arty, svo.rf_refilling.p[potion].arty, potion)
        svo.rf_refilling.p[potion].normal = svo.rf_refilling.p[potion].arty
      end
    end
  end

  if not next(svo.rf_refilling.p) then
    svo.rf_refilling = nil
    svo.echof("Don't have anything to refill, then :/")
    return
  end

  svo.rf_previousorder = svo.deepcopy(svo.rf_refilling.p)
  if not needarties then svo.rf_nextpotion() else
    svo.echof("Looking for the artefact vials...")
    svo.sendc("config pagelength 250", svo.rf_debug)
    svo.sendc("ii artefact", svo.rf_debug)
    svo.sendc("config pagelength "..(conf.pagelength >= 20 and conf.pagelength or 20), svo.rf_debug)
  end
end

-- to be called only when we need to do the next potion
function svo.rf_nextpotion()
  svo.rf_refilling.currentorder = next(svo.rf_refilling.p)
  svo.rf_refilling.currentorderdata = svo.rf_refilling.p[svo.rf_refilling.currentorder]
  if not svo.rf_refilling.currentorder then
    svo.rf_refilling = nil
    svo.echof("Done refilling!")
    raiseEvent("svo done refilling")
  else
    svo.echof("Going to work on refilling %s.", tostring(svo.rf_refilling.currentorder))

    -- change which trans to check based on what we're brewing
    if concoctions[svo.rf_refilling.currentorder] then
      svo.rf_currenttrans = svo.rf_transrefiller
    else
      svo.rf_currenttrans = svo.rf_transtoxicology
    end

    svo.rf_fillpot(svo.rf_refilling.currentorder,
      -- refill 5 health 2 arty means 3 normal + 2 arty!
      (svo.rf_refilling.p[svo.rf_refilling.currentorder].normal - svo.rf_refilling.p[svo.rf_refilling.currentorder].arty) * (svo.rf_currenttrans and 4 or 5) +
      svo.rf_refilling.p[svo.rf_refilling.currentorder].arty * 2)
    svo.rf_boilpot()

    -- clear the fill so next time rf_nextpotion() is called, it's fine
    svo.rf_refilling.p[svo.rf_refilling.currentorder] = nil
  end
end

function svo.rf_undopot(potion, fills, pot)
  svo.assert(potion and fills, "rf_undopot: need to supply potion and how many fills went in")

  svo.assert(concoctions[potion], "rf_undopot: don't know about such a potion")
  for item, amount in pairs(concoctions[potion]) do
    svo.doadd("get "..amount * fills.." "..item.." from "..(pot or conf.potid))
  end
  svo.doadd("get "..(pot or conf.potid))
  svo.doadd("refill next potion")
end

function svo.rf_missingstuff()
  disableTrigger("Missing ingredients"); tempTimer(2, function() enableTrigger("Missing ingredients") end)
  killTimer(svo.rf_wait_to_boil)

  echo'\n' svo.echof("Ack, looks like you're out of enough ingredients - going to get what we put into the pot back...")

    svo.rf_undopot(svo.rf_refilling.currentorder,
      (svo.rf_refilling.currentorderdata.normal - svo.rf_refilling.currentorderdata.arty) * (svo.rf_currenttrans and 4 or 5) +
      svo.rf_refilling.currentorderdata.arty * 2)
end
