function ndb.showqwi()
  if not ndb.checkingqwi then return end
  ndb.checkingqwi = nil

  ndb.checkqw(nil, "show infamous")
end