local affs = svo.affl
-- do we know something is wrong already?
if affs.webbed or affs.impale or affs.roped or affs.crippledleftarm or affs.crippledrightarm or affs.mangledrightarm or affs.mangledleftarm or affs.missingrightarm or affs.missingleftarm or affs.unwknowncrippledarm or affs.unknowncrippledlimb then return end

-- if no, we should cure it
svo.valid.simpleunknownany()