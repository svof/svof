-- vimportprio <name> server loads saved serverside priorities. vimportprio
-- server is that with no name, as the plain form is with no name
if matches[3] and matches[3] ~= "" then
  svo.sk.serverprios_import(matches[2])
  return
end

svo.prio.import(matches[2], true, true)
svo.sk.serverprios_remind()