--[[
Logic-level test for the two ways svof kept a ? (an unknown affliction) that
was already accounted for. Both were found in a captured fight against rats,
whose venom hides what it gives ("You are confused as to the effects of the
venom."):

1. A defence that absorbs the hidden venom takes its unknown back off:
   "Your insulating unguent dissolves as it ameliorates the extreme cold."
   GMCP's defence Remove arrives before that text, so caloric_gone was
   already queued ahead of the venom's unknown, and took one off a count
   still at 0. Same for insomnia.
2. The game revealing a hidden affliction over GMCP, with its symptom. The
   Add handler put it in affs before the symptom's line arrived, so the
   symptom triggers saw it as already known and left its ? alone.

Like the other suites, this does not run svof or Mudlet. It extracts the real
code by anchor text and runs it under stubs: the GMCP handlers, lifevision's
queue and validate, the action system's checkaction and actionfinished, the
affliction bookkeeping, the dictionary's own unknownany, unknownmental,
caloric and insomnia entries, the defence lost_ generator, the trigger
functions, the symptom trigger scripts, and Penlight's OrderedMap, whose
"a key keeps its place" behaviour bug 1 hinges on. Only dict_setup's three
naming lines and the svotossa name map are written out here.

Every case runs twice: before GMCP is live, and live, the way a player is
after the login List, with the GMCP gate in lifevision and the add and remove
backstops on. A first check shows which of the two each run is in.

The controls run the same scenarios with the code from before the fix, so
the scenarios are shown to reproduce both bugs.

Run: lua tools/test_phantom_unknowns.lua
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

local SETUP = "src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua"
local SKELETON = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"
local ACTIONS = "src/scripts/svo (curing skeleton, controllers, action system)/Action_system.lua"
local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local DEFENCES = "src/scripts/svo (alias and defence functions)/Defences.lua"
local TRIGGERS = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"
local SIMPLE = "src/scripts/svo (trigger functions)/Simple_aff_trigger_functions.lua"
local SYMPTOMS = "src/triggers/svo (aliases, triggers)/svo/General/Symptoms/"
local PENLIGHT = "src/scripts/svo (core)/3rdparty/Penlight/"

local blocks = {
  gmcp = extract(SETUP,
    "signals.gmcpcharafflictionslist = signals.gmcpcharafflictionslist or luanotify.signal.new()",
    "end, 'update list of defs from gmcp')", false) .. "end, 'update list of defs from gmcp')",
  prompt = extract(SKELETON, "function sk.onprompt_beforeaction_add(name, what)",
    "signals.after_lifevision_processing:connect(sk.onprompt_beforeaction_do", false),
  lifevision_add = extract(SKELETON, "function svo.lifevision.add(what, other_action, arg, lineguard)",
    "function svo.lifevision.addcust", false),
  validate = extract(SKELETON, "local function run_through_actions()", "sys.lineguard = false", true),
  bookkeeping = extract(SKELETON, "svo.updateaffcount = function (which)",
    "-- public version of removeaff.", false),
  actions = extract(ACTIONS, "svo.checkaction = function (act, input)", "-- cancels an action entirely", false),
  addunknownany = extract(DICT, "codepaste.addunknownany = function(amount)",
    "svo.updateaffcount(svo.dict.unknownany)", true),
  dict = "return {\n"
    .. extract(DICT, "    unknownany = {", "    unknownmental = {", false)
    .. extract(DICT, "    unknownmental = {", "    unknowncrippledlimb = {", false)
    .. extract(DICT, "    insomnia = {", "    myrrh = {", false)
    .. extract(DICT, "    caloric = {", "    blind = {", false)
    .. "}",
  lost_defs = "for _, defname in ipairs(defnames) do\n"
    .. extract(DEFENCES, "    if not defs['lost_' .. sk.sanitize(defname)] then",
      "    if not defdata.nodef and not defdata.custom_def_type then", false)
    .. "end",
  absorbed = extract(TRIGGERS, "-- A defence that absorbed the hidden venom", "if svo.haveskillset('elementalism') then", false),
  remove_unknown = extract(TRIGGERS, "-- remove unknown level if the affliction from a symptom was not present before",
    "function svo.valid.loki()", false),
  simple_loop = "do\n" .. extract(SIMPLE, "  -- Derived from the dictionary instead of listed here.", "svo.valid.simplehoisted", false),
  simple_unknowns = extract(SIMPLE, "svo.valid.simpleunknownany = function (number)",
    "for _, affname in ipairs({'skullfractures', 'crackedribs', 'wristfractures', 'torntendons'}) do", false),
}

for _, name in ipairs({"Paralysis", "Anorexia", "Weakness", "Clumsiness"}) do
  blocks["symptom_" .. name] = read_file(SYMPTOMS .. name .. ".lua")
end

-- The code before this fix, for the controls.
local OLD_ABSORBED = [[
function svo.valid.stripped_caloric()
  svo.checkaction(svo.dict.caloric.gone, true)
  if actions.unknownany_aff then
    lifevision.add(actions.caloric_gone.p, nil, 'unknownany')
  elseif actions.unknownmental_aff then
    lifevision.add(actions.caloric_gone.p, nil, 'unknownmental')
  else
    lifevision.add(actions.caloric_gone.p)
  end
end
]]
local OLD_REMOVE_UNKNOWN = [[
valid.remove_unknownmental = function (affliction)
  if affs[affliction] then return end

  if affliction and affs.unknownmental then sk.gmcp_vouched[affliction] = true end
  svo.checkaction(svo.dict.unknownmental.gone, true)
  lifevision.add(actions.unknownmental_gone.p, 'lost_level')
end
valid.remove_unknownany = function (affliction)
  if affs[affliction] then return end

  if affliction and affs.unknownany then sk.gmcp_vouched[affliction] = true end
  svo.checkaction(svo.dict.unknownany.gone, true)
  lifevision.add(actions.unknownany_gone.p, 'lost_level')
end
valid.remove_revealed_unknown = function () end
]]

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
local LIVE = false
local function eq(actual, expected, label)
  checks = checks + 1
  label = (LIVE and "[gmcp live] " or "[gmcp not live] ") .. label
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

local function signal()
  local fns = {}
  return {
    connect = function(self, fn) fns[#fns + 1] = fn end,
    emit = function(self, ...) for _, fn in ipairs(fns) do fn(...) end end,
    unblock = function() end,
  }
end

-- opts.old_absorbed / opts.old_remove run the pre-fix code instead.
local function new_svof(opts)
  opts = opts or {}
  local svo = {
    affs = {}, affl = {}, gaffl = {}, gdefc = {}, defc = {}, defs = {}, me = {},
    conf = { aillusion = false, gmcpaffechoes = false, gmcpdefechoes = false, serverside = false },
    sk = { gmcp_cured = {}, gmcp_revealed = {}, onpromptfuncs = {} },
    valid = {}, lifevision = {}, codepaste = {}, reset = {},
    stats = { currenthealth = 4000, maxhealth = 4692, currentmana = 4000, maxmana = 4380 },
    dict = { sstosvoa = {}, sstosvod = {}, svotossa = {}, svotossd = {} },
    pl = { OrderedMap = OrderedMap },
  }
  svo.actions = OrderedMap()
  svo.lifevision.l = OrderedMap()
  svo.sys = { lineguard = false }
  svo.sk.gmcp_affs_listed = LIVE
  svo.getping = function() return 0.1 end
  svo.promptcount = 1
  local lost_defences = {}
  svo.defences = { lost = function(name) lost_defences[#lost_defences + 1] = name end, got = function() end }
  local signals = {
    svogotaff = signal(), svolostaff = signal(), changecuring = signal(),
    after_lifevision_processing = signal(), curedwith_focus = signal(),
  }
  for _, s in ipairs({"afflictionslist", "afflictionsremove", "afflictionsadd",
                      "defenceslist", "defencesremove", "defencesadd"}) do
    signals["gmcpchar" .. s] = signal()
  end
  local gmcp = { Char = { Afflictions = {}, Defences = {} } }

  function svo.assert(v, msg) if not v then error(msg or "assertion failed", 2) end return v end
  function svo.echof() end
  function svo.debugf() end
  function svo.deepcopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = svo.deepcopy(v) end
    return r
  end
  function svo.sk.checkaeony() end
  function svo.sk.sanitize(s) return s end
  function svo.codepaste.badaeon() end
  function svo.haveskillset() return false end
  svo.sk.sawcuring = function() return false end
  svo.paragraph_length = 1

  local env = {
    svo = svo, sk = svo.sk, conf = svo.conf, sys = svo.sys, me = svo.me, stats = svo.stats,
    affs = svo.affs, defc = svo.defc, defs = svo.defs, gaffl = svo.gaffl, valid = svo.valid,
    actions = svo.actions, lifevision = svo.lifevision, codepaste = svo.codepaste,
    defences = svo.defences, signals = signals, gmcp = gmcp, cnrl = {},
    luanotify = { signal = { new = signal } },
    pl = svo.pl, bals_in_use = {}, actions_performed = {},
    debugf = svo.debugf, make_gnomes_work = function() end,
    defnames = {"caloric", "insomnia"},
    -- Mudlet
    raiseEvent = function() end, createStopWatch = function() return 0 end,
    startStopWatch = function() end, stopStopWatch = function() return 0 end,
    echo = function() end, echoLink = function() end, tempTimer = function() end,
    decho = function() end,
    -- stdlib
    string = string, table = table, tonumber = tonumber, tostring = tostring, type = type,
    pairs = pairs, ipairs = ipairs, next = next, select = select, pcall = pcall,
    error = error, setmetatable = setmetatable, debug = debug, math = math,
  }
  env._G = env

  -- the dictionary's own entries, named the way dict_setup names them
  local entries = load_into(env, blocks.dict, "dictionary entries")
  for key, entry in pairs(entries) do
    svo.dict[key] = entry
    entry.name = entry.name or key
    for sub, data in pairs(entry) do
      if type(data) == "table" then
        data.name = data.name or (key .. "_" .. sub)
        data.balance = data.balance or sub
        data.action_name = data.action_name or key
      end
    end
  end
  for _, aff in ipairs({"paralysis", "anorexia", "weakness", "clumsiness", "crippledrightleg"}) do
    svo.dict[aff] = { name = aff, aff = { name = aff .. "_aff", balance = "aff", action_name = aff,
      oncompleted = function() svo.addaffdict(svo.dict[aff]) end } }
  end
  svo.dict.anorexia.focus = { name = "anorexia_focus" } -- focus cures anorexia
  svo.dict.sstosvoa = { paralysis = "paralysis", anorexia = "anorexia", weariness = "weakness",
    clumsiness = "clumsiness", brokenrightleg = "crippledrightleg" }
  svo.dict.sstosvod = { insulation = "caloric", insomnia = "insomnia" }
  -- svof name -> GMCP name: how the GMCP gate knows GMCP can report an affliction
  svo.dict.svotossa = {}
  for gname, sname in pairs(svo.dict.sstosvoa) do svo.dict.svotossa[sname] = gname end

  for _, name in ipairs({"prompt", "lifevision_add", "validate", "bookkeeping", "actions",
                         "addunknownany", "lost_defs", "gmcp", "simple_loop", "simple_unknowns"}) do
    load_into(env, blocks[name], name)
  end
  load_into(env, opts.old_absorbed and OLD_ABSORBED or blocks.absorbed, "absorbed")
  load_into(env, opts.old_remove and OLD_REMOVE_UNKNOWN or blocks.remove_unknown, "remove_unknown")

  local s = { svo = svo, env = env, gmcp = gmcp, signals = signals, lost_defences = lost_defences }

  -- the game's side of things
  function s.gmcp_add(name)
    gmcp.Char.Afflictions.Add = { name = name }
    signals.gmcpcharafflictionsadd:emit()
  end
  function s.gmcp_lost_def(name)
    gmcp.Char.Defences.Remove = { name }
    signals.gmcpchardefencesremove:emit()
  end
  function s.trigger(name) load_into(env, blocks["symptom_" .. name], name .. " trigger") end
  function s.prompt()
    svo.lifevision.validate()
    svo.sk.onprompt_beforeaction_do()
  end
  function s.unknowns() return svo.affs.unknownany and svo.dict.unknownany.count or 0 end
  function s.mental_unknowns() return svo.affs.unknownmental and svo.dict.unknownmental.count or 0 end
  -- a ? already held from an earlier venom
  function s.hold_unknowns(n)
    svo.valid.simpleunknownany(n)
    s.prompt()
  end
  return s
end

local function cases()
-- The GMCP gate is on only once GMCP is live: a paralysis line GMCP doesn't back is refused
do
  local s = new_svof()
  s.svo.valid.simpleparalysis()
  s.prompt()
  eq(s.svo.affs.paralysis ~= nil, not LIVE, "the gate refuses a claim GMCP doesn't back only when live")
end

-- ===== bug 1: insulation absorbs the hidden venom =====

-- The log: "Lost def insulation" over GMCP, the venom, then the unguent line.
local function insulation_case(opts)
  local s = new_svof(opts)
  s.gmcp_lost_def("insulation")
  s.svo.valid.simpleunknownany()           -- You are confused as to the effects of the venom.
  s.svo.valid.stripped_caloric()           -- Your insulating unguent dissolves...
  s.prompt()
  return s
end

do
  local s = insulation_case()
  eq(s.unknowns(), 0, "insulation, GMCP first: the absorbed venom leaves no ?")
  eq(s.svo.affs.unknownany, nil, "insulation, GMCP first: unknownany is not tracked")
  eq(s.lost_defences[1], "caloric", "insulation, GMCP first: the defence is still lost")
  eq(#s.lost_defences, 1, "insulation, GMCP first: and lost once")

  local old = insulation_case({ old_absorbed = true })
  eq(old.unknowns(), 1, "control: before the fix, the absorbed venom's ? stayed")
end

-- Two venoms, insulation absorbs one: one ? stays.
do
  local s = new_svof()
  s.gmcp_lost_def("insulation")
  s.svo.valid.simpleunknownany()
  s.svo.valid.simpleunknownany()
  s.svo.valid.stripped_caloric()
  s.prompt()
  eq(s.unknowns(), 1, "two venoms, one absorbed: one ? stays")
end

-- The unguent line between the two venom lines, as in the log's third case.
do
  local s = new_svof()
  s.gmcp_lost_def("insulation")
  s.svo.valid.simpleunknownany()
  s.svo.valid.stripped_caloric()
  s.svo.valid.simpleunknownany()
  s.prompt()
  eq(s.unknowns(), 1, "venom, unguent, venom: one ? stays")
end

-- An unknown mental venom is handled the same way.
do
  local s = new_svof()
  s.gmcp_lost_def("insulation")
  s.svo.valid.simpleunknownmental()
  s.svo.valid.stripped_caloric()
  s.prompt()
  eq(s.mental_unknowns(), 0, "insulation absorbs an unknown mental venom: no ? stays")
end

-- Text only, no GMCP defence Remove: this worked before and still does.
do
  local s = new_svof()
  s.svo.valid.simpleunknownany()
  s.svo.valid.stripped_caloric()
  s.prompt()
  eq(s.unknowns(), 0, "insulation, text only: the absorbed venom leaves no ?")
end

-- No venom in the paragraph: an earlier ? is not touched.
do
  local s = new_svof()
  s.hold_unknowns(1)
  s.gmcp_lost_def("insulation")
  s.svo.valid.stripped_caloric()
  s.prompt()
  eq(s.unknowns(), 1, "insulation gone without a venom: the earlier ? stays")
  eq(s.lost_defences[1], "caloric", "insulation gone without a venom: the defence is lost")
end

-- insomnia has the same shape
do
  local s = new_svof()
  s.gmcp_lost_def("insomnia")
  s.svo.valid.simpleunknownany()
  s.svo.valid.stripped_insomnia()
  s.prompt()
  eq(s.unknowns(), 0, "insomnia, GMCP first: the absorbed venom leaves no ?")
  eq(s.lost_defences[1], "insomnia", "insomnia, GMCP first: the defence is lost")
end

-- ===== bug 2: GMCP reveals a hidden affliction with its symptom =====

-- The log: a ? held, then "stand" fails with "You are paralysed and unable to
-- do that.", and GMCP's Add for paralysis comes with it.
local function reveal_case(opts, gmcpname, trigger, svoname)
  local s = new_svof(opts)
  s.hold_unknowns(1)
  s.gmcp_add(gmcpname)
  s.env.svo.valid.symp_paralysis = function() s.svo.valid.simpleparalysis() end
  s.env.svo.valid.symp_anorexia = function() s.svo.valid.simpleanorexia() end
  s.trigger(trigger)
  s.prompt()
  eq(s.svo.affs[svoname] ~= nil, true, trigger .. ": the revealed affliction is tracked")
  return s
end

do
  local s = reveal_case(nil, "paralysis", "Paralysis", "paralysis")
  eq(s.unknowns(), 0, "paralysis revealed by GMCP: its ? is taken off")
  eq(next(s.svo.sk.gmcp_revealed), nil, "paralysis revealed by GMCP: the record is gone after the prompt")

  local old = reveal_case({ old_remove = true }, "paralysis", "Paralysis", "paralysis")
  eq(old.unknowns(), 1, "control: before the fix, the revealed paralysis' ? stayed")
end

do
  local s = reveal_case(nil, "weariness", "Weakness", "weakness")
  eq(s.unknowns(), 0, "weariness revealed by GMCP: its ? is taken off, under svof's name")
end

do
  local s = reveal_case(nil, "anorexia", "Anorexia", "anorexia")
  eq(s.unknowns(), 0, "anorexia revealed by GMCP: its ? is taken off")
end

-- One of the eight symptom triggers that already took a ? off: it skipped
-- whenever GMCP's Add came first, which is always.
do
  local s = reveal_case(nil, "clumsiness", "Clumsiness", "clumsiness")
  eq(s.unknowns(), 0, "clumsiness revealed by GMCP: the existing trigger now takes its ? off")

  local old = reveal_case({ old_remove = true }, "clumsiness", "Clumsiness", "clumsiness")
  eq(old.unknowns(), 1, "control: before the fix, the existing trigger left it")
end

-- Focus cures anorexia, so an unknown mental affliction is used up first.
do
  local s = new_svof()
  s.hold_unknowns(1)
  s.svo.addaffdict(s.svo.dict.unknownmental)
  s.svo.dict.unknownmental.count = 1
  s.gmcp_add("anorexia")
  s.env.svo.valid.symp_anorexia = function() s.svo.valid.simpleanorexia() end
  s.trigger("Anorexia")
  s.prompt()
  eq(s.mental_unknowns(), 0, "anorexia revealed with both kinds held: the mental ? goes")
  eq(s.unknowns(), 1, "anorexia revealed with both kinds held: the other ? stays")
end

-- A new affliction from an attack also arrives as an Add while a ? is held.
-- With no symptom line, the ? stays: it is still something else.
do
  local s = new_svof()
  s.hold_unknowns(1)
  s.gmcp_add("brokenrightleg")
  s.svo.valid.simplecrippledrightleg()      -- Your right leg breaks with a loud crack.
  s.prompt()
  eq(s.unknowns(), 1, "a visible new affliction while a ? is held: the ? stays")
  eq(next(s.svo.sk.gmcp_revealed), nil, "a visible new affliction: the record is gone after the prompt")
end

-- A symptom of an affliction svof already knew: the ? is something else.
do
  local s = new_svof()
  s.hold_unknowns(1)
  -- tracked the way a diagnose files it, with GMCP standing aside
  s.svo.gmcp_set_aside(s.svo.addaffdict, s.svo.dict.paralysis)
  s.gmcp_add("paralysis")
  s.env.svo.valid.symp_paralysis = function() end
  s.trigger("Paralysis")
  s.prompt()
  eq(s.unknowns(), 1, "a symptom of an affliction svof already tracked: the ? stays")
end

-- No ? held: nothing is recorded and nothing is taken off.
do
  local s = new_svof()
  s.gmcp_add("paralysis")
  eq(s.svo.sk.gmcp_revealed.paralysis, nil, "no ? held: the Add records no reveal")
  s.env.svo.valid.symp_paralysis = function() s.svo.valid.simpleparalysis() end
  s.trigger("Paralysis")
  s.prompt()
  eq(s.unknowns(), 0, "no ? held: still none")
  eq(s.svo.affs.paralysis ~= nil, true, "no ? held: paralysis is tracked")
end

-- The symptom line without GMCP, as in blackout: the new triggers change nothing.
do
  local s = new_svof()
  s.hold_unknowns(1)
  s.env.svo.valid.symp_paralysis = function() s.svo.valid.simpleparalysis() end
  s.trigger("Paralysis")
  s.prompt()
  eq(s.unknowns(), 1, "a paralysis symptom with no GMCP: the ? stays, as before")
end

-- A reveal in one paragraph does not carry over to a symptom in the next.
do
  local s = new_svof()
  s.hold_unknowns(2)
  s.gmcp_add("paralysis")
  s.prompt()
  s.env.svo.valid.symp_paralysis = function() end
  s.trigger("Paralysis")
  s.prompt()
  eq(s.unknowns(), 2, "a reveal does not reach a symptom on a later prompt")
end

end
for _, live in ipairs({false, true}) do LIVE = live; cases() end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
