deleteLine()
cecho("\n<DeepPink>Fish swam out " .. matches[2].. " feet.")
fdistance = fdistance + matches[2]
cecho("<LightGoldenrod> Gotta reel in " .. fdistance .. " feet.")
if catch then cecho("<red> Caught a " ..catch.."!!") end
