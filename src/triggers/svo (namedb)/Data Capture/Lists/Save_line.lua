if stop_capturing then stop_capturing = nil return end
if string.find(line, "The following are ACTIVE citizens of .*") then return end

if ndb.tempnames == nil then ndb.tempnames = "" end

ndb.tempnames = ndb.tempnames .. " " .. line
