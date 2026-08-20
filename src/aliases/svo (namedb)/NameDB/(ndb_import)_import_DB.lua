-- keep the location used between imports
local oldlocation = false
if ndb.importdata and ndb.importdata.location then oldlocation = ndb.importdata.location end

ndb.importdata = {
  location = oldlocation,
  data = false,
  fields = {},
}

if ndb.importdata.location then ndb.getimportfields() end
ndb.importmenu()