-- people typically expect the aff versions of these, not the defences
if matches[2] == "deaf" then matches[2] = "deafaff"
elseif matches[2] == "blind" then matches[2] = "blindaff" end

svo.toggle_ignore(matches[2])