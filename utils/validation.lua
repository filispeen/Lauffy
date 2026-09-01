local M = {}

function M.positive_integer(value)
  value = tonumber(value)
  if not value or value < 1 or value % 1 ~= 0 then return nil end
  return value
end

function M.parse_duration(value)
  if type(value) ~= "string" then return nil end
  value = value:lower():match("^%s*(.-)%s*$")
  if value == "" then return nil end
  if value:match("^%d+$") then return tonumber(value) * 1000 end

  local hours, minutes, seconds = value:match("^(%d+):(%d%d):(%d%d)$")
  if hours then
    minutes, seconds = tonumber(minutes), tonumber(seconds)
    if minutes < 60 and seconds < 60 then
      return (tonumber(hours) * 3600 + minutes * 60 + seconds) * 1000
    end
    return nil
  end

  minutes, seconds = value:match("^(%d+):(%d%d)$")
  if minutes then
    seconds = tonumber(seconds)
    if seconds < 60 then return (tonumber(minutes) * 60 + seconds) * 1000 end
    return nil
  end

  local total, consumed = 0, ""
  for amount, unit in value:gmatch("(%d+)([hms])") do
    total = total + tonumber(amount) * (unit == "h" and 3600 or (unit == "m" and 60 or 1))
    consumed = consumed .. amount .. unit
  end
  return consumed == value and total * 1000 or nil
end

return M
