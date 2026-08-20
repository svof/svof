-- Svof (c) 2011-2020 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.loader.refiller = function()

local conf = svo.conf

svo.rf_debug = false
-- format: {p = {potion = #, currentorder = ""}
-- this stores the total order that we need to do
svo.rf_refilling = svo.rf_refilling or false

-- format: 'potion'
-- this stores the current potion that we're doing of the whole order

-- need a variable to handle either remedies or toxicology transcendence
svo.rf_currenttrans = svo.rf_currenttrans or false

-- a variable to handle whether the user wants to brew or compound
svo.rf_refillaction = svo.rf_refillaction or false

conf.potid = conf.potid or 'pot'
svo.config.setoption('potid', {
  type = 'string',
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("refiller: ", "", "svo Refiller", true)
    fg(defaultcolour) echo("Pot/Alembic to use is ")
    fg('a_cyan') echoLink((conf.potid or 'pot'), "printCmdLine 'vconfig potid '", "Click to set the pot/alembic ID to use for brewing/compounding in", true)
    fg(defaultcolour) echo("; storing your containers in")
    fg('a_cyan') echoLink(" "..(conf.packid or 'pack'), "printCmdLine'vconfig packid '", "Click to set the pack ID to stuff your vials into when you do 'putvials'", true)
    fg(defaultcolour) echo(".\n")
  end,
  onset = function ()
    svo.echof("Okay, will brew/compound in the %s item.", conf.potid)
  end
})

conf.containerid = conf.containerid or 'emptyvial'
svo.config.setoption('containerid', {
  type = 'string',
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("refiller: ", "", "svo Refiller", true)
    fg(defaultcolour) echo("Container to fill is ")
    fg('a_cyan') echoLink((conf.containerid or 'emptyvial'), "printCmdLine 'vconfig containerid '", "Click to set the container ID that you want to fill after finished brewing", true)
    fg(defaultcolour) echo(".\n")
  end,
  onset = function ()
    svo.echof("Okay, will pour liquids in %s when finished.", conf.containerid)
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
  epidermal = true,
  immunity = true,
  mana = true,
  health = true,
  venom = true,
  frost = true,
  levitation = true,
  mending = true,
  mass = true,
  speed = true,
  restoration = true,
  caloric = true,
}

local toxins = {
  xentio = true,
  oleander = true,
  eurypteria = true,
  kalmia = true,
  digitalis = true,
  darkshade = true,
  curare = true,
  epteth = true,
  prefarar = true,
  monkshood = true,
  euphorbia = true,
  colocasia = true,
  oculus = true,
  vernalius = true,
  epseth = true,
  larkspur = true,
  slike = true,
  voyria = true,
  delphinium = true,
  vardrax = true,
  loki = true,
  aconite = true,
  selarnia = true,
  gecko = true
}

function svo.rf_brewpot()
  local max = (svo.rf_currenttrans and 12 or 10)
  local pot = conf.potid
  if pot == "pot" and svo.rf_refillaction == "compound" then pot = "alembic" end
  if svo.rf_refilling.currentorder == 'restoration' and svo.rf_refillaction == 'brew' then
    local gold = 40 * math.min(svo.rf_refilling.currentorderdata,max) * (svo.rf_currenttrans and 4 or 5)
    svo.sendc("get "..gold.." money from "..conf.packid, svo.rf_debug)
  end
  svo.sendc(svo.rf_refillaction.. " ".. (svo.rf_currenttrans and 4 or 5) * math.min(svo.rf_refilling.currentorderdata,max) .. " " ..tostring(svo.rf_refilling.currentorder) .. " in "..pot, svo.rf_debug)
end

function svo.rf_magichappened()
  if not svo.rf_refilling then return end
  svo.doadd(function()
    local max = (svo.rf_currenttrans and 12 or 10)
    if svo.rf_refilling.currentorderdata then
      for _ = 1, math.min(svo.rf_refilling.currentorderdata, max) do
        svo.rf_fillnext()
      end
      if svo.rf_refilling.currentorderdata <= max then
        svo.rf_refilling.currentorderdata = nil
      end
    end
    echo'\n' svo.rf_nextpotion()
  end)
end

function svo.rf_fillnext()
  local pot = conf.potid
  if pot == "pot" and svo.rf_refillaction == "compound" then pot = "alembic" end
  if not svo.rf_refilling then return end
  svo.sendc("pour ".. pot .. " in " .. conf.containerid, svo.rf_debug)
end

function svo.rf_cancel()
  svo.rf_refilling = nil
  svo.undoall()
  --no need for failsafe triggers when not using refiller
  disableTrigger("There's something wrong there")
  
  echo'\n' svo.echof("Cancelled refilling.")
end

function svo.rf_refill(action,what)
  svo.rf_refillaction = action
  what = what:split(",")
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
      svo.echof("Don't know what a '%s' is :|", tostring(potion))
    else
      svo.rf_refilling.p[potion] = tonumber(amount)
    end
  end
  if not next(svo.rf_refilling.p) then
    svo.rf_refilling = nil
    svo.echof("Don't have anything to refill, then :/")
    return
  end
  --enables failsafe triggers
  enableTrigger("There's something wrong there")
  
  svo.rf_previousorder = svo.deepcopy(svo.rf_refilling.p)
  svo.rf_nextpotion()
end


-- to be called only when we need to do the next potion
function svo.rf_nextpotion()
  -- if we're still in the process of making something
  local max
  if svo.rf_refilling.p[svo.rf_refilling.currentorder] then
  max = (svo.rf_currenttrans and 12 or 10)
    -- delete the max amount we're able to make per brewpot(), we already made it
    svo.rf_refilling.currentorderdata = svo.rf_refilling.currentorderdata - max
  end
  if not svo.rf_refilling.currentorderdata or svo.rf_refilling.currentorderdata <= 0 then
    svo.rf_refilling.currentorder = next(svo.rf_refilling.p)
    svo.rf_refilling.currentorderdata = svo.rf_refilling.p[svo.rf_refilling.currentorder]
  end
  if not svo.rf_refilling.currentorder then
    svo.rf_refilling = nil
    --disables failsafe triggers as they are no longer needed when we finish everything
    disableTrigger("There's something wrong there")
    
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
    svo.rf_brewpot()
    -- if we have made all of the current item, then clear the fill so next time rf_nextpotion() is called, it is fine
    max = (svo.rf_currenttrans and 12 or 10)
    if svo.rf_refilling.currentorderdata <= max then
      svo.rf_refilling.p[svo.rf_refilling.currentorder] = nil
      svo.rf_refilling.currentorder = nil
    end
  end
end

function svo.rf_missingstuff()
  disableTrigger("Missing ingredients"); tempTimer(2, function() enableTrigger("Missing ingredients") end)

  echo'\n' svo.echof("Ack, looks like you're out of enough ingredients. :(")
  svo.rf_cancel()
end
end
if svo.systemloaded then svo.loader.refiller() end