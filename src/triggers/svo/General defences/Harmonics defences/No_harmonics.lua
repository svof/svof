for _, harmonic in ipairs{"lament", "anthem", "harmonius", "contradanse", "paxmusicalis", "gigue", "bagatelle", "partita", "berceuse", "continuo", "wassail", "canticle", "reel", "hallelujah"} do
  if svo.defc[harmonic] then svo.defs["lost_"..harmonic]() end
end