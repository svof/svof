-- see if it's arm numbness
local previousline = getLines(getLineNumber()-1, getLineNumber())[1]
if previousline == "You try to use your right hand but it is still too numb."
  or previousline == "You try to use your left hand but it is still too numb." then return end

local affs = svo.affl
-- do we know something is wrong already?
if affs.crippledleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mangledleftarm or affs.missingrightarm or affs.missingleftarm or affs.unknowncrippledarm or affs.unknowncrippledlimb then return end

-- if no, we should cure it
svo.valid.simpleunknowncrippledarm()