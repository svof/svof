selectString(matches[2], 1)
setUnderline(true)
setLink([[send("showbug ]]..matches[2]..[[")]], "Click to show bug #"..matches[2])