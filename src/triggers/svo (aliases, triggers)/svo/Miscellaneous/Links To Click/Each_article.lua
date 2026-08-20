if not svo.readingsection then return end

selectString(matches[2], 1)
setUnderline(true)
setLink([[send("readnews ]]..svo.readingsection..[[ ]]..matches[2]..[[")]], "Click to read "..svo.readingsection.." news #"..matches[2])