if not clanNames then 
   clanNames = multimatches[2][2]:gsub(",? and ", ", ")
else
   clanNames = clanNames .. " " .. multimatches[2][2]:gsub(",? and ", ", ")
end

setTriggerStayOpen("Clan Position Name",99)
setTriggerStayOpen("Clan Position Start",99)