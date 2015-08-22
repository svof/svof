-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

es_version = "1.1"

-- stores vial ID and months left
es_vials = {}
-- stores type by key, and inside each, a potion table
--es_potions = {} -- intialized in setup
-- what are we currently capturing - so we know when to show the output
es_capturing = ""
es_disposecmd = ""

es_knownstuff = es_knownstuff or {}

signals.elistcaptured = luanotify.signal.new()

function es_capture()
  -- reset only what we're actually capturing
  if line:find("Venom", 1, true) then
    es_capturing = "venoms"

    for vial, _ in pairs(es_potions.venom) do
      es_potions.venom[vial] = {sips = 0, vials = 0, decays = 0}
    end

    -- wipe venoms only from es_potions
    local wipevenom = {}
    for vialid, vialdata in pairs(es_vials) do
      if es_potions.venom[vialdata.potion] then
        wipevenom[#wipevenom+1] = vialid
      end
    end
    for i = 1, #wipevenom do
      es_vials[wipevenom[i]] = nil
    end
  else
    es_capturing = "potions"

    for catn,cat in pairs(es_potions) do
      if catn ~= "venom" then
        for vial, _ in pairs(cat) do
          cat[vial] = {sips = 0, vials = 0, decays = 0}
        end
      end
    end

    -- wipe non-venoms only from es_potions
    local wipevial = {}
    for vialid, vialdata in pairs(es_vials) do
      if not es_potions.venom[vialdata.potion] then
        wipevial[#wipevial+1] = vialid
      end
    end
    for i = 1, #wipevial do
      es_vials[wipevial[i]] = nil
    end
  end
end

config.setoption("elist",
{
  type = "custom",
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg("gold")
    echoLink("es:", "", "svo Elist Sorter", true)
    -- change desired amounts; considering vials about to decay at 5 or less months
    fg("a_cyan") echoLink(" set vial amounts", "svo.config.set'elist'", "Click to change the minimum amounts of vials you'd like to have", true)
    fg(defaultcolour) echo("; considering vials about to decay at")
    fg("a_cyan") echoLink(" "..(conf.decaytime or '?'), "printCmdLine'vconfig decaytime '", "Click to change the amount of months at which a vial will be considered for throwing away", true)
    fg(defaultcolour)
    echo(" month"..(conf.decaytime == 1 and '' or 's')..".\n")

  end,
  onmenu = function ()
    -- sort into categories
    local t = {}
    for k,v in pairs(es_categories) do t[es_categories[k] or "unknown"] = t[es_categories[k] or "unknown"] or {}; t[es_categories[k] or "unknown"][#t[es_categories[k] or "unknown"]+1] = k end

    echof("Set the desired amount for each potion by clicking on the number:")
    for catn, catt in pairs(t) do
      echof("%s%s:", catn:title():sub(1, -2), (catn:sub(-1) == "y" and "ies" or catn:sub(-1).."s"))

      for _, potion in pairs(catt) do
        local amount = (es_knownstuff[potion] or 0)
        echo(string.format("  %30s ", potion))
        fg("blue")
        echoLink(" "..amount.." ", 'printCmdLine"vconfig setpotion '..(es_shortnamesr[potion] and es_shortnamesr[potion] or "unknown").. ' '..amount..'"', "Change how many vials of "..potion.." you'd like to have", true)
        resetFormat()
        echo"\n"
      end
    end
  end
})

conf.decaytime = conf.decaytime or 3
config.setoption("decaytime",
{
  type = "number",
  vconfig2string = true,
  onset = function () echof("Will consider vials available for disposal when they decay time is at or less than %d months.", conf.decaytime) end,
  onshow = function (defaultcolour)
    fg("gold")
    echoLink("es:", "", "svo Elist Sorter", true)

    -- obfuscated vials: store vials at less than %d sips into %container
    fg(defaultcolour) echo(" obfuscated vials: store at less than")
    fg("a_cyan") echoLink(" "..(conf.obfsips or '?'), "printCmdLine'vconfig obfsips '", "Click to change the # of sips below which obfuscated vials will be stored in a container", true)
    fg(defaultcolour)
    echo(" sip"..(conf.obfuscated == 1 and '' or 's').." into ")
    fg("a_cyan") echoLink((conf.obfcontainer or '?'), "printCmdLine'vconfig obfcontainer '", "Click to change container into which obfuscated vials will be stored", true)
    echo(".\n")
  end
})

conf.obfsips = conf.obfsips or 20
config.setoption("obfsips",
{
  type = "number",
  onset = function () echof("Will put obfuscated vials away into %s when they're at %d or below sips.", tostring(conf.obfcontainer), conf.obfsips) end
})


conf.obfcontainer = conf.obfcontainer or "pack"
config.setoption("obfcontainer",
{
  type = "string",
  onset = function () echof("Will put obfuscated vials away into %s.", tostring(conf.obfcontainer)) end
})

config.setoption("setpotion",
{
  type = "string",
  onset = function()
    if not conf.setpotion:find("^.+ %d+$") then echof("What amount do you want to set?") return end

    local potion, amount = conf.setpotion:match("^(.+) (%d+)$")
    amount = tonumber(amount)
    if es_shortnames[potion] then
      es_knownstuff[es_shortnames[potion]] = amount
      echof("Made a note that we'd like to have a minimum %s of %s.", amount, potion)
      return
    elseif not es_knownstuff[potion] then
      echof("I haven't seen any potions called '%s' yet...", potion)
    else
      es_knownstuff[potion] = amount
      echof("Made a note that we'd like to have a minimum %s of %s.", amount, potion)
      return
    end
  end
})

function es_appendrequest(whatfor)
  local t = {}
  for catn, catt in pairs(es_potions) do
    for potn, pott in pairs(catt) do
      if ((whatfor ~= "venoms" and not potn:find("the venom", 1, true)) or (whatfor == "venoms" and potn:find("the venom", 1, true))) and es_knownstuff[potn] and pott.vials < es_knownstuff[potn] then
        t[#t+1] = (es_knownstuff[potn] - pott.vials) .. " ".. (es_shortnamesr[potn] and es_shortnamesr[potn] or potn)
      end
    end
  end

  if #t == 0 then echof("I don't think you're short on anything!") return
  else appendCmdLine(" I'd like "..concatand(t)) end
end

function es_refillfromkeg()
  local t = {}
  for catn, catt in pairs(es_potions) do
    for potn, pott in pairs(catt) do
      if es_knownstuff[potn] and pott.vials < es_knownstuff[potn] and (es_shortnamesr[potn] and es_shortnamesr[potn] or potn) ~= "empty" then
        for i = 1, es_knownstuff[potn] - pott.vials do
          t[#t+1] = string.format("refill empty from %s", (es_shortnamesr[potn] and es_shortnamesr[potn] or potn))
        end
      end
    end
  end

  if #t == 0 then echof("I don't think you're short on anything!") return
  else
    sendc(unpack(t))
  end
end

function es_captured(vlist)
  tempTimer(0, function()
    local missing = 0
    local decaying

    local function checkdecays(pott)
      if pott.decays == 0 then return ""
      else decaying = true return (pott.decays.." decaying soon") end
    end

    for catn, catt in pairs(es_potions) do
      echof("%s%s:", catn:title():sub(1, -2), (catn:sub(-1) == "y" and "ies" or catn:sub(-1).."s"))

      for potn, pott in pairs(catt) do
        -- don't show vials that we have 0 of and want 0 of
        if not (pott.vials == 0 and (not es_knownstuff[potn] or (es_knownstuff[potn] and es_knownstuff[potn] == 0))) then
          if es_knownstuff[potn] and pott.vials < es_knownstuff[potn] then
            missing = missing + es_knownstuff[potn] - pott.vials
            echon("%3d %-35s%7s  %10s", pott.vials, potn..' ('..pott.sips..'s)', (es_knownstuff[potn] - pott.vials .. " short"), checkdecays(pott))
          else
            echon("%3d %-35s%7s  %10s", pott.vials, potn..' ('..pott.sips..'s)', "", checkdecays(pott))
          end
        end
      end
    end
    echo"  "; dechoLink("<0,0,250>("..getDefaultColor().."change desired amounts<0,0,250>)", "svo.config.set('elist')", "Show a menu to change how much of what would you like to have", true) echo"\n"
    if decaying then echo"  "; dechoLink("<0,0,250>("..getDefaultColor().."dispose of decays<0,0,250>)", "printCmdLine'dispose of decays by: give vial to humgii'", "Dispose of vials (pouring them into other vials if possible) with a custom command.\nMake sure to include the word 'vial' in the command", true) echo"\n" end
    if missing > 0 then
      echo"  "
      dechoLink("<0,0,250>("..getDefaultColor().."append refill request, need "..missing.." refills<0,0,250>)", "svo.es_appendrequest('"..es_capturing.."')", "Insert how many refills of "..es_capturing.." would you like into the command line.\nYou should pre-type whenever you want to say or tell this to anyone, and then click", true)
      echo"\n  "
      dechoLink("<0,0,250>("..getDefaultColor().."refill from tuns, need "..missing.." refills<0,0,250>)", "svo.es_refillfromkeg()", "Click here to refill all necessary things from shop tuns", true)
      echo"\n"
    end
    showprompt()
    debugf("raising elistcaptured with: %s", tostring(vlist))
    signals.elistcaptured:emit(vlist)
  end)
end

function es_dodisposing(vlist)
  -- check vlist and then elist - ignore if its vlist, only act on elist
  debugf("es_dodisposing: %s", tostring(vlist))
  if vlist then return end

  local function emptyvial(id)
    if es_vials[id].sips == 0 then echof("%d is already empty.", id) return end
    echof("Emptying vial%d with %s.", id, es_vials[id].potion)

    -- one pass is enough! If we don't completely dispose of it, then that's alright
    for otherid, t in pairs(es_vials) do
      if otherid ~= id and (t.potion == es_vials[id].potion or t.potion == "empty") and t.sips < (type(t.months) == "number" and 200 or 240) and
        (type(t.months) ~= "number" or t.months > conf.decaytime) then

        local deltacapacity = (type(t.months) == "number" and 200 or 240) - t.sips -- this is how much we can fill it up by
        echof("Can fill vial%d with %d more sips.", otherid, deltacapacity)

        local fillingwith = (es_vials[id].sips < deltacapacity and es_vials[id].sips or deltacapacity)
        echof("Filling vial%d with %d sips.", otherid, fillingwith)

        sendc(string.format("pour %d into %d", id, otherid))

        t.sips = t.sips + fillingwith
        echof("Poured %s into vial%s, which is now at %d sips.", es_vials[id].potion, tostring(otherid), tostring(t.sips))

        es_vials[id].sips = es_vials[id].sips - fillingwith
        echof("Decayable vial%s is now at %d sips.", id, es_vials[id].sips)

        if t.potion == "empty" then t.potion = es_vials[id].potion; echof("Poured into empty now has %s potion", tostring(t.potion)) end
        if es_vials[id].sips <= 0 then echof("Vial %s fully emptied.\n--", tostring(id)) return end
      end
    end
    echof("Vial %d with '%s' wasn't fully emptied, no space to pour it into now.\n--", id, es_vials[id].potion)
  end

  echo'\n'
  local haddecays
  for id, t in pairs(es_vials) do
    if type(t.months) == "number" and t.months <= conf.decaytime then
      emptyvial(id)
      sendc(es_disposecmd:gsub("vial", id), false)
      haddecays = true
    end
  end

  if haddecays then
    echof("Disposing of vials which have %d or less months on them...", conf.decaytime)
  else
    echof("Don't have any vials which have under %d months :)", conf.decaytime)
  end
  showprompt()

  signals.elistcaptured:disconnect(es_dodisposing)
end

function es_dispose(cmd)
  if not cmd:find("vial", 1, true) then echof("Please include the word 'vial' in the command. Thanks!") return end
  if not next(es_vials) then echof("Don't know of any vials you have - check 'elist' please.") return end

  signals.elistcaptured:connect(es_dodisposing)
  es_disposecmd = cmd
  -- refresh our vials data, in case new vials were bought
  send("config pagelength 250", false)
  send("vlist", false)
  send("elist", false)
end

signals.saveconfig:connect(function () table.save(getMudletHomeDir() .. "/svo/config/es_knownstuff", es_knownstuff) end)
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/es_knownstuff"

  if lfs.attributes(conf_path) then
    table.load(conf_path, es_knownstuff)
  end

  if lfs.attributes(conf_path) then
    local ok = pcall(table.load, conf_path, es_knownstuff)
    if not ok then
      os.remove(conf_path)
      tempTimer(10, function()
        echof("Your elist sorter save file file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to re-set all of the elist options again, though. (%q)", msg)
      end)
    end
  end
end)

-- remember our vial statuses if we have
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/es_potions"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    update(es_potions, t)
  end

  -- erase tonics and balms as those are gone
  es_potions.tonic = nil
  es_potions.balm = nil
end)

signals.saveconfig:connect(function () table.save(getMudletHomeDir() .. "/svo/config/es_potions", es_potions) end)

echof("Loaded svo Elist Sorter, version %s.", tostring(es_version))

