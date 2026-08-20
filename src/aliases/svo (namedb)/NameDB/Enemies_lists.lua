if ndb.checkingenemies then killTimer(ndb.checkingenemies[1]) end
ndb.checkingfor = matches[2]

ndb.checkingenemies = {
  tempTimer(10+getNetworkLatency(), [[
    ndb.checkingenemies = nil
    disableTrigger"City/House/Order enemies"
  ]]),
  option = (matches[3] and matches[3]:trim() or nil)
}

enableTrigger"City/House/Order enemies"
send(matches[2].." enemies", false)