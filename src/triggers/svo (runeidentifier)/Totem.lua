local rune = multimatches[2][2]
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
    rune = "tiwaz", effect = "defence strip"}
}

echo(string.rep(" ", 60-#multimatches[2][1]))

if t[rune] then
  cecho(string.format(" <a_red>(<a_grey>%s: <a_cyan>%s<a_red>)",
    t[rune].rune, type(t[rune].effect) == "function" and t[rune].effect() or t[rune].effect))
else
  cecho(" <a_red>(<a_darkyellow>unknown!<a_red)")
end

svo.prompttrigger("clear fehu", function() svo.fehu = nil end)