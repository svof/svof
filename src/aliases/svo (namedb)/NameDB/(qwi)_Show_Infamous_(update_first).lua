if not svo.conf.usehonors then
  svo.echof("You need to enable vconfig usehonors for Infamous info to show.")
  return
else
  ndb.checkingqwi = true
  ndb.checkqw(nil, "update")
end

