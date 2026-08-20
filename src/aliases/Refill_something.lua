-- example: compound/brew 5 health, 3 restoration
if command:find("brew %d+ %w+ in %w+") then send(command, false) return end
if command:find("compound %d+ %w+ in %w+") then send(command, false) return end

if matches[3] == 'cancel' then svo.rf_cancel() svo.showprompt() echo'\n' return end
svo.rf_refill(matches[2], matches[3])