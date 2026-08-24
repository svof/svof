local percent = math.min(180, math.floor((100/tonumber(matches[3])) * tonumber(matches[2])))

echo(string.rep(" ", 36 - #line))
resetFormat()

local width = math.floor((percent * 30) / 100)
fg("blue") echo(string.rep([[|]], width))
fg("a_darkgreen") echo(string.rep("-", 30 - width))

fg("a_darkgrey") echo(" " .. percent .. "% mana") resetFormat()