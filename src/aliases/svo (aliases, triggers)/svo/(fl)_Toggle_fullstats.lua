if not matches[2] then matches[2] = "" end
svo.fullstats((matches[2] == "" and true or false), (matches[3] and [[expandAlias"]]..matches[3]..[["]] or nil), true)