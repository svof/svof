-- vexportprio <name> server saves the serverside priorities
if matches[3] and matches[3]:match("^%s*server%s*$") then
  svo.sk.serverprios_export(matches[2])
  return
end

svo.prio.export(matches[2], matches[3], true)