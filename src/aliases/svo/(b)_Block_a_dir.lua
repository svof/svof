if not svo.ignore.block then
  svo.conf.blockingdir = matches[2]
  svo.defs.keepup("block", true, nil, true)
else
  send(command, false)
end