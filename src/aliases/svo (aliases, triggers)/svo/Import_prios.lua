-- vimportprio <name> server loads saved serverside priorities
if matches[3] and matches[3] ~= "" then
  svo.sk.serverprios_import(matches[2])
  return
end

svo.prio.import(matches[2], true, true)
svo.sk.serverprios_remind()