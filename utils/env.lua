local fs = require("fs")
local path = require("path")

local function load(filepath)
  filepath = filepath or path.join(process.cwd(), ".env")

  local ok, content = pcall(fs.readFileSync, filepath)
  if not ok or not content then return end

  for line in content:gmatch("[^\r\n]+") do
    local key, value = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
    if key and not line:match("^%s*#") and process.env[key] == nil then
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

local function string_value(value, default)
  if value == nil or value == "" then return default end
  return value
end

local function required_string(value, name)
  local normalized = type(value) == "string" and value:match("^%s*(.-)%s*$") or nil
  if not normalized or normalized == "" then
    error(string.format("%s is required. Set it in .env or provide it as an environment variable.", name))
  end
  return normalized
end

local function config()
  load()

  local port = number(process.env.NODELINK_PORT, 2333, "NODELINK_PORT")
  if port < 1 or port > 65535 or port % 1 ~= 0 then
    error("NODELINK_PORT must be an integer between 1 and 65535")
  end

  local api_version = number(process.env.NODELINK_API_VERSION, 4,
    "NODELINK_API_VERSION")
  if api_version ~= 4 then
    error("NODELINK_API_VERSION must be 4: NodeLink v3 only supports Lavalink API v4")
  end

  local search_source = string_value(process.env.NODELINK_SEARCH_SOURCE, "ytmsearch")
  local supported_search_sources = {
    ytsearch = true,
    ytmsearch = true,
    spsearch = true,
    search = true,
  }
  if not supported_search_sources[search_source] then
    error("NODELINK_SEARCH_SOURCE must be one of: ytmsearch, ytsearch, spsearch, search")
  end

  return {
    token = required_string(process.env.TOKEN, "TOKEN"),
    nodelink = {
      host = string_value(process.env.NODELINK_HOST, "localhost"),
      port = port,
      authorization = required_string(process.env.NODELINK_PASSWORD, "NODELINK_PASSWORD"),
      secure = boolean(process.env.NODELINK_TLS, false, "NODELINK_TLS"),
      apiVersion = api_version,
      searchSource = search_source,
      resuming = boolean(process.env.NODELINK_RESUME, true, "NODELINK_RESUME"),
      resumeTimeout = number(process.env.NODELINK_RESUME_TIMEOUT, 60,
        "NODELINK_RESUME_TIMEOUT"),
      reconnectTries = number(process.env.NODELINK_RECONNECT_TRIES, 5,
        "NODELINK_RECONNECT_TRIES"),
      reconnectDelay = number(process.env.NODELINK_RECONNECT_DELAY, 5000,
        "NODELINK_RECONNECT_DELAY"),
    },
  }
end

return {
  load = load,
  boolean = boolean,
  number = number,
  string = string_value,
  required_string = required_string,
  config = config,
}
