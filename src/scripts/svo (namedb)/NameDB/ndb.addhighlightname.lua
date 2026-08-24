function ndb.addhighlightname(_, name)
  if not name then return end -- no name is passed on a suicided person

  local person = ndb.getname(name)

  if not person then return end -- in case a person was deleted
  ndb.singlehighlight(name,
      person.city or "", 
      person.order or "", 
      person.cityenemy or 0,
      person.orderenemy or 0, 
      person.houseenemy or 0, 
      svo.me.watchfor[person.name],
      person.immortal or 0)
end