local class = svo.me.class:title()

-- load help data in
if not ndb.help then
  local path = svo.installationfolder() .."/ndb-help.lua"
  
  local f, m = io.open(path)
  local s = f:read("*a")

  local data = loadstring("return "..s)()
  if not data then
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