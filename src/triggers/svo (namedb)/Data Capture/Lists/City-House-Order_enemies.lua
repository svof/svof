local field

if not ndb.checkingfor then return end
if ndb.checkingfor == "city" then
  ndb.fixed_set(ndb.db.people.cityenemy, 0)
  field = "city"
elseif ndb.checkingfor == "order" then
  ndb.fixed_set(ndb.db.people.orderenemy, 0)
  field = "order"
else
  ndb.fixed_set(ndb.db.people.houseenemy, 0)
  field = "house"
end
local names = string.split(multimatches[4][1], ",")

for i = 1, #names do
  names[i] = names[i]:trim()
end

ndb.fixed_set(ndb.db.people[field.."enemy"], 1, db:in_(ndb.db.people.name, names))

-- reload all highlights
ndb.loadhighlights()

echo'\n'

if ndb.checkingenemies and ndb.checkingenemies.option then
  local temp_name_list = {}
  for i = 1, #names do
    temp_name_list[#temp_name_list + 1] = {
      name = names[i],
    }
  end

  db:merge_unique(ndb.db.people, temp_name_list)

  svo.echof(field:title().." enemies list updated, and new names added.")

  raiseEvent("NameDB got new data")
else
  svo.echof(field:title().." enemies list updated.")
end

disableTrigger("City-House-Order enemies")
if ndb.checkingenemies then killTimer(ndb.checkingenemies[1]) end
ndb.checkingenemies = nil
ndb.checkingfor = nil