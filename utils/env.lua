local fs = require("fs")
local path = require("path")

local function load(filepath)
  filepath = filepath or path.join(process.cwd(), ".env")

  local ok, content = pcall(fs.readFileSync, filepath)
  if not ok or not content then return end

  for line in content:gmatch("[^\r\n]+") do
    local key, value = line:match("^([%w_]+)%s*=%s*(.-)%s*$")

    if key and not line:match("^%s*#") then
      value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
      process.env[key] = value
    end
  end
end

local function boolean(value, default, name)
  if value == nil or value == "" then return default end
  if type(value) == "boolean" then return value end

  local normalized = tostring(value):lower():match("^%s*(.-)%s*$")
  if normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on" then
    return true
  end
  if normalized == "false" or normalized == "0" or normalized == "no" or normalized == "off" then
    return false
  end

  error(string.format("%s must be a boolean, got %q", name or "value", tostring(value)))
end

local function number(value, default, name)
  if value == nil or value == "" then return default end

  local parsed = tonumber(value)
  if not parsed then
    error(string.format("%s must be a number, got %q", name or "value", tostring(value)))
  end
  return parsed
end

local function string(value, default)
  if value == nil or value == "" then return default end
  return value
end

return {
  load = load,
  boolean = boolean,
  number = number,
  string = string,
}