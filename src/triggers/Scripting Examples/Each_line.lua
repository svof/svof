local name = matches[2]

if ndb.isenemy(name) then
	parse_enemies[name] = (100 / tonumber(matches[4])) * tonumber(matches[3])
end