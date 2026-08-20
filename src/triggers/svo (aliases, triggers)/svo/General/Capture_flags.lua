for _, balance in pairs{"balance", "equilibrium"} do
  if svo.bals[balance] then svo["had_"..balance] = true end
end

svo.valid.setup_prompt()