function svo.rf_check_trans()
  if not svo.loader.refiller then return end
  if not (gmcp and gmcp.Char and gmcp.Char.Skills and gmcp.Char.Skills.Groups) then return end

  svo.rf_transrefiller = false
  svo.rf_transtoxicology = false
  for _, t in pairs(gmcp.Char.Skills.Groups) do
    if t.name and (t.name == "Remedies") and t.rank and t.rank == "Transcendent" then
      svo.rf_transrefiller = true; break
    end
    if t.name and (t.name == "Toxicology") and t.rank and t.rank == "Transcendent" then
      svo.rf_transtoxicology = true;break
    end
  end
end