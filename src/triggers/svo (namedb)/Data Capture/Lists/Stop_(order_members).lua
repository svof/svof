setTriggerStayOpen("Order members", 0)

db:merge_unique(ndb.db.people, temp_name_list)

for _, person in pairs(temp_name_list) do
  raiseEvent("NameDB saw list name", person.name)
end

temp_name_list = nil

raiseEvent("NameDB got new data")