local class = svo.me.class:title()

-- load help data in
if not ndb.help then
  local path = svo.installationfolder() .."/ndb-help.lua"
  
  -- A missing file used to reach f:read on a nil f and raise a raw traceback,
  -- with the perfectly good message below going unused.
  local f, m = io.open(path)
  if not f then
    svo.echof("Couldn't open the ndb-help.lua file (%s) :/ is it where svof was installed?", tostring(m))
    return
  end
  local s = f:read("*a")
  f:close()

  local ok, data = pcall(loadstring("return "..s))
  if not ok or not data then
    svo.echof("Couldn't load data from the ndb-help.lua file :/ maybe it is messed up.")
    return
  end

  ndb.help = data
end

local function gettooltip(entry)
  return table.concat(entry.definition, "\n")
end

local function getdesc(entry)
  return table.concat(entry.definition, "\n")
end

local function showshort()
	svo.echof("ndb alias cheatsheet:")

	for id, entry in pairs(ndb.help) do
		fg("DarkSlateGrey") echo"  * " setFgColor(unpack(svo.getDefaultColorNums)) echoLink(entry.term, 'ndb.showhelp('..id..')', gettooltip(entry), true) echo"\n"
	end
end

local function showlong()
	svo.echof("ndb alias cheatsheet (extended):")

	for id, entry in pairs(ndb.help) do
		fg("DarkSlateGrey") echo"  * " setFgColor(unpack(svo.getDefaultColorNums)) echoLink(entry.term, 'ndb.showhelp('..id..')', gettooltip(entry), true) echo"\n"
		echo"      " echo(getdesc(entry)) echo"\n"  echo"\n"
	end
end

if matches[2] then showlong() else showshort() end
svo.showprompt() echo'\n'