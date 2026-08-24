-- keep the location used between exports
local oldlocation = false
if ndb.exportdata and ndb.exportdata.location then oldlocation = ndb.exportdata.location end

ndb.exportdata = {
  fields = {},
  people = {all = true},
  location = oldlocation
}

-- setup defaults
for key, _ in pairs(ndb.schema.people) do
  ndb.exportdata.fields[key] = true
end
ndb.exportdata.fields.notes = false

ndb.exportmenu()