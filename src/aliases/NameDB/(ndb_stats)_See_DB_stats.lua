svo.echof("Compiling database stats...")
svo.showprompt()

local function makestats()
  local alldata = db:fetch(ndb.db.people)

  if not alldata or not next(alldata) then svo.echof("Your NameDB is empty! Check 'qw', 'citizens' to start filling it up...") return end

  local totalcount = #alldata

  local cities = {}
  for i = 1, #alldata do
    local p = alldata[i]
    if not p.city or p.city == '' then p.city = "none" end
    cities[p.city] = cities[p.city] or {}
    cities[p.city][#cities[p.city]+1] = p.name
  end
  local citiessorted = {}; for city in pairs(cities) do citiessorted[#citiessorted+1] = {city, #cities[city]} end
  table.sort(citiessorted, function(a, b)
    return a[2] > b[2]
  end)
  
  echo'\n'
  svo.echof("People in the DB: %s", totalcount)
  svo.echof("City stats:")
  for i = 1, #citiessorted do
    cecho(string.format("  %-8s - %d citizens.\n", citiessorted[i][1], citiessorted[i][2]))
  end

  svo.showprompt()
end

tempTimer(0, makestats)