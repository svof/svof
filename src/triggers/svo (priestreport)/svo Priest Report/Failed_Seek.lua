if svo.defc.dragonform then return end

if svo.locating and svo.locating.name then
    if svo.locating.clan == "party" then
        send(string.format(
        "pt %s could not be located",
        svo.locating.name
        ))
    elseif svo.locating.clan then
        send(string.format(
        "clan %s tell %s could not be located",
        svo.locating.clan, svo.locating.name
        ))
    end
    svo.locating = nil
end