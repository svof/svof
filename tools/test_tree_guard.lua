--[[
Logic-level test for the tree guard: svof does not touch tree when every
tree-curable affliction it has already has a cure on its way.

The game runs commands in the order they are sent, and svof sends tree after
focus, salve, sip, purgative, smoke and herb each prompt. So with two
afflictions, focus for one and an herb for the other, the any2affs strategy
used to send touch tree after both, and tree found nothing left to cure.
That happened 4 times in a captured fight against rats. The strategies keep
their conditions; the guard only skips that one case. Shrugging and
dragonheal cure the same afflictions, are sent after the same cures and share
empty.tree, so they carry the same guard and are run here too.

Like the other suites, this does not run svof or Mudlet. It extracts the real
code by anchor text and runs it under stubs: the touchtree, shrugging and
dragonheal actions' isadvisable, codepaste.treecurablescovered,
gettreeableaffs with the tree-curable list and its blocks, every shipped tree,
shrugging and dragonheal strategy, and the action
system's doaction, checkaction, actionclear and doingaction, over Penlight's
OrderedMap. Cures are put on their way with the real doaction, under the names
dict_setup gives them.

The controls run the same scenarios with the isadvisable from before the
guard, so the scenarios are shown to reproduce the empty touch.

A second, smaller guard is covered at the end: what svof records when a touch
is sent twice, as doubledo does under stupidity or serious concussion. The
first touch's result and the second touch's off-balance line arrive before the
same prompt, and both go into the one lifevision entry tree has. That part
runs the real tree line handlers from Main trigger functions (tree1,
tree_cured, tree2 and touched_treeoffbal) over the real lifevision.add, with a
control that runs touched_treeoffbal from before its guard. It then finishes
the entry at the prompt with the real touchtree action, actionfinished,
empty.tree and presume_cured, so it checks what the kept entry does, not only
what was filed.

Run: lua tools/test_tree_guard.lua
]]

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return data
end

-- From the start anchor to just before the end anchor, or with through, up
-- to and including the first "\nend" after the end anchor.
local function extract(path, start_anchor, end_anchor, through)
  local source = read_file(path)
  local s = source:find(start_anchor, 1, true)
  if not s then error("start anchor not found in " .. path .. ": " .. start_anchor) end
  local e = source:find(end_anchor, s + 1, true)
  if not e then error("end anchor not found in " .. path .. ": " .. end_anchor) end
  if not through then return source:sub(s, e - 1) end
  e = source:find("\nend", e + #end_anchor, true)
  if not e then error("no closing end after " .. end_anchor .. " in " .. path) end
  return source:sub(s, e + 4)
end

local ACTIONS = "src/scripts/svo (curing skeleton, controllers, action system)/Action_system.lua"
local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local EMPTY = "src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua"
local STRATS = "src/scripts/svo (core)/svo Utilities/Tree_curing_strats.lua"
local SHRUG_STRATS = "src/scripts/svo (core)/svo Utilities/Shrugging_curing_strats.lua"
local DRAGON_STRATS = "src/scripts/svo (core)/svo Utilities/Dragonheal_curing_strats.lua"
local PENLIGHT = "src/scripts/svo (core)/3rdparty/Penlight/"
local TRIGGERS = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"
local SKELETON = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"

local GUARDED = "if s and m then return not codepaste.treecurablescovered() end"

local blocks = {
  actions = extract(ACTIONS, "svo.doaction = function(arg1, arg2)",
    "-- checks if any of the actions are being done", false),
  actionclear = extract(ACTIONS, "svo.actionclear = function(act)", "actions_performed[act.action_name] = nil", true),
  doingaction = extract(ACTIONS, "svo.doingaction = function (which)", "-- doingaction was previously private", false),
  codepaste = extract(DICT, "codepaste.nonstdcure = function()", "if svo.haveskillset('metamorphosis') then", false),
  treeable = extract(EMPTY, "empty.treecurables = {", "empty.tree = function ()", false),
  touchtree = "return {\n        "
    .. extract(DICT, "isadvisable = function()\n          if not next(affs) or not bals.tree",
      "oncompleted = function (aff)\n          -- small heuristic", false)
    .. "}",
  strats = read_file(STRATS),
  -- shrugging and dragonheal cure the same affs and share empty.tree
  shrugging = "return {\n        "
    .. extract(DICT, "isadvisable = function()\n          if not next(affs) or not bals.shrugging",
      "oncompleted = function (number)", false)
    .. "}",
  dragonheal = "return {\n        "
    .. extract(DICT, "isadvisable = function()\n          if not next(affs) or not defc.dragonform",
      "oncompleted = function (number)", false)
    .. "}",
  shrug_strats = read_file(SHRUG_STRATS),
  dragon_strats = read_file(DRAGON_STRATS),
  -- the tree line handlers share the local tree_cure, so they load as one chunk
  tree_lines = extract(TRIGGERS, "local tree_cure = false", "\nfunction svo.valid.tree2()", true)
    .. "\n" .. extract(TRIGGERS, "local TREE_SPECIAL = {", "-- humour cures", false)
    .. "\n" .. extract(TRIGGERS, "function svo.valid.touched_treeoffbal()", "-- special defences", false),
  lifevision_add = extract(SKELETON, "function svo.lifevision.add(what, other_action, arg, lineguard)",
    "function svo.lifevision.addcust(", false),
  -- what the prompt then does with tree's entry: the whole touchtree action,
  -- actionfinished, and empty.tree with the presume_cured it calls
  touchtree_entry = "return {\n" .. extract(DICT, "    touchtree = {", "    restore = {", false) .. "}",
  actionfinished = extract(ACTIONS, "svo.actionfinished = function(act, other_action, arg)",
    "-- cancels an action entirely", false),
  empty_tree = extract(EMPTY, "local function presume_cured(which)", "-- expose publicly, so an addon", false)
    .. "\n" .. extract(EMPTY, "empty.tree = function ()", "empty.dragonheal = empty.tree", false),
}

local OFFBAL_GUARDED = "if actions.touchtree_misc and not lifevision.l.touchtree_misc then"
local offbal_unguarded, offbal_replaced = blocks.tree_lines:gsub(
  (OFFBAL_GUARDED:gsub("%p", "%%%0")), "if actions.touchtree_misc then")
assert(offbal_replaced == 1, "the guarded condition was not found in touched_treeoffbal")

-- The isadvisables from before the guard, for the controls.
local unguarded = {}
for _, name in ipairs({"touchtree", "shrugging", "dragonheal"}) do
  local replaced
  unguarded[name], replaced = blocks[name]:gsub((GUARDED:gsub("%p", "%%%0")), "if s and m then return true end")
  assert(replaced == 1, "the guarded return was not found in " .. name .. "'s isadvisable")
end

-- ===== Penlight, loaded the way svof ships it =====

for _, mod in ipairs({"utils", "tablex", "List", "class", "Map", "OrderedMap", "pretty", "lexer", "stringx"}) do
  package.preload["pl." .. mod] = function()
    local chunk, err = loadfile(PENLIGHT .. mod .. ".lua")
    -- pretty.lua assigns to a loop variable, which Lua 5.1 allows and 5.4+
    -- refuses to compile. Map only needs it to print a map.
    if not chunk and mod == "pretty" then return { write = tostring } end
    assert(chunk, err)
    chunk()
    return package.loaded["pl." .. mod]
  end
end
local OrderedMap = require("pl.OrderedMap")

-- ===== assertions =====

local failures, checks = {}, 0
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

-- ===== environment =====

local function load_into(env, code, name)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(code, name)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(code, name, "t", env)
  end
  if not chunk then error("failed to load " .. name .. ": " .. tostring(err)) end
  local ok, runerr = pcall(chunk)
  if not ok then error("failed to run " .. name .. ": " .. tostring(runerr)) end
  return runerr
end

-- svof's own table extension, used by gettreeableaffs
local svotable = setmetatable({
  index_of = function(t, value)
    for i, v in ipairs(t) do if v == value then return i end end
  end,
}, { __index = table })

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deepcopy(v) end
  return c
end

-- opts.old: run the isadvisable from before the guard
-- opts.strategies: the strategies left on, default any2affs (svof ships it off)
local function new_svof(opts)
  opts = opts or {}
  local affs, dict = {}, {}
  local svo = {
    affs = affs, affl = affs, dict = dict, tree = {}, shrugging = {}, dragonheal = {}, ignore = {},
    codepaste = {}, defc = { dragonform = opts.dragonform },
    me = { disabledtreefunc = {}, disabledshruggingfunc = {}, disableddragonhealfunc = {}, locks = {} },
    bals = { tree = true, salve = true, sip = true, shrugging = true, dragonheal = true },
    conf = { tree = true, shrugging = true, dragonheal = true, aillusion = true },
    sys = { wait = 1 },
    sk = {},
    es_potions = {},
    actions = OrderedMap(),
    actions_performed = {}, bals_in_use = {},
    deepcopy = deepcopy,
    haveskillset = function() return false end,
    countbrokenlimbs = function() return 0 end,
    havefractures = function() return false end,
    assert = assert,
    debugf = function() end,
  }
  local env = setmetatable({
    svo = svo, affs = affs, dict = dict, bals = svo.bals, conf = svo.conf, me = svo.me, sk = svo.sk,
    defc = svo.defc,
    sys = svo.sys, codepaste = svo.codepaste, empty = {}, table = svotable,
    actions = svo.actions, actions_performed = svo.actions_performed, bals_in_use = svo.bals_in_use,
    debugf = svo.debugf, echof = function() end, make_gnomes_work = function() end,
    syncdelay = function() return 0 end,
    signals = {},
    tempTimer = function() return 1 end, killTimer = function() end,
    createStopWatch = function() return 1 end, startStopWatch = function() end,
    echoLink = function() end,
  }, { __index = _G })

  load_into(env, blocks.actions, "doaction")
  load_into(env, blocks.actionclear, "actionclear")
  load_into(env, blocks.doingaction, "doingaction")
  load_into(env, blocks.codepaste, "codepaste")
  load_into(env, blocks.treeable .. "\nsvo.treecurables = empty.treecurables", "treeable")
  load_into(env, blocks.strats, "strats")
  load_into(env, blocks.shrug_strats, "shrugging strats")
  load_into(env, blocks.dragon_strats, "dragonheal strats")
  function svo.codepaste.balanceful_codepaste() return false end
  local touchtree = load_into(env, opts.old and unguarded.touchtree or blocks.touchtree, "touchtree")
  local shrugging = load_into(env, opts.old and unguarded.shrugging or blocks.shrugging, "shrugging")
  local dragonheal = load_into(env, opts.old and unguarded.dragonheal or blocks.dragonheal, "dragonheal")

  -- the same strategy names are switched on in all three
  local on = {}
  for _, name in ipairs(opts.strategies or {"any2affs"}) do on[name] = true end
  for name in pairs(svo.tree) do svo.me.disabledtreefunc[name] = not on[name] end
  for name in pairs(svo.shrugging) do svo.me.disabledshruggingfunc[name] = not on[name] end
  for name in pairs(svo.dragonheal) do svo.me.disableddragonhealfunc[name] = not on[name] end

  local s = { env = env, svo = svo }

  -- have an affliction, with a count for the counted ones
  function s.aff(name, count)
    dict[name] = dict[name] or { count = count }
    if count then dict[name].count = count end
    affs[name] = { p = dict[name] }
  end

  -- put an action on its way with the real doaction, named the way dict_setup names it
  function s.send(name, balance)
    dict[name] = dict[name] or {}
    local act = { name = name .. "_" .. balance, action_name = name, balance = balance,
      onstart = function() end, oncompleted = function() end }
    dict[name][balance] = act
    svo.doaction(act)
    return act
  end

  -- an affliction line the action system is holding for lifevision
  function s.pending_aff(name)
    dict[name] = dict[name] or {}
    dict[name].aff = { name = name .. "_aff", action_name = name, balance = "aff", oncompleted = function() end }
    svo.checkaction(dict[name].aff, true)
  end

  function s.touch() return touchtree.isadvisable() and true or false end
  function s.shrug() return shrugging.isadvisable() and true or false end
  function s.dragonheal() return dragonheal.isadvisable() and true or false end

  return s
end

-- ===== the empty touch from the log =====

for _, old in ipairs({false, true}) do
  local label = old and "control (before the guard): " or ""

  local s = new_svof({ old = old })
  s.aff("stupidity"); s.aff("asthma")
  s.send("stupidity", "focus"); s.send("asthma", "herb")
  eq(s.touch(), old, label .. "two affs, focus and kelp on their way")

  s = new_svof({ old = old })
  s.aff("stupidity"); s.aff("asthma"); s.aff("clumsiness")
  s.send("stupidity", "focus"); s.send("asthma", "herb")
  eq(s.touch(), true, label .. "three affs, two covered")
end

-- ===== touched as before =====

local s = new_svof()
s.aff("stupidity"); s.aff("asthma")
s.send("stupidity", "focus")
eq(s.touch(), true, "herb off balance, asthma has no cure on its way")

s = new_svof()
s.aff("stupidity"); s.aff("asthma")
eq(s.touch(), true, "nothing sent yet")

-- one kelp is eaten a prompt, so the second kelp aff waits on herb balance
s = new_svof()
s.aff("asthma"); s.aff("clumsiness")
s.send("asthma", "herb")
eq(s.touch(), true, "two kelp affs and one kelp")

s = new_svof()
s.aff("stupidity"); s.aff("asthma"); s.aff("unknownany", 1)
s.send("stupidity", "focus"); s.send("asthma", "herb")
eq(s.touch(), true, "a ? is never covered")

-- focus can be aimed at a mental ?, but it may cure another mental aff instead
s = new_svof()
s.aff("unknownmental", 1); s.aff("asthma")
s.send("unknownmental", "focus"); s.send("asthma", "herb")
eq(s.touch(), true, "a mental ? is never covered, even with focus on its way")

s = new_svof()
s.aff("stupidity"); s.aff("skullfractures", 2)
s.send("stupidity", "focus"); s.send("skullfractures", "sip")
eq(s.touch(), true, "two levels of skull fractures and one sip")

s = new_svof()
s.aff("stupidity"); s.aff("skullfractures", 1)
s.send("stupidity", "focus"); s.send("skullfractures", "sip")
eq(s.touch(), false, "one level of skull fractures and one sip")

s = new_svof({ strategies = {"hardlock"} })
s.aff("asthma"); s.aff("anorexia"); s.aff("slickness")
s.svo.me.locks.hard = true
eq(s.touch(), true, "hard lock, nothing can be sent")

-- only a cure counts, not an affliction being waited on or held for lifevision
s = new_svof({ strategies = {"blackout"} })
s.aff("blackout"); s.aff("stupidity")
s.send("blackout", "waitingfor"); s.send("stupidity", "focus")
eq(s.touch(), true, "blackout's timer is not a cure")

s = new_svof()
s.aff("stupidity"); s.aff("asthma")
s.pending_aff("stupidity"); s.send("asthma", "herb")
eq(s.touch(), true, "an affliction line held for lifevision is not a cure")

-- a cure that is cleared is no longer on its way
s = new_svof()
s.aff("stupidity"); s.aff("asthma")
local focus = s.send("stupidity", "focus"); s.send("asthma", "herb")
eq(s.touch(), false, "both covered before the focus is cleared")
s.svo.actionclear(focus)
eq(s.touch(), true, "stupidity uncovered once its focus is cleared")

-- covered on any cure balance, the misc ones included
s = new_svof()
s.aff("fear"); s.aff("selarnia"); s.aff("voyria"); s.aff("aeon")
s.send("fear", "misc"); s.send("selarnia", "salve"); s.send("voyria", "purgative"); s.send("aeon", "smoke")
eq(s.touch(), false, "misc, salve, purgative and smoke cures all count")

-- the blocks gettreeableaffs applies still apply
s = new_svof()
s.aff("madness"); s.aff("stupidity"); s.aff("confusion")
s.send("madness", "smoke")
eq(s.touch(), false, "madness blocks tree for stupidity and confusion, and madness is covered")

-- the unknown crippled limbs are covered like any other aff: a mending
-- application on its way will cure the arm, whichever it is
s = new_svof()
s.aff("stupidity"); s.aff("unknowncrippledarm", 1)
s.send("stupidity", "focus"); s.send("unknowncrippledarm", "salve")
eq(s.touch(), false, "an unknown crippled arm with mending on its way is covered")

s = new_svof()
s.aff("stupidity"); s.aff("unknowncrippledarm", 2)
s.send("stupidity", "focus"); s.send("unknowncrippledarm", "salve")
eq(s.touch(), true, "two unknown crippled arms and one mending")

-- ===== shrugging and dragonheal: the same guard =====

for _, old in ipairs({false, true}) do
  local label = old and "control (before the guard): " or ""

  s = new_svof({ old = old })
  s.aff("stupidity"); s.aff("asthma")
  s.send("stupidity", "focus"); s.send("asthma", "herb")
  eq(s.shrug(), old, label .. "shrugging, two affs, focus and kelp on their way")

  -- dragonheal's strategies are about locks, not counts: aeon with asthma
  s = new_svof({ old = old, strategies = {"aeon"}, dragonform = true })
  s.aff("aeon"); s.aff("asthma")
  s.send("aeon", "smoke"); s.send("asthma", "herb")
  eq(s.dragonheal(), old, label .. "dragonheal, aeon and asthma, both cures on their way")
end

s = new_svof()
s.aff("stupidity"); s.aff("asthma")
s.send("stupidity", "focus")
eq(s.shrug(), true, "shrugging, asthma has no cure on its way")

s = new_svof({ strategies = {"aeon"}, dragonform = true })
s.aff("aeon"); s.aff("asthma")
s.send("asthma", "herb")
eq(s.dragonheal(), true, "dragonheal, aeon has no cure on its way")

s = new_svof()
s.aff("stupidity")
eq(s.shrug(), false, "shrugging, any2affs with one aff")

-- the checks before the strategies are untouched
s = new_svof({ dragonform = true })
s.aff("stupidity"); s.aff("asthma")
eq(s.shrug(), false, "shrugging, not in dragonform")

s = new_svof({ strategies = {"aeon"} })
s.aff("aeon"); s.aff("asthma")
eq(s.dragonheal(), false, "dragonheal, only in dragonform")

-- ===== the strategy still decides =====

s = new_svof()
s.aff("stupidity")
eq(s.touch(), false, "any2affs with one aff")

s = new_svof({ strategies = {} })
s.aff("stupidity"); s.aff("asthma")
eq(s.touch(), false, "no strategy on")

-- a user's own strategy with nothing svof knows tree cures is left to decide
s = new_svof({ strategies = {"mine"} })
s.svo.tree.mine = { function() return true end }
s.svo.me.disabledtreefunc.mine = false
s.aff("prone")
eq(s.touch(), true, "a custom strategy with no tree-curable affs")

-- the checks before the strategies are untouched
s = new_svof()
s.aff("stupidity"); s.aff("asthma")
s.svo.bals.tree = false
eq(s.touch(), false, "off tree balance")

s = new_svof()
s.aff("stupidity"); s.aff("asthma"); s.aff("paralysis")
eq(s.touch(), false, "paralysed")

-- ===== a doubled touch: the second line must not replace the first =====

-- Loads the tree line handlers into an svof with a touch on its way, and returns
-- the handlers, the entry lifevision holds for tree, and the svof. The touch is
-- the real touchtree action, so s.prompt() can then finish what lifevision
-- holds the way run_through_actions does, in order through actionfinished.
-- GMCP never gates a tree claim, which is neither a gain nor a "gone".
local function doubled(old)
  local s = new_svof()
  local svo, env = s.svo, s.env
  svo.valid = {}
  svo.lifevision = { l = OrderedMap() }
  svo.errorf = function(...) error(string.format(...)) end
  svo.getping = function() return 0.1 end
  env.valid, env.lifevision, env.answer_to = svo.valid, svo.lifevision, function() end
  env.color_table, env.getStopWatchTime = {}, function() return 1 end
  env.send, env.echo = function() end, function() end
  load_into(env, blocks.lifevision_add, "lifevision.add")
  load_into(env, old and offbal_unguarded or blocks.tree_lines, "tree lines")
  load_into(env, blocks.actionfinished, "actionfinished")
  load_into(env, blocks.empty_tree, "empty.tree")
  svo.dict.unknownany, svo.dict.unknownmental = { count = 0 }, { count = 0 }
  -- svo.rmaff's GMCP backstop is the reconciler suite's business. In blackout,
  -- the case that matters here, it removes whatever it is given.
  svo.rmaff = function(which)
    for _, aff in ipairs(type(which) == "table" and which or { which }) do svo.affs[aff] = nil end
  end
  svo.updateaffcount = function() end
  s.tree_balance_taken = 0
  svo.lostbal_tree = function() s.tree_balance_taken = s.tree_balance_taken + 1 end
  svo.dict.touchtree = load_into(env, blocks.touchtree_entry, "touchtree action").touchtree
  local act = svo.dict.touchtree.misc
  act.name, act.action_name, act.balance = "touchtree_misc", "touchtree", "misc"
  svo.doaction(act)
  function s.prompt()
    for _, claim in svo.lifevision.l:iter() do svo.actionfinished(claim.p, claim.other_action, claim.arg) end
    svo.lifevision.l = OrderedMap()
  end
  return svo.valid, function() return svo.lifevision.l.touchtree_misc end, s
end

for _, old in ipairs({false, true}) do
  local label = old and "control (before the guard): " or ""

  -- the paragraph from the log: the first touch cures voyria, the second is off balance
  local valid, entry, s = doubled(old)
  s.aff("voyria")
  valid.tree1()
  valid.tree_cured("voyria")
  valid.tree2()
  valid.touched_treeoffbal()
  eq(entry().other_action, old and "offbal" or nil, label .. "a cure then an off-balance touch: the outcome")
  eq(entry().arg, (not old) and "voyria" or nil, label .. "a cure then an off-balance touch: what tree cured")
  -- and at the prompt, in blackout, where only the cure line can remove it
  s.aff("blackout")
  s.prompt()
  eq(s.svo.affs.voyria == nil, not old, label .. "a cure then an off-balance touch, in blackout: voyria is removed")
  eq(s.tree_balance_taken, 1, label .. "a cure then an off-balance touch: tree balance is taken once")

  -- the first touch cures nothing: its empty result is kept too
  valid, entry, s = doubled(old)
  s.aff("asthma")
  valid.tree1()
  valid.tree2()
  valid.touched_treeoffbal()
  eq(entry().other_action, old and "offbal" or "empty", label .. "an empty touch then an off-balance touch")
  -- and at the prompt it rules out what tree cures, asthma among them
  s.prompt()
  eq(s.svo.affs.asthma == nil, not old, label .. "an empty touch then an off-balance touch: asthma is ruled out")
  eq(s.tree_balance_taken, 1, label .. "an empty touch then an off-balance touch: tree balance is taken once")
end

-- a lone off-balance touch is recorded as before
local valid, entry
valid, entry, s = doubled(false)
s.aff("asthma")
valid.touched_treeoffbal()
eq(entry() and entry().other_action, "offbal", "an off-balance touch on its own")
s.prompt()
eq(s.svo.affs.asthma ~= nil, true, "an off-balance touch on its own: rules nothing out")
eq(s.tree_balance_taken, 1, "an off-balance touch on its own: tree balance is taken once")

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
