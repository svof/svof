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

-- The bootstrap module goes last on purpose. It carries its own
-- svo.uninstall_all_modules registered on sysUninstallModule, which mass
-- uninstalls the rest and ends with svo.systemloaded = nil, so removing it
-- first turns the remaining work into a race against a handler we do not
-- control.
local BOOTSTRAP = "svo (install me in module manager)"

local function installed(list)
  local left = {}
  for _, module in ipairs(list) do
    if getModulePath(module) then left[#left + 1] = module end
  end
  return left
end

-- uninstallModule RETURNS false when Mudlet refuses - Host::uninstallPackage
-- declines while a profile save is in flight - it does not raise. pcall's `ok`
-- was therefore true for every refusal, the "couldn't remove" branch was dead,
-- and the guard reported "old modules removed" having removed nothing.
local function try_remove(list)
  for _, module in ipairs(list) do
    pcall(uninstallModule, module)
  end
end

-- The refusal is transient - the same call a few seconds later succeeds - so
-- retry a bounded number of times before telling the user to do it by hand.
local MAX_ATTEMPTS = 4

local function finish(found)
  local left = installed(found)

  if #left == 0 then
    cecho("<green_yellow>Svof: old modules removed.\n")
  else
    cecho("\n<indian_red>Svof: couldn't remove " .. #left .. " of " .. #found ..
          " module(s): " .. table.concat(left, ", ") .. "\n")
    cecho("<indian_red>Please remove them in the Module Manager, or everything will run twice.\n")
  end

  svo.removing_legacy_modules = nil

  -- Removing the bootstrap module fires its sysUninstallModule handler, which
  -- ends in svo.systemloaded = nil - after svo_init_system had already set it.
  -- Left alone, this session has the right items and an uninitialised system,
  -- so there is no curing at all until a second restart. Re-init the way
  -- svo.classchange does rather than asking for two restarts.
  if not svo.systemloaded and svo_init_system then
    cecho("<indian_red>Svof: reloading the system after the cleanup.\n")
    svo.systemloaded = false
    local ok, err = pcall(svo_init_system)
    if not ok then
      cecho("<indian_red>Svof: reload failed (" .. tostring(err) ..
            ") - please restart Mudlet.\n")
    end
  end
end

local function sweep(found, attempt)
  local left = installed(found)
  if #left == 0 then return finish(found) end

  -- bootstrap last, see BOOTSTRAP above
  table.sort(left, function(a, b)
    if (a == BOOTSTRAP) ~= (b == BOOTSTRAP) then return b == BOOTSTRAP end
    return a < b
  end)

  try_remove(left)

  if #installed(found) > 0 and attempt < MAX_ATTEMPTS then
    tempTimer(2, function() sweep(found, attempt + 1) end)
  else
    finish(found)
  end
end

function svo.remove_legacy_modules(event, name)
  -- sysInstall fires for every package; only react to our own
  if event == "sysInstall" and name and name ~= "svof" then return end
  if svo.removing_legacy_modules then return end

  local found = installed(legacy_modules)
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
  tempTimer(0, function() sweep(found, 1) end)
end
