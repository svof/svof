-- Svof used to ship as 24 Mudlet modules, installed by a 25th that acted as a
-- bootstrap. It now ships as a single package.
--
-- Anything left over from a module install keeps working after the package is
-- installed, which means the whole system exists twice: every trigger fires
-- twice, every alias runs twice, and curing commands are sent twice on the
-- same prompt. That is worse than the system not loading at all, so the
-- leftovers are removed rather than merely warned about.
--
-- Only Svof's own modules are touched. Nothing is deleted from disk; the
-- modules are removed from the profile, so the xml files stay where they are.

local legacy_modules = {
  "svo (install me in module manager)",
  "svo (actions dictionary)",
  "svo (alias and defence functions)",
  "svo (curing skeleton, controllers, action system)",
  "svo (custom prompt, serverside)",
  "svo (install, config, pipes, rift, parry, prios)",
  "svo (setup, misc, empty, funnies, dor)",
  "svo (trigger functions)",
  "svo (aliases, triggers)",
  "svo (namedb)",
  "svo (elistsorter)",
  "svo (fishdist)",
  "svo (inker)",
  "svo (logger)",
  "svo (mindnet)",
  "svo (offering)",
  "svo (peopletracker)",
  "svo (reboundingsileristracker)",
  "svo (refiller)",
  "svo (runeidentifier)",
  "svo (stormhammertarget)",
  "svo (limbcounter)",
  "svo (burncounter)",
  "svo (priestreport)",
  "svo (enchanter)",
}

function svo.remove_legacy_modules(event, name)
  -- sysInstall fires for every package; only react to our own
  if event == "sysInstall" and name and name ~= "svof" then return end
  if svo.removing_legacy_modules then return end

  local found = {}
  for _, module in ipairs(legacy_modules) do
    if getModulePath(module) then found[#found + 1] = module end
  end
  if #found == 0 then return end

  svo.removing_legacy_modules = true

  cecho("\n<indian_red>Svof: found " .. #found .. " module(s) from the older module-based install.\n")
  cecho("<indian_red>Leaving them alongside the package would run everything twice, so they are being removed.\n")
  cecho("<indian_red>Your xml files are left on disk untouched - only the modules are removed from this profile.\n")

  for _, module in ipairs(found) do
    -- sync has to go first: uninstalling a synced module can write it back out
    if disableModuleSync then disableModuleSync(module) end
  end

  -- give Mudlet a moment to settle the sync change before uninstalling
  tempTimer(0, function()
    for _, module in ipairs(found) do
      local ok, err = pcall(uninstallModule, module)
      if not ok then
        cecho("<indian_red>Svof: couldn't remove " .. module .. " (" .. tostring(err) .. ") - please remove it in the Module Manager.\n")
      end
    end
    svo.removing_legacy_modules = nil
    cecho("<green_yellow>Svof: old modules removed. Please restart Mudlet to finish cleaning up.\n")
  end)
end
