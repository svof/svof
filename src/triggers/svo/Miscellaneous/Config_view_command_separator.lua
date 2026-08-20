local separator = multimatches[3][2]

if separator == "None" then separator = '' end

svo.config.set("commandseparator", separator:trim())