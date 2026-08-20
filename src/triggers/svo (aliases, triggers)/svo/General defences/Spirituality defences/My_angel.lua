local percent = math.min(180, math.floor((100/5000) * tonumber(multimatches[2][2])))

echo(string.rep(" ", 36 - #getCurrentLine()))

local width = math.floor((percent * 30) / 100)
fg("a_green") echo(string.rep([[|]], width))
fg("a_darkgreen") echo(string.rep("-", 30 - width))

fg("a_darkgrey") echo(" " .. percent .. "% power")
deselect() resetFormat()

local diff = 5000 - tonumber(multimatches[2][2])
svo.af = math.floor(diff/(svo.stats.maxhealth * .05))
svo.aff = math.floor(diff/(svo.stats.maxmana * .05))

echo"\n" svo.echof("fortify: %d, power: %d", svo.af, svo.aff)

if svo.fixangel == "fortify" then
  for i = 1, svo.af do svo.doadd("angel fortify", false, false) end
  if svo.af == 0 then svo.echof("Your angel is healthy already.") end
  svo.fixangel = nil
elseif svo.fixangel == "power" then
  for i = 1, svo.aff do svo.doadd("angel power", false, false) end
    if svo.aff == 0 then svo.echof("Your angel is healthy already.") end
  svo.fixangel = nil
end