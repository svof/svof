if not svo.ignore.block then
  svo.defs.keepup("block", false, nil, true)
else
  send("unblock", false)
end