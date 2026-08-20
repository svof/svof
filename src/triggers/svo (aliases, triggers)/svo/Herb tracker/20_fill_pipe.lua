local pipeid = tonumber(matches[2])

for _, pipe in pairs(svo.me.pipes) do
  if pipe.id == pipeid then
    pipe.maxpuffs = 20
    echo'\n' svo.echof("Found & set your %s pipe as a 20-puffs pipe.", pipe.filledwith)
  end
end