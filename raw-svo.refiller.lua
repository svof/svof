-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

rf_debug = false

-- format: {p = {potion = { normal = #, arty = 0/#}}, currentorder = ""}
-- this stores the total order that we need to do
rf_refilling = false

-- format: "potion"
-- this stores the current potion that we're doing of the whole order

conf.potid = conf.potid or "pot"
config.setoption("potid", {
  type = "string",
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg("gold")
    echoLink("refiller: ", "", "svo Refiller", true)
    fg(defaultcolour) echo("Pot to use is ")
    fg("a_cyan") echoLink((conf.potid or "pot"), "printCmdLine 'vconfig potid pot###'", "Click to set the pot ID to use for brewing in", true)
    fg(defaultcolour) echo("; storing your vials in")
    fg("a_cyan") echoLink(" "..(conf.packid or 'pack'), "printCmdLine'vconfig packid '", "Click to set the pack ID to stuff your vials into when you do 'putvials'", true)
    fg(defaultcolour) echo(".\n")
  end,
  onset = function ()
    echof("Okay, will brew in the %s item.", conf.potid)
  end
})

conf.packid = conf.packid or "pack"
config.setoption("packid", {
  type = "string",
  onset = function ()
    echof("Okay, will store vials in %s when you do 'putvials'. Doing 'getvials' will get them back out.", conf.packid)
  end
})

local concoctions = {
  epidermal = {
    ["kuzu"] = 2,
    ["bloodroot"] = 1,
    ["hawthorn"] = 1,
    ["ginseng"] = 1
  },
  immunity = {
    ["sac"] = 1,
    ["ash"] = 1,
    ["echinacea"] = 2,
  },
  mana = {
    ["slipper"] = 1,
    ["bellwort"] = 1,
    ["hawthorn"] = 1,
    ["bloodroot"] = 1,
  },
  health = {
    ["valerian"] = 1,
    ["goldenseal"] = 1,
    ["ginseng"] = 1,
    ["myrrh"] = 1,
  },
  venom = {
    ["sac"] = 1,
    ["cohosh"] = 1,
    ["kelp"] = 1,
    ["skullcap"] = 1,
  },
  frost = {
    ["kelp"] = 1,
    ["pear"] = 1,
    ["ginseng"] = 1,
  },
  levitation = {
    ["kelp"] = 2,
    ["pear"] = 1,
    ["eaglefeather"] = 1,
  },
  mending = {
    ["ginger"] = 2,
    ["diamonddust"] = 1,
    ["kelp"] = 1,
    ["kuzu"] = 1,
  },
  mass = {
    ["moss"] = 1,
    ["bloodroot"] = 1,
    ["diamonddust"] = 1,
    ["kuzu"] = 1,
  },
  speed = {
    ["skin"] = 2,
    ["goldenseal"] = 1,
    ["kuzu"] = 1,
    ["ginger"] = 1,
  },
  restoration = {
    ["kuzu"] = 2,
    ["valerian"] = 1,
    ["bellwort"] = 1,
    ["gold"] = 2,
  },
  caloric = {
    kuzu = 2,
    kelp = 2,
    valerian = 1,
    bellwort = 1
  }
}

local function outr(what, amount)
  if what == "gold" then
    sendc("get "..amount.." gold from "..conf.packid, rf_debug)
    return
  end

  if amount == 1 then send("outr "..what, rf_debug)
  else sendc("outr "..amount.." "..what, rf_debug) end
end

local function inpot(what, amount, pot)

  while amount > 50 do
    sendc("inpot 50 "..what.." in "..pot, rf_debug)
    amount = amount - 50
  end

  if amount == 1 then
    sendc("inpot "..what.." in "..pot, rf_debug)
  else
    sendc("inpot "..amount.. " "..what.." in "..pot, rf_debug)
  end
end

function rf_fillpot(potion, fills, pot)
  assert(potion and fills, "rf_fillpot: need to supply both what to brew and what amount to brew")

  -- 1 set of ingredients = 1 fill
  assert(concoctions[potion], "rf_fillpot: don't know about such a potion")
  for item, amount in pairs(concoctions[potion]) do
    outr(item, amount * fills)
    inpot(item, amount * fills, pot or conf.potid)
  end
end

function rf_boilpot(pot)
  local pot = pot or conf.potid

  rf_wait_to_boil = tempTimer(getNetworkLatency()+1, function ()
    if not svo.defc.selfishness then
      sendc("drop "..pot, rf_debug)
      sendc("boil "..pot.." for "..tostring(rf_refilling.currentorder), rf_debug)
    else
      sendc("generosity", rf_debug)
      rf_temptrigger = tempExactMatchTrigger("You have recovered equilibrium.", "killTrigger(svo.rf_temptrigger); send('drop "..pot.."', svo.rf_debug); send('boil "..pot.." for "..tostring(rf_refilling.currentorder).."', svo.rf_debug)")
    end
  end)
end

function rf_magichappened()
  if not rf_refilling then return end

  svo.doadd(function()
    sendc("take "..conf.potid, rf_debug)

    if rf_refilling.currentorderdata then
      for i = 1, rf_refilling.currentorderdata.arty do
        rf_fillarty()
      end

      for i = 1, (rf_refilling.currentorderdata.normal - rf_refilling.currentorderdata.arty) do
        rf_fillnext()
      end
    end

    echo'\n' rf_nextpotion()
  end)
end

function rf_fillnext()
  if not rf_refilling then return end

  sendc("fill emptyvial from "..conf.potid.." "..(svo.rf_transrefiller and 4 or 5).." times", rf_debug)
end

function rf_fillarty()
  if not rf_refilling then return end

  if not svo.rf_arties[1] then
    missing_arty = (missing_arty or 0) + 1
    prompttrigger("warn of missing arties", function()
      echof("You're missing %s artefact vials that were needed in the order, fyi.", missing_arty)
      missing_arty = nil
    end)
    return
  end

  sendc("fill "..table.remove(svo.rf_arties).." from "..conf.potid.." "..(svo.rf_transrefiller and 2 or 3).." times", rf_debug)
end

function rf_cancel()
  rf_refilling = nil
  undoall()
  echof("Cancelled refilling.")
end

function rf_refill(what)
  local what = what:split(",")
  local needarties

  rf_refilling = { p = {}, currentorder = false, currentorderdata = false}
  for i = 1, #what do
    what[i] = what[i]:trim()
    local amount, potion
    if what[i]:find("^(%d+) (%w+)") then
      amount, potion = what[i]:match("^(%d+) (%w+)")
    elseif what[i]:find("^(%w+)") then
      amount, potion = 1, what[i]:match("^(%w+)")
    end

    if not concoctions[potion] then
      echof("Don't know the ingredients for a '%s' potion :|", tostring(potion))
    else
      rf_refilling.p[potion] = {normal = tonumber(amount)}
      rf_refilling.p[potion].arty = tonumber(what[i]:match("(%d+) arty$") or 0)

      if rf_refilling.p[potion].arty > 0 then
        needarties = true
      end

      if rf_refilling.p[potion].arty > rf_refilling.p[potion].normal then
        echof("You can't have only %s refills of %s, and %s of them into artefact vials... going to assume you wanted %s %s refills total.", rf_refilling.p[potion].normal, potion, rf_refilling.p[potion].arty, rf_refilling.p[potion].arty, potion)
        rf_refilling.p[potion].normal = rf_refilling.p[potion].arty
      end
    end
  end

  if not next(rf_refilling.p) then
    rf_refilling = nil
    echof("Don't have anything to refill, then :/")
    return
  end

  rf_previousorder = deepcopy(rf_refilling.p)
  if not needarties then rf_nextpotion() else
    echof("Looking for the artefact vials...")
    sendc("config pagelength 250", rf_debug)
    sendc("ii artefact", rf_debug)
    sendc("config pagelength "..(conf.pagelength >= 20 and conf.pagelength or 20), rf_debug)
  end
end

-- to be called only when we need to do the next potion
function rf_nextpotion()
  rf_refilling.currentorder = next(rf_refilling.p)
  rf_refilling.currentorderdata = rf_refilling.p[rf_refilling.currentorder]
  if not rf_refilling.currentorder then
    rf_refilling = nil
    svo.echof("Done refilling!")
    raiseEvent("svo done refilling")
  else
    svo.echof("Going to work on refilling %s.", tostring(rf_refilling.currentorder))
    rf_fillpot(rf_refilling.currentorder,
      -- refill 5 health 2 arty means 3 normal + 2 arty!
      (rf_refilling.p[rf_refilling.currentorder].normal - rf_refilling.p[rf_refilling.currentorder].arty) * (svo.rf_transrefiller and 4 or 5) +
      rf_refilling.p[rf_refilling.currentorder].arty * 2)
    rf_boilpot()

    -- clear the fill so next time rf_nextpotion() is called, it's fine
    rf_refilling.p[rf_refilling.currentorder] = nil
  end
end

function rf_undopot(potion, fills, pot)
  assert(potion and fills, "rf_undopot: need to supply potion and how many fills went in")

  assert(concoctions[potion], "rf_undopot: don't know about such a potion")
  for item, amount in pairs(concoctions[potion]) do
    doadd("get "..amount * fills.." "..item.." from "..(pot or conf.potid))
  end
  doadd("get "..(pot or conf.potid))
  doadd("refill next potion")
end

function rf_missingstuff()
  disableTrigger("Missing ingredients"); tempTimer(2, function() enableTrigger("Missing ingredients") end)
  killTimer(rf_wait_to_boil)

  echo'\n' echof("Ack, looks like you're out of enough ingredients - going to get what we put into the pot back...")

    rf_undopot(rf_refilling.currentorder,
      (rf_refilling.currentorderdata.normal - rf_refilling.currentorderdata.arty) * (svo.rf_transrefiller and 4 or 5) +
      rf_refilling.currentorderdata.arty * 2)
end
