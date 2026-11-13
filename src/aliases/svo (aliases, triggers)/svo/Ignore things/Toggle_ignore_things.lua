-- people typically expect the aff versions of these, not the defences
if matches[2] == "deaf" then matches[2] = "deafaff"
elseif matches[2] == "blind" then matches[2] = "blindaff" end

-- vignore <aff> <count>: one stack, on the server, in custom mode
if matches[3] and matches[3] ~= "" then
  svo.sk.serverprios_stackignore(matches[2], tonumber(matches[3]))
  return
end

svo.toggle_ignore(matches[2])