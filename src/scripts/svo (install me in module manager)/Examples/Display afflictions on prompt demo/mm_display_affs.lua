-- just shows how to suffix affs to the prompt so you know

function mm_display_affs()
	-- put two dashes before the line below so this function will work!
	if true then return end

	-- this if/elseif chain will append one aff at a time only
	if svo.affl.prone then
		echo("[[PRONE]] ")
	elseif svo.affl.paralysis then
		echo("[[PARALYSIS]] ")
	elseif svo.affl.crippledleftleg then
		echo("[[CRIPPLED LEFTLEG]] ")
	end

	-- these stand-alone ifs will allow for several affs to be suffixed
	if svo.affl.crippledrightleg then
		echo("[[CRIPPLED RIGHT LEG]] ")
	end

	if svo.affl.tangled then
		echo("[[TANGLED]] ")
	end
end