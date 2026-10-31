--[[
Logic-level regression test for the paragraph lookbacks in
`src/scripts/svo (setup, misc, empty, funnies, dor)/Miscellaneous_functions.lua`:
svo.find_until_last_paragraph, svo.count_until_last_paragraph,
svo.paragraph_so_far and svo.previous_paragraph_line, with the line they're
fed from, the Prompt trigger's condition in
`src/triggers/svo (aliases, triggers)/svo/General/triggers.json`.

Same approach as tools/test_bare_dict.lua: the code under test is extracted
from the real source files by anchor text and executed in a stub environment,
so it is a substring of what ships rather than a reimplementation, and the
test fails loudly if the anchors move instead of silently testing stale logic.

What it covers: the lookbacks read Mudlet's buffer with getLines(), and the
buffer isn't what the game sent. svof's own warning ("(breathrain inc)") is
echoed onto lines, and a line longer than the profile's "Wrap lines at" is
cut into several, so an exact lookback missed a line that was there: the
2026-09-26 false sensitivity. Now the Prompt trigger's condition saves each
line as it arrives, and the lookbacks search that.

The buffer here follows Mudlet's source, as the
svof-warning-suffix-breaks-lookbacks notes record it: a line's permanent
triggers run first, then the temporary ones, where svof's warning echoes onto
the line; then the line is wrapped into separate buffer lines.
getLines(from, to) leaves out line `to`, and while a line is processed it is
the last line in the buffer. Echoes outside a trigger add buffer lines no
trigger sees.

Things it pins, each against controls that put getLines() back (the
functions from in-client-svof, run over the same buffer):

  * a line with svof's warning suffix is found exactly.
  * a line cut at wrap 80 is found exactly, and a substring across the cut
    is found. At wrap 100 nothing is cut, and both versions agree.
  * a trigger never finds its own line, whether it runs before the Prompt
    trigger or after it, and a second identical line finds the first, which
    hypochondria's duplicate check needs.
  * at the prompt every line is found, and the previous prompt and svof's
    own echoes are not.
  * outside a trigger, the last line is left out, as getLines() left it out.
  * counts, the previous line, and the reset at the prompt.

It proves nothing about Mudlet itself; the live wrap test in
svof-live-testing covers that.

Run: lua tools/test_paragraph_lookbacks.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local MISC = "src/scripts/svo (setup, misc, empty, funnies, dor)/Miscellaneous_functions.lua"
local TRIGGERS = "src/triggers/svo (aliases, triggers)/svo/General/triggers.json"
local CONTROLLERS = "src/scripts/svo (curing skeleton, controllers, action system)/Controllers.lua"

local START = "function svo.note_paragraph_line()"

local END = "  return count\nend"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  -- a Windows checkout may have CRLF; the anchors are written with LF
  return (data:gsub("\r\n", "\n"))
end

local function between(source, path, start, finish)
  local s = source:find(start, 1, true)
  if not s then error("start anchor " .. start .. " not found in " .. path .. "; update this test's anchors") end
  local e = source:find(finish, s, true)
  if not e then error("end anchor not found in " .. path .. "; update this test's anchors") end
  return source:sub(s, e + #finish - 1)
end

local function compile(block, chunkname, env)
  -- Mudlet runs Lua 5.1, where only loadstring() takes a source string and
  -- the environment is applied with setfenv. Branch on setfenv rather than on
  -- a version string so this runs under either.
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block, chunkname)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block, chunkname, "t", env)
  end
  if not chunk then error("could not load " .. chunkname .. ": " .. tostring(err)) end
  return chunk
end

local new_block = between(read_file(MISC), MISC, START, END)

-- The controls: the getLines() versions, as in-client-svof had them before
-- the saved copy (e4904d5), copied here because a CI checkout may have no
-- other branch to read them from
local old_block = [[
function svo.find_until_last_paragraph (pattern, type)
  local t = getLines(svo.lastpromptnumber, getLastLineNumber('main'))

  local find = string.find
  for i = 1, #t do
    local line = t[i]

    if type == 'exact' and line == pattern then return true
    elseif type == 'pattern' and find(line, pattern) then return true
    elseif type == 'substring' and find(line, pattern, 1, true) then return true end
  end

  return false
end

function svo.count_until_last_paragraph (pattern, type)
  local t = getLines(svo.lastpromptnumber, getLastLineNumber('main'))

  local find, count = string.find, 0
  for i = 1, #t do
    local line = t[i]

    if type == 'exact' and line == pattern then count = count + 1
    elseif type == 'pattern' and find(line, pattern) then count = count + 1
    elseif type == 'substring' and find(line, pattern, 1, true) then count = count + 1 end
  end

  return count
end
]]

-- the Prompt trigger's condition, the Lua pattern of the trigger named Prompt
local condition = read_file(TRIGGERS):match('"name": "Prompt",.-"pattern": "(if isPrompt%(%).-)",')
if not condition then error("the Prompt trigger's condition not found in " .. TRIGGERS) end
condition = condition:gsub('\\"', '"')

-- svo.onprompt has to clear the saved lines where it resets the count
local controllers = read_file(CONTROLLERS)
local reset_found = controllers:find("  svo.paragraph_length = 0\n  svo.paragraph_lines = {}\n", 1, true) ~= nil

local checks, failures = 0, 0
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", desc, tostring(got), tostring(want)))
  end
end

check("svo.onprompt clears the saved lines with the count", reset_found, true)

-- A Mudlet stand-in. Buffer line numbers start at 0, as Mudlet's do.
local function new_world(wrap)
  local w = {buffer = {}, wrap = wrap, prompt = false}
  local svo = {paragraph_length = 0, paragraph_lines = {}, lastpromptnumber = 0}
  w.svo = svo
  local env = {svo = svo, string = string, table = table, ipairs = ipairs}
  w.env = env
  function env.getLastLineNumber() return #w.buffer - 1 end
  function env.getLineNumber() return #w.buffer - 1 end
  function env.getLines(from, to)
    local t = {}
    for i = from, to - 1 do if w.buffer[i + 1] then t[#t + 1] = w.buffer[i + 1] end end
    return t
  end
  function env.isPrompt() return w.prompt end
  compile(new_block, "lookbacks under test", env)()
  w.new = {find = svo.find_until_last_paragraph, count = svo.count_until_last_paragraph,
    so_far = svo.paragraph_so_far, previous = svo.previous_paragraph_line}
  local old_svo = setmetatable({}, {__index = svo})
  local old_env = setmetatable({svo = old_svo}, {__index = env})
  compile(old_block, "getLines lookbacks", old_env)()
  w.old = {find = old_svo.find_until_last_paragraph, count = old_svo.count_until_last_paragraph}
  w.condition = compile(condition, "Prompt condition", env)
  return w
end

-- One line from the game. before and after are triggers that run before and
-- after the Prompt trigger; warning is svof's suffix, echoed by a temp
-- trigger after both.
local function arrive(w, text, opts)
  opts = opts or {}
  w.buffer[#w.buffer + 1] = text
  w.env.line = text
  w.prompt = false
  if opts.before then opts.before() end
  w.condition()
  if opts.after then opts.after() end
  if opts.warning then w.buffer[#w.buffer] = w.buffer[#w.buffer] .. opts.warning end
  -- wrap: the last buffer line cut into pieces of w.wrap
  local last = table.remove(w.buffer)
  repeat
    w.buffer[#w.buffer + 1] = last:sub(1, w.wrap)
    last = last:sub(w.wrap + 1)
  until last == ""
end

-- The prompt: the condition says it's a prompt, svo.onprompt runs the
-- lookbacks given in at, then resets as Controllers.lua does
local function prompt(w, at)
  w.buffer[#w.buffer + 1] = "1000h, 1000m ex-"
  w.env.line = w.buffer[#w.buffer]
  w.prompt = true
  check("the condition says the prompt is one", w.condition(), true)
  if at then at() end
  w.svo.lastpromptnumber = #w.buffer - 1
  w.svo.paragraph_length = 0
  w.svo.paragraph_lines = {}
end

local function echo_line(w, text) w.buffer[#w.buffer + 1] = text end

local HEARING = "Your hearing is suddenly restored."
-- 92 characters, so cut at wrap 80 and whole at 100. ACROSS straddles the cut
local LONG = "Spinning to the right as Alex draws a scimitar from its sheath, he slashes across your arms."
local ACROSS = LONG:sub(76, 85)

-- 1. svof's warning suffix
do
  local w = new_world(100)
  prompt(w)
  arrive(w, HEARING, {warning = "                       (breathrain inc)"})
  prompt(w, function()
    check("a line with svof's warning is found exactly", w.new.find(HEARING, 'exact'), true)
    check("control: getLines() missed it", w.old.find(HEARING, 'exact'), false)
  end)
end

-- 2. wrap
for _, wrap in ipairs({80, 100}) do
  local w = new_world(wrap)
  prompt(w)
  arrive(w, LONG)
  prompt(w, function()
    check("wrap " .. wrap .. ": the long line is found exactly", w.new.find(LONG, 'exact'), true)
    check("wrap " .. wrap .. ": a substring across 80 is found", w.new.find(ACROSS, 'substring'), true)
    local cut = #LONG > wrap
    check("wrap " .. wrap .. ": control: getLines() found it exactly only uncut", w.old.find(LONG, 'exact'), not cut)
    check("wrap " .. wrap .. ": control: getLines() found the substring only uncut", w.old.find(ACROSS, 'substring'), not cut)
  end)
end

-- 3. a trigger's own line, before and after the Prompt trigger, and a
-- duplicate
do
  local w = new_world(80)
  prompt(w)
  local own_before, own_after, first_dup, second_dup
  arrive(w, HEARING, {
    before = function() own_before = w.new.find(HEARING, 'exact') end,
    after = function() own_after = w.new.find(HEARING, 'exact') end,
  })
  check("a trigger before the Prompt trigger doesn't find its own line", own_before, false)
  check("a trigger after the Prompt trigger doesn't find its own line", own_after, false)
  arrive(w, "You feel sick.", {after = function() first_dup = w.new.find("You feel sick.", 'exact') end})
  arrive(w, "You feel sick.", {after = function() second_dup = w.new.find("You feel sick.", 'exact') end})
  check("the first of two identical lines finds none", first_dup, false)
  check("the second finds the first", second_dup, true)
  local prev_first, prev_second
  arrive(w, LONG, {after = function() prev_first = w.new.previous() end})
  arrive(w, HEARING, {before = function() prev_second = w.new.previous() end})
  check("the previous line is the game's last line", prev_first, "You feel sick.")
  check("the previous line of a wrapped one is whole", prev_second, LONG)
end

-- 4. at the prompt: the previous prompt and svof's echoes are out
do
  local w = new_world(80)
  prompt(w)
  arrive(w, "Alex viciously jabs a rapier into Quinn.")
  echo_line(w, "(svof): you are stunned, waiting")
  local first_previous
  arrive(w, "Your hearing is suddenly restored.", {after = function() first_previous = w.new.previous() end})
  check("the previous line skips svof's echo", first_previous, "Alex viciously jabs a rapier into Quinn.")
  prompt(w, function()
    check("at the prompt, the last line is found", w.new.find(HEARING, 'exact'), true)
    check("svof's own echo isn't found", w.new.find("(svof)", 'substring'), false)
    check("control: getLines() found svof's echo", w.old.find("(svof)", 'substring'), true)
    check("the previous prompt isn't found", w.new.find("1000h", 'substring'), false)
    check("control: getLines() found the previous prompt", w.old.find("1000h", 'substring'), true)
    check("'you' isn't found in svof's echo alone", w.new.find("you", 'substring'), false)
    check("control: getLines() found 'you' in svof's echo", w.old.find("you", 'substring'), true)
    check("two lines so far", #w.new.so_far(), 2)
  end)
  check("the prompt clears the saved lines", #w.svo.paragraph_lines, 0)
  local first
  arrive(w, HEARING, {after = function() first = w.new.previous() end})
  check("the first line's previous line is empty", first, "")
end

-- 5. outside a trigger, the last line is left out, as getLines() left it
do
  local w = new_world(100)
  prompt(w)
  arrive(w, "Alex jabs you.")
  arrive(w, HEARING)
  check("outside a trigger, the last line is left out", w.new.find(HEARING, 'exact'), false)
  check("control: getLines() left it out too", w.old.find(HEARING, 'exact'), false)
  check("outside a trigger, an earlier line is found", w.new.find("Alex jabs you.", 'exact'), true)
end

-- 6. counts
do
  local w = new_world(80)
  prompt(w)
  arrive(w, "Alex balls up one fist and hammerfists you.")
  arrive(w, "Alex balls up one fist and hammerfists you.")
  arrive(w, LONG)
  prompt(w, function()
    check("two hits are counted", w.new.count("balls up one fist and hammerfists you", 'substring'), 2)
    check("a pattern finds the long line", w.new.find("^Spinning to the right as %w+ draws", 'pattern'), true)
    check("a long line is counted once", w.new.count(LONG, 'exact'), 1)
  end)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
