local t = {
  ["like an open eye"] = {
    rune = "wunjo", effect = "cure blind"},
  ["that looks like a stick man"] = {
    rune = "inguz", effect = "paralysis"},
  ["shaped like a butterfly"] = {
    rune = "nairat", effect = "entangle"},
  ["like a closed eye"] = {
    rune = "fehu", effect = function()
      if not svo.fehu or svo.fehu == 3 then svo.fehu = 1 return "strip insomnia"
      elseif svo.fehu == 1 then svo.fehu = 2 return "sleep"
      elseif svo.fehu == 2 then svo.fehu = 3 return "strip kola" end
    end
  },
  ["resembling a bell"] = {
    rune = "mannaz", effect = "cure deaf"},
  ["that looks like a nail"] = {
    rune = "sowulu", effect = "damage"},
  ["that looks like something out of your nightmares"] = {
    rune = "kena", effect = "fear"},
  ["shaped like a viper"] = {
    rune = "sleizak", effect = "voyria"},
  ["resembling an apple core"] = {
    rune = "loshre", effect = "anorexia"},
  ["resembling a square box"] = {
    rune = "pithakhan", effect = "drain mana"},
  ["like a lightning bolt"] = {
    rune = "uruz", effect = "heal"},
  ["resembling a leech"] = {
    rune = "nauthiz", effect = "hunger"},
  ["like an upward-pointing arrow"] = {
    rune = "tiwaz", effect = "defence strip"},
  ["shaped like a mighty oak"] = {
    rune = "jera", effect = "+1 con and str"},
  ["resembling an elk"] = {
    rune = "algiz", effect = "10% dmg reduction"},
  ["like a lion"] = {
    rune = "berkana", effect = "lvl1 health regen"},
  ["resembling a horse"] = {
    rune = "raido", effect = "return location"},
  ["like a flurry of lightning bolts"] = {
    rune = "isaz", effect = "throws off balance"},
  ["like a rising sun"] = {
    rune = "dagaz", effect = "heals affs"},
  ["shaped like a yew"] = {
    rune = "eihwaz", effect = "removes vibes"},
  ["resembling a volcano"] = {
    rune = "thurisaz", effect = "hits a person"},
  ["resembling a mountain range"] = {
    rune = "othala", effect = "damage over time"},
}

for i = 1, #matches, 2 do
  local rune = matches[i+1]
  local line = matches[i]

  local pos = selectString(line, 1)
  moveCursor("main", pos+#line-1, getLineNumber())

  if t[rune] then
    cinsertText(string.format(" <a_blue>(<a_grey>%s: <a_cyan>%s<a_blue>)",
      t[rune].rune, type(t[rune].effect) == "function" and t[rune].effect() or t[rune].effect))
  else
    cinsertText(" <a_blue>(<a_darkyellow>unknown!<a_blue>)")
  end
end

deselect()
resetFormat()
moveCursorEnd()

svo.prompttrigger("clear fehu", function() svo.fehu = nil end)