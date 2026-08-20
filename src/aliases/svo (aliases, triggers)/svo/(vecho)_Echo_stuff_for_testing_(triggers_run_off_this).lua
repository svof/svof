local s = matches[2]

s = string.gsub(s, "%$", "\n")
feedTriggers(s.."\n")
echo("")