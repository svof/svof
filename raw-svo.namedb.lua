-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

pl.dir.makepath(getMudletHomeDir() .. "/svo/namedb")

-- load the highlightignore list
signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/highlightignore"

  if lfs.attributes(conf_path) then
    local t = {}
    local ok, msg = pcall(table.load, conf_path, t)
    if ok then
	    me.highlightignore = me.highlightignore or {} -- make sure it's initialized
	    update(me.highlightignore, t)
	else
		os.remove(conf_path)
		tempTimer(10, function()
		  echof("Your NameDB highlights ignored file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to re-do all the names to ignore highlighting, though. (%q)", msg)
		end)
	end
  end
end)
signals.saveconfig:connect(function () me.highlightignore = me.highlightignore or {}; svo.tablesave(getMudletHomeDir() .. "/svo/config/highlightignore", me.highlightignore) end)


-- save the ndb.conf.citypolitics list

signals.saveconfig:connect(function () ndb.conf.citypolitics = ndb.conf.citypolitics or {}; svo.tablesave(getMudletHomeDir() .. "/svo/namedb/citypolitics", ndb.conf.citypolitics) end)

signals.saveconfig:connect(function ()
	-- this can error out if the connection is closed
  pcall(function() db.__conn["namedb"]:execute("VACUUM") end)
end)

--ndb.API
function ndb.ismhaldorian(name)
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.city, "Mhaldor"), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.iscyrenian(name)
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.city, "Cyrene"), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.isshallamese(name)
  return #(db:fetch(ndb.db.people, {db:OR(db:eq(ndb.db.people.city, "Shallam"), db:eq(ndb.db.people.city, "Targossas")), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.istargossian(name)
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.city, "Targossas"), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.iseleusian(name)
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.city, "Eleusis"), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.isashtani(name)
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.city, "Ashtan"), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.ishashani(name)
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.city, "Hashan"), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.isclass(name, class)
  name, class = name:title(), class:lower()
  return #(db:fetch(ndb.db.people, {db:eq(ndb.db.people.class, class), db:eq(ndb.db.people.name, name)})) ~= 0
end

function ndb.getclass(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return r[1].class:lower()
end

function ndb.setclass(name, class)
  class = class:lower()
  svo.assert(ndb.isvalidclass(class), "ndb.setclass: invalid class given")

  ndb.fixed_set(ndb.db.people.class, class, db:eq(ndb.db.people.name, name))
end

function ndb.getcity(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return r[1].city
end

function ndb.getnotes(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return r[1].notes
end

function ndb.getxprank(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return r[1].xp_rank
end

function ndb.ismark(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  if r[1].mark == "" then return false
  else return r[1].mark end
end

function ndb.setmark(name, type)
  if type == false then type = "" end

  ndb.fixed_set(ndb.db.people.mark, type, db:eq(ndb.db.people.name, name))
end

function ndb.isinfamous(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  if r[1].infamous == "" then return false
  else return r[1].infamous end
end

function ndb.setinfamous(name, infamy)
  ndb.fixed_set(ndb.db.people.infamous, infamy, db:eq(ndb.db.people.name, name))
end

function ndb.isdragon(name)
  svo.assert(name, "ndb.isdragon() requires a name")

  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return (r[1].dragon == 1 and true or false)
end

function ndb.getcityrank(name)
  svo.assert(name, "ndb.getcityrank() requires a name")

  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return ndb.valid.cityranks[r[1].city][r[1].city_rank]
end

function ndb.setdragon(name, status)
  status = svo.toboolean(status) and 1 or 0

  ndb.fixed_set(ndb.db.people.dragon, status, db:eq(ndb.db.people.name, name))
end

function ndb.isimmortal(name)
  name = name:title()
  local r = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))
  if not next(r) then return nil, "name not known" end

  return (r[1].immortal == 1 and true or false)
end

function ndb.exists(name)
  return #(db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))) ~= 0
end

function ndb.isperson(name)
  return #(db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))) ~= 0
end

-- returns true only if a certain enemy
function ndb.isenemy(name)
  local p = ndb.getname(name)
  if not p then return false end

  local city = p.city

  -- -1 autodetected, 1 enemy, 2 ally
  if p.iff == 1 or
       (p.iff ~= 2 and
         ((city and city ~= "" and ndb.conf.citypolitics[city] == "enemy") or
         (p.cityenemy == 1 or p.orderenemy == 1 or p.houseenemy == 1))) then
    return true else return false
  end
end

-- returns true only if someone is an enemy via iff or is a city enemy. They could be a house enemy, and not be considered an enemy by this
function ndb.iscityenemy(name)
  local p = ndb.getname(name)
  if not p then return false end

  local city = p.city

  -- -1 autodetected, 1 enemy, 2 ally
  if p.iff == 1 or
       (p.iff ~= 2 and
         ((city and city ~= "" and ndb.conf.citypolitics[city] == "enemy") or
         (p.cityenemy == 1))) then
    return true else return false
  end
end

-- given a title, returns all info about a person
function ndb.getnamebytitle (title)
  return db:fetch(ndb.db.people, db:in_(ndb.db.people.name, string.split(title, " ")))
end

-- given a line, returns the first name it finds, if any
function ndb.findname(line)
  for w in string.gmatch(line, "(%u%l+)") do
    if #w >= 3 then
      if ndb.isperson(w) then return w end
    end
  end
end

-- given a line, returns all names found on it
function ndb.findnames(line)
  local l = {}
  for w in string.gmatch(line, "(%u%l+)") do
    if #w >= 3 then
      if ndb.isperson(w) then l[#l+1] = w end
    end
  end

  if l[1] then return l end
end

-- given a name, returns all info about a person
function ndb.getname (name)
  return db:fetch(ndb.db.people, db:eq(ndb.db.people.name, string.title(name)))[1]
end

local singular_city = {
  [""] = "Rogue",
  Mhaldor = "Mhaldorian",
  Ashtan = "Ashtani",
  Hashan = "Hashani",
  Eleusis = "Eleusian",
  Shallam = "Shallamese",
  Targossas = "Targossian",
  Cyrene = "Cyrenian"
}

local plural_city = {
  [""] = "Rogues",
  Mhaldor = "Mhaldorians",
  Ashtan = "Ashtani",
  Hashan = "Hashani",
  Eleusis = "Eleusians",
  Shallam = "Shallamese",
  Targossas = "Targossians",
  Cyrene = "Cyrenians"
}

local singular_class = {}

local plural_class = {
  Apostate    = "Apostates",
  Bard        = "Bards",
  Blademaster = "Blademasters",
  Dragon      = "Dragons",
  Druid       = "Druids",
  Infernal    = "Infernals",
  Jester      = "Jesters",
  Magi        = "Magi",
  Monk        = "Monks",
  Occultist   = "Occultists",
  Paladin     = "Paladins",
  Priest      = "Priests",
  Runewarden  = "Runewardens",
  Sentinel    = "Sentinels",
  Serpent     = "Serpents",
  Shaman      = "Shamans",
  Sylvan      = "Sylvans",
}

function ndb.getpluralclass(class, count)
  if count <= 1 then
    return class
  else
    return plural_class[class]
  end
end

function ndb.getpluralcity(city, count)
  if count <= 1 then
    return singular_city[city]
  else
    return plural_city[city]
  end
end

local function getcolor(name)
  local person = ndb.getname(name)

  if not person then return "" end -- in case the person doesn't exist

  local city, conf, color = person.city, svo.conf

  -- order of priority: watchfor > divine > city > order > house > citizens.
  if (city == "" or city == "rogue") then city = "" else city = city:lower() end -- known rogues are returned as ""

  -- color first
  if conf.highlightwatchfor and svo.me.watchfor[name] then
    color     = conf.watchforcolor or "a_darkwhite"

  elseif conf.highlightdivine and person.immortal == 1 then
    color     = conf.divinecolor or "a_darkwhite"

  elseif conf.highlightcity and person.cityenemy == 1 then
    color     = conf.citycolor or "a_darkwhite"

  elseif conf.highlightorder and person.orderenemy == 1 then
    color     = conf.ordercolor or "a_darkwhite"

  elseif conf.highlighthouse and person.houseenemy == 1 then
    color     = conf.housecolor or "a_darkwhite"

  elseif order and conf["highlight"..order] then
    color     = conf[order.."color"] or "a_darkwhite"

  elseif city == "" and conf.highlightrogues then
    color     = conf.roguescolor or "a_darkwhite"

  elseif city ~= "" and conf["highlight"..city] then
    color     = conf[city.."color"] or "a_darkwhite"
  end

  return color
end

function ndb.getcolor(name)
  svo.assert(type(name) == "string", "ndb.getcolor: name to get a color of is required")

  local color = getcolor(name)

  return ((color and color ~= "") and '<'..color..'>' or "")
end

function ndb.getcolorn(name)
  svo.assert(type(name) == "string", "ndb.getcolorn: name to get a color of is required")

  local color = getcolor(name)

  return ((color and color ~= "") and ('<'..color..'>'..name..'<reset>') or name)
end

function ndb.getcolorp(name)
  svo.assert(type(name) == "string", "ndb.getcolorp: name to get a color of is required")

  local color = getcolor(name)

  return color
end

for _, format in ipairs{"bold", "underline", "italicize"} do
  ndb["should"..format] = function(name)
    svo.assert(type(name) == "string", "ndb.should"..format..": name to get a color of is required")

    local person = ndb.getname(name)

    if not person then return false end -- in case the person doesn't exist

    local city, conf, color = person.city, svo.conf

    return (conf[format.."watchfor"] and svo.me.watchfor[name])    or
           (conf[format.."city"] and person.cityenemy == 1)        or
           (conf[format.."order"] and person.orderenemy == 1)      or
           (conf[format.."house"] and person.houseenemy == 1)      or
           (conf[format.."divine"] and person.immortal == 1)       or
           (order and conf[format..order])                         or
           ((city == "" or city == "rogue") and conf[format.."rogues"]) or
           (city and conf[format..city])                           or false
  end
end

function ndb.addname(name)
  local temp_name_list = {}

  if type(name) == "table" then
    for i = 1, #name do
      temp_name_list[#temp_name_list+1] = {name = name[i]:title()}
    end
  else
    temp_name_list = {{name = name:title()}}
  end

  db:merge_unique(ndb.db.people, temp_name_list)

  raiseEvent("NameDB got new data")
end

function ndb.setiff(name, status)
  local name = name:lower():title()

  local category = "iff"
  local towhat

  -- -1 autodetected, 1 enemy, 2 ally
  local status = status:lower()
  if status == "enemy" then
    towhat = 1
  elseif status == "ally" then
    towhat = 2
  else
    towhat = -1
  end

  local temp_name_list = {{
    name = name,
    [category] = towhat
  }}

  db:merge_unique(ndb.db.people, temp_name_list)
end

-- ndb.support

function ndb.tablemerge(t, other)
   for other_key, other_items in pairs(other) do
      if not t[other_key] then
         t[other_key] = other_items
      else
         local group = t[other_key]
         for item_key, item_value in pairs(other_items) do
            group[item_key] = item_value
         end
      end
   end
   return t
end

-- given a string and a table of possible answers, returns the first possible answer, if any
function ndb.findfromtable(input, valid)
  local sfind = string.find

  for i = 1, #valid do
    if sfind(input, valid[i], 1, true) then return valid[i] end
  end
end

function ndb.showinfamous()
  local infamous = {}
  for _, person in pairs(db:fetch(ndb.db.people, db:gte(ndb.db.people.infamous, 1))) do
    local infamy = ndb.isinfamous(person.name)

    if infamy and infamy >= 1 then
      infamous[infamy] = infamous[infamy] or {}
      infamous[infamy][#infamous[infamy]+1] = person.name
    end
  end

  svo.echof("Infamous names known in NameDB:")
  if not next(infamous) then svo.echof("(none found)") end
  for cat, people in pairs(infamous) do
    table.sort(people)
    echo(string.format("  %s: %s\n", ndb.valid.shortinfamous[cat], svo.concatand(people)))
  end
  showprompt()
end

function ndb.showhelp(entry)
  svo.echof("<0,250,0>"..ndb.help[entry].term.."<47,79,79>: "..svo.getDefaultColor()..table.concat(ndb.help[entry].definition, "\n"))
  svo.showprompt() echo'\n'
end

function ndb.honors(name, type)
  if ndb.honorsid then svo.echof("ndb.honors() for %s called, when already honours'ing %s - not going to do this.", name:title(), ndb.honorsname:title()) return end
  name = string.title(name)

  enableTrigger("Honors")

  if ndb.honorsid then killTimer(ndb.honorsid) end
  ndb.honorsid = tempTimer(2+getNetworkLatency(), function()
    disableTrigger("Honors")
    svo.echof("Honors on %s didn't happen - re-checking...", name)
    ndb.honorsid, ndb.gaghonours = nil, nil
    ndb.honors(name, type)
  end)

  ndb.honorsname = name
  send("honorsb " .. name, false) -- needs to full so it sees the clan listing

  if type == "quiet" then ndb.gaghonours = true end
end

function ndb.cancelhonors(quietly)
  ndb.manualcheck = nil
  ndb.checkingqwi = nil

  if (ndb.honorslist and next(ndb.honorslist)) or ndb.honorsid then
    ndb.honorslist = {}
    if ndb.honorsid then killTimer(ndb.honorsid) disableTrigger("Honors") end; ndb.honorsid = nil
    if not quietly then svo.echof("Cancelled honors-checking people.") end
  else
    if not quietly then svo.echof("Not checking anyone atm already.") end
  end
  if not quietly then svo.showprompt() end

  ndb.hidehonorswindow()
end

function ndb.getrankincity(city, name)
  city, name = city:title(), name:title()

  if ndb.valid.cityranks[city] then return ndb.valid.cityranks[city][name] end
end

-- update all info that we should be able to glean from honors.
-- might: if it's at -1, then it's default known
-- rank: -1 default unknown, -2 unranked
function ndb.updatebyhonors()
  -- took might check off, as the website doesn't show it
  if not svo.conf.usehonors then return end -- Achaea disallowed use of website scraping, can only honors on a 2s eq

  local data = db:fetch(ndb.db.people, db:AND(db:not_eq(ndb.db.people.immortal, 1), db:eq(ndb.db.people.xp_rank, -1)))

  ndb.honorslist = (function ()
    local t = {}
    for i,j in ipairs(data) do
      -- sanity check for weird names
      if j.name:find("^%u%l+$") then t[j.name] = true
      else db:delete(ndb.db.people, db:eq(ndb.db.people.name, j.name)) end
    end return t end)()

    if svo.conf.paused or not next(ndb.honorslist) then return end

    if not svo.conf.autocheck and not ndb.manualcheck then
      if table.size(ndb.honorslist) > 1 then
        echo'\n'
        if table.size(ndb.honorslist) <= 10 then
          svo.echofn("Got new names (%s), use '", svo.oneconcat(ndb.honorslist))
          setFgColor(unpack(svo.getDefaultColorNums))
          setUnderline(true)
          echoLink("ndb honorsnew", 'ndb.manualcheck = true; ndb.updatebyhonors()', 'Click to do ndb honorsnew', true)
          setUnderline(false)
          echo("' to check them.\n")
        else
          svo.echofn("Got %d new names, use '", table.size(ndb.honorslist))
          setFgColor(unpack(svo.getDefaultColorNums))
          setUnderline(true)
          echoLink("ndb honorsnew", 'ndb.manualcheck = true; ndb.updatebyhonors()', 'Click to do ndb honorsnew', true)
          setUnderline(false)
          echo("' to check them.\n")
        end
      end

      return
    end

    -- don't show anymore - checking isn't so intrusive anymore
    -- if table.size(ndb.honorslist) <= 10 then
    --   echo'\n' svo.echof("Have new names (%s) - going to check them.", svo.oneconcat(ndb.honorslist))
    -- else
    --   echo'\n' svo.echof("Have %s new names - going to check them.", table.size(ndb.honorslist))
    -- end

  if not ndb.honorsid then ndb.honors_next() end
end

function ndb.doexport()
  if not ndb.exportdata.location then return nil, "no export location" end

  local alldata = db:fetch(ndb.db.people)

  if not alldata or not next(alldata) then svo.echof("Your NameDB is empty! Check 'qw', 'citizens' to start filling it up. There's nothing to export otherwise...") return end

  for i = 1, #alldata do
    local p = alldata[i]

    -- see if we need to prune the result first
    if not ndb.exportdata.people.all then
      alldata[i] = nil

    else
      -- prune fields we don't need
      for key,value in pairs(ndb.exportdata.fields) do
        if key ~= "name" and not value then p[key] = nil end
      end

      -- prune internal fields starting with underscores
      local removekeys = {}
      for key, _ in pairs(p) do
        if key:sub(1,1) == '_' then
          removekeys[#removekeys+1] = key
        end
      end

      for i = 1, #removekeys do p[removekeys[i]] = nil end
    end
  end

  -- build the final table that we'll svo.tablesave()
  local exportable = {
    meta = { author = gmcp.Char.Status.name, date = os.date("%A %d, %b '%y"), fields =  ndb.exportdata.fields },
    data = alldata
  }

  local location = string.format("%s/%s's namedb, %s", ndb.exportdata.location, gmcp.Char.Status.name,os.date("%A %d, %b '%y"))
  svo.tablesave(location, exportable)
  echo'\n' svo.echof("Data exported okay, it's in %s.", location)
end

-- reads selected files for fields available within it to import
function ndb.getimportfields()

  if not ndb.importdata.location or not io.exists(ndb.importdata.location) then ndb.importdata.location = nil; return end

  ndb.importdata.data = {}
  table.load(ndb.importdata.location, ndb.importdata.data)
  if not ndb.importdata.data then svo.echof("Couldn't read the file - maybe it's corrupted? Try another.") return end

  for k,v in pairs(ndb.importdata.data.meta.fields) do if ndb.schema.people[k] then ndb.importdata.fields[k] = true end end
end

function ndb.doimport()
  if not ndb.importdata.data then return nil, "no data loaded in ndb.importdata.data" end

  -- copy data over for importing with only the fields we need
  local temp_name_list = {}

  -- data.data as the original data is stored in .data of the new field that's imported.
  for i = 1, #ndb.importdata.data.data do
    local p = ndb.importdata.data.data[i]

    temp_name_list[#temp_name_list + 1] = {
      name = p.name,
    }

    for k,v in pairs(p) do
      if ndb.importdata.fields[k] then
        temp_name_list[#temp_name_list][k] = v
      end
    end
  end

  db:merge_unique(ndb.db.people, temp_name_list)
  svo.echof("Imported %d name%s okay.", #temp_name_list, (#temp_name_list == 1 and '' or 's'))

  local c = #(db:fetch(ndb.db.people, db:eq(ndb.db.people.city, "Shallam")))
  if c ~= 0 then
    ndb.fixed_set(ndb.db.people.city, "Targossas", db:eq(ndb.db.people.city, "Shallam"))
    svo.echof("Migrated "..c.." Shallamese to be called Targossians now.")
  end

  raiseEvent("NameDB got new data")
  ndb.importdata.data = nil
end

function ndb.loadhighlights()
  ndb.highlightIDs = ndb.highlightIDs or {}
  collectgarbage("stop")

  ndb.cleartriggers()

  if svo.conf.ndbpaused then return end

  local highlight, watchfor = ndb.singlehighlight, svo.me.watchfor

  local dbnames = db:fetch(ndb.db.people)

  for i = 1, #dbnames do
    highlight(dbnames[i].name,
      dbnames[i].city or "",
      dbnames[i].order or "",
      dbnames[i].cityenemy or 0,
      dbnames[i].orderenemy or 0,
      dbnames[i].houseenemy or 0,
      watchfor[dbnames[i].name],
      dbnames[i].immortal or 0
    )
  end

  collectgarbage()
end

function ndb.singlehighlight(name, city, order, cityenemy, orderenemy, houseenemy, watchfor, immortal)
  if ndb.highlightIDs and ndb.highlightIDs[name] then
    killTrigger(ndb.highlightIDs[name])
  end

  if name == svo.me.name or svo.me.highlightignore[name] or svo.conf.ndbpaused then return end

  local color, bold, underline, italicize
  local conf = svo.conf

  -- order of priority: watchfor > divine > city > order > house > citizens.

  city = city:lower()
  if order == "" then order = false else order = order:lower() end

  -- color first
  if conf.highlightwatchfor and watchfor then
    color     = conf.watchforcolor or "a_darkwhite"

  elseif conf.highlightdivine and immortal == 1 then
    color     = conf.divinecolor or "a_darkwhite"

  elseif conf.highlightcity and cityenemy == 1 then
    color     = conf.citycolor or "a_darkwhite"

  elseif conf.highlightorder and orderenemy == 1 then
    color     = conf.ordercolor or "a_darkwhite"

  elseif conf.highlighthouse and houseenemy == 1 then
    color     = conf.housecolor or "a_darkwhite"

  elseif order and conf["highlight"..order] then
    color     = conf[order.."color"] or "a_darkwhite"

  elseif (city == "" or city == "rogue") and conf.highlightrogues then
    color     = conf.roguescolor or "a_darkwhite"

  elseif city and conf["highlight"..city] then
    color     = conf[city.."color"] or "a_darkwhite"
  end

  -- rest of things
  bold      = (conf.boldwatchfor and watchfor)            or
                (conf.boldcity and cityenemy == 1)        or
                (conf.boldorder and orderenemy == 1)      or
                (conf.boldhouse and houseenemy == 1)      or
                (conf.bolddivine and immortal == 1)       or
                (order and conf["bold"..order])           or
                ((city == "" or city == "rogue") and conf.boldrogues) or
                (city and conf["bold"..city])

  underline = (conf.underlinewatchfor and watchfor)       or
                (conf.underlinecity and cityenemy == 1)   or
                (conf.underlineorder and orderenemy == 1) or
                (conf.underlinehouse and houseenemy == 1) or
                (conf.underlinedivine and immortal == 1)  or
                (order and conf["underline"..order])      or
                ((city == "" or city == "rogue") and conf.underlinerogues) or
                (city and conf["underline"..city])

  italicize = (conf.italicizewatchfor and watchfor)       or
                (conf.italicizecity and cityenemy == 1)   or
                (conf.italicizeorder and orderenemy == 1) or
                (conf.italicizehouse and houseenemy == 1) or
                (conf.italicizedivine and immortal == 1)  or
                (order and conf["italicize"..order])      or
                ((city == "" or city == "rogue") and conf.italicizerogues) or
                (city and conf["italicize"..city])

  if not (color or bold or underline or italicize) then return end

  ndb.highlightIDs = ndb.highlightIDs or {}
  ndb.highlightIDs[name] = tempTrigger(name, ([[ndb.highlight("%s", %s, %s, %s, %s)]]):format(name,
    (color     and '"'..color..'"' or "false"),
    (bold      and "true" or "false"),
    (underline and "true" or "false"),
    (italicize and "true" or "false")
  ))
end

function ndb.cleartriggers()
  if not ndb.highlightIDs or not next(ndb.highlightIDs) then return end

  local killTrigger = killTrigger
  for k,v in pairs(ndb.highlightIDs) do
    killTrigger(v)
  end

  ndb.highlightIDs = {}
end

function ndb.highlight(who, color, bold, underline, italicize)
  -- c counts the appearance of the substring of the word in the line, k counts the character position
  local c, k = 1, 1
  while k > 0 do
    k = line:find(who, k)
    if k == nil then return; end
    c = c + 1

    if k == line:find("%f[%a]"..who.."%f[%A]", k) then
      if selectString(who, c-1) > -1 then
        if color     then fg(color) end
        if bold      then setBold(true) end
        if underline then setUnderline(true) end
        if italicize then setItalics(true) end
        resetFormat()
      else return end
    end

--    k = k + #who
    k = k + 1 -- this is a quicker optimization
  end
end

function ndb.finished_honors(event, name, type)
  if svo.conf.paused or not ndb.honorslist then return end
  local type = gaghonours and "quiet" or "manual"

  local name = next(ndb.honorslist or {})
  if not name then
    if type ~= "manual" then
      echo'\n'
      svo.echof("Done checking all new names.")
      svo.showprompt()
      raiseEvent("NameDB finished all honors")
    end

    ndb.manualcheck = nil
    ndb.hidehonorswindow()
    return
  end
end

function ndb.honors_next(argument)
  if not svo.conf.autocheck and not ndb.manualcheck then return end
  if svo.conf.usehonors and not svo.bals.equilibrium then return end
  if not svo.conf.usehonors and argument then return end -- argument is passed if this comes from a balance,
                                                         -- which is for usehonors only - with it off, autohonors will start many honors processes

  local name = next(ndb.honorslist or {})
  if not name then return end

  if svo.conf.usehonors then
    ndb.honors(name, "quiet")
  else
    --ndb.getinfo(name) -- Achaea disallowed use of website scraping
    return
  end

  ndb.honorslist[name] = nil
  local left = table.size(ndb.honorslist)

  local timeleft = {}
  if svo.conf.usehonors then
    -- honors takes 2s eq
    local leftseconds = left * 2

    local h,m,s = seconds2human(leftseconds)
    if h > 0 then
      timeleft[#timeleft+1] = h.."h"
    end
    if h > 0 and m > 0 then
      timeleft[#timeleft+1] = ", "
    end
    if m > 0 then
      timeleft[#timeleft+1] = m.."m"
    end
    if m > 0 and s > 0 then
      timeleft[#timeleft+1] = ", "
    end
    if s > 0 then
      timeleft[#timeleft+1] = s.."s"
    end
  end

  ndb.showhonorswindow(string.format("Checking %s, %s name%s%s left to check...\n", name, left, (left == 1 and '' or 's'), (next(timeleft) and '('..table.concat(timeleft)..')' or '')))
end
signals["svo got balance"]:connect(ndb.honors_next)
signals["namedb finished honors"] = luanotify.signal.new()
signals["namedb finished honors"]:connect(ndb.honors_next)

-- sk.togglehonors = function()
--   if svo.conf.usehonors then
--     signals["namedb finished honors"]:block(ndb.honors_next)

-- end
-- signals["svo config changed"]:connect(sk.togglehonors)
