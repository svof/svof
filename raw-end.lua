-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.


svo.signals.systemstart:emit()
tempTimer(0, function() svo.systemloaded = true; raiseEvent("svo system loaded") end)

return _M;
