deleteLine()
cecho("\n<LawnGreen>You have ".. matches[2].. " feet left to reel in!")
fdifference = fdistance - matches[2]
cecho("<medium_orchid> You reeled in ".. fdifference .. " feet.")
fdistance = matches[2]
if catch then cecho("<red> Caught a " ..catch.."!!") end