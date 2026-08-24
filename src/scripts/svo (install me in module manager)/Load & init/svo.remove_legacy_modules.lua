-- Svof used to ship as 24 Mudlet modules, installed by a 25th that acted as a
-- bootstrap. It now ships as a single package.
--
-- Anything left over from a module install keeps working after the package is
-- installed, which means the whole system exists twice: every trigger fires
-- twice, every alias runs twice, and curing commands are sent twice on the
-- same prompt. That is worse than the system not loading at all, so the
-- leftovers are removed rather than merely warned about.
--
-- Only Svof's own modules are touched, and only in this profile - nothing here
-- deletes a file. Mudlet's own profile save does, though, which is why the
-- sweep is delayed and every module xml is copied first. See SAVE_DELAY.

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

-- How long to wait before touching anything, and why it is not zero.
--
-- Host::installPackage calls saveProfile() BEFORE it raises sysInstall.
-- saveProfile snapshots modulesToWrite from the still-synced modules and hands
-- saveModules() to QtConcurrent::run, where writeModuleXML reads the LIVE
-- trigger/alias/script lists on a pool thread. The main thread then raises
-- sysInstall, this guard runs, and the sweep empties those lists a few
-- milliseconds later. The background writer then serialises what is left,
-- which is nothing - so every module xml on disk is overwritten with a ~304
-- byte empty <MudletPackage>. Measured on Mudlet 4.16: 23 to 25 of 25 files
-- truncated, the count varying because it is a race. Not reproduced on 4.18 or
-- 4.22, but svo_init_system accepts anything newer than 3.20, the old install
-- instructions told people to tick sync on all 25, and for most of them those
-- files are the only copy of the pre-conversion system.
--
-- Delaying past that save is the fix; two seconds measured clean where zero
-- did not. currentlySavingProfile is not exposed to Lua on 4.16, so a fixed
-- delay is the only option. Three, for margin on a slower machine - the cost
-- of the extra second is one more second of everything running twice.
local SAVE_DELAY = 3

-- Belt and braces for the above: if the delay is still not enough on some
-- Mudlet or some machine, the user has a copy. Written once - a second run
-- must not overwrite a good backup with an already-truncated file.
local function backup(module)
  local path = getModulePath(module)
  if not path then return nil end
  local to = path .. ".svof-backup"
  if io.open(to, "rb") then return nil end
  local from = io.open(path, "rb")
  if not from then return nil end
  local data = from:read("*a")
  from:close()
  if not data or #data == 0 then return nil end
  local out = io.open(to, "wb")
  if not out then return nil end
  out:write(data)
  out:close()
  return to
end

local function finish(found)
  -- Cleared first, not last. Clearing it after the printing meant a throw
  -- anywhere below latched svo.removing_legacy_modules for the whole session,
  -- so a re-raised sysInstall found the guard disabled: on the failure branch
  -- that strands leftover modules with no message and no way to retry.
  svo.removing_legacy_modules = nil

  local left = installed(found)

  if #left == 0 then
    cecho("<green_yellow>Svof: old modules removed.\n")
  else
    cecho("\n<indian_red>Svof: couldn't remove " .. #left .. " of " .. #found ..
          " module(s): " .. table.concat(left, ", ") .. "\n")
    cecho("<indian_red>Please remove them in the Module Manager, or everything will run twice.\n")
  end

  -- Removing the bootstrap module fires its sysUninstallModule handler, which
  -- ends in svo.systemloaded = nil - after svo_init_system had already set it.
  -- Left alone, that session has the right items and an uninitialised system,
  -- so there is no curing at all until a second restart. Re-init the way
  -- svo.classchange does rather than asking for two restarts.
  --
  -- In practice this branch has never been entered: at sweep time
  -- svo.uninstall_all_modules resolves to the package's body, which returns
  -- early for any name but "svof", so the flag is never cleared. It stays
  -- because which of the two bodies wins depends on load order that this code
  -- does not control, and being wrong in the other direction costs a session
  -- with no curing.
  if not svo.systemloaded and svo_init_system then
    cecho("<indian_red>Svof: reloading the system after the cleanup.\n")
    svo.systemloaded = false
    -- svo_init_system signals failure by NOT setting svo.systemloaded - it
    -- returns quietly when a subsystem is missing or Penlight is not loaded
    -- yet. Branching on pcall's ok alone reported success for exactly the case
    -- worth reporting: measured ok=true, err=nil, systemloaded=false with one
    -- loader absent.
    local ok, err = pcall(svo_init_system)
    if not ok or not svo.systemloaded then
      cecho("<indian_red>Svof: reload failed (" ..
            tostring(ok and "the system did not finish loading" or err) ..
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

  -- This used to promise "your xml files are left on disk untouched", and on
  -- Mudlet 4.16 that promise was false - see SAVE_DELAY. Say what actually
  -- happens, and make the files recoverable either way.
  cecho("<indian_red>A copy of each module xml is kept beside it as <file>.svof-backup,\n")
  cecho("<indian_red>because Mudlet rewrites synced module files while it saves the profile.\n")

  -- The disableModuleSync loop that used to sit here is gone. It could not
  -- help - modulesToWrite was snapshotted before sysInstall was raised, so the
  -- write is already scheduled by the time any of this runs - and in an
  -- isolated three-module test it made things worse: uninstallModule with sync
  -- left on truncated nothing on any Mudlet, while disableModuleSync followed
  -- by uninstallModule truncated the file on 4.16.
  --
  -- Wait for Mudlet's own profile save to finish before touching anything.
  -- This was tempTimer(0, ...), which put the sweep inside that save's window.
  -- The backups are taken here rather than above for the same reason: at
  -- sysInstall time the background writer may be part-way through the file,
  -- and a copy of a half-written xml is not a backup.
  tempTimer(SAVE_DELAY, function()
    for _, module in ipairs(found) do backup(module) end
    sweep(found, 1)
  end)
end
