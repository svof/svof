if svo.conf.aillusion and svo.conf.ignoresinglestabs and not string.find(getLines(getLineNumber()-1, getLineNumber())[1], "^The attack rebounds back onto") then
  svo.ignore_illusion("Ignored the single-aff doublestab (vconfig ignoresinglestabs is on)", true)
end