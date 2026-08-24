local percent = math.min(180, math.floor((100/tonumber(matches[3])) * tonumber(matches[2])))

echo(string.rep(" ", 36 - #getCurrentLine()))

local width = math.floor((percent * 30) / 100)
fg("a_green") echo(string.rep([[|]], width))
fg("a_darkgreen") echo(string.rep("-", 30 - width))

fg("a_darkgrey") echo(" " .. percent .. "%")
deselect() resetFormat()

local diff = tonumber(matches[3]) - tonumber(matches[2])
local af = math.floor(diff/(svo.stats.maxhealth * .05))
local aff = math.floor(diff/(svo.stats.maxmana * .05))

echo"\n" svo.echof("fortify: %d, power: %d", af, aff)