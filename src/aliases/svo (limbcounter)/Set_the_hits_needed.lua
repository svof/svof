local name = (matches[2] ~= "") and matches[2] or nil
local hits = tonumber(matches[3])

svo.lc_sethitsneeded(name,hits)