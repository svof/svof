function svo_autoslickprio(_, balance)
  if not svo.conf.autoslick then return end
  if balance ~= 'herb' then return end
  if not (svo.affl.slickness and svo.affl.asthma) and not svo.swapped_asthma then return end

  -- see if we need to swap it back
  if svo.swapped_asthma then
    if not svo.affl.slickness or not svo.affl.asthma then
      -- all good now? undo change
      svo.prio_swap("asthma", "herb", svo.swapped_asthma)
      svo.swapped_asthma = nil
      echo'\n' svo.echof("Swapped asthma priority back down.")
      return
    end
  end

  -- don't have any more affs than this? Then asthma will get cured, so we're fine
  if table.size(svo.affl) <= 2 then return end

  local asthma_prio = svo.prio.getnumber("asthma", "herb")
  local paralysis_prio = svo.prio.getnumber("paralysis", "herb")
  local impatience_prio = svo.prio.getnumber("impatience", "herb")

  -- see if it's not highest
  if asthma_prio > paralysis_prio and asthma_prio > impatience_prio then return end

  local currentmax = svo.prio.gethighest("herb")

  svo.prio_swap("asthma", "herb", currentmax+1)
  svo.swapped_asthma = asthma_prio
  echo'\n' svo.echof("emergency - have asthma+slickness and paralysis/impatience prio is before asthma: swapping asthma to be cured first.")
end