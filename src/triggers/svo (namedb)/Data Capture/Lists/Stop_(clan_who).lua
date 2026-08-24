setTriggerStayOpen("Clan who", 0)

db:merge_unique(ndb.db.people, temp_name_list)

for _, person in pairs(temp_name_list) do
  raiseEvent("NameDB saw list name", person.name)
end

if next(ndb.temp_classes_list) then
  local classes = svo.keystolist(ndb.temp_classes_list)
  table.sort(classes)

  for i = 1, #classes do
    classes[i] = ndb.temp_classes_list[classes[i]] .. " "..(ndb.temp_classes_list[classes[i]] == 1 and classes[i] or string.pluralize(classes[i]))
  end

  moveCursor(0, getLineNumber())
  svo.itf("%s present, of those %s %s dragon%s (%s total).\n", svo.concatand(classes), temp_dragon, (temp_dragon == 1 and 'is a' or 'are'), (temp_dragon == 1 and '' or 's'), #temp_name_list)
  moveCursorEnd()
  ndb.temp_classes_list = nil
end

temp_name_list, temp_dragon = nil, nil

raiseEvent("NameDB got new data")
