local fs = require("fs")
local path = require("path")

local function safe_tostring(value)
  local ok, result = pcall(tostring, value)
  return ok and result or "<unprintable value>"
end

local function format_error_value(value, seen, depth)
  local value_type = type(value)
  if value == nil then return "<no error details>" end
  if value_type ~= "table" then
    local text = safe_tostring(value)
    if text:match("^Uncaught Error:%s*%(%s*null%s*%)$") then return "<no error details>" end
    return text
  end
  if seen[value] then return "<cycle>" end
  if depth >= 3 then return "<nested table>" end

  seen[value] = true
  local parts, count = {}, 0
  for _, key in ipairs({ "message", "error", "code", "status", "statusCode", "body", "stack", "cause" }) do
    local field = rawget(value, key)
    if field ~= nil then
      count = count + 1
      parts[#parts + 1] = key .. "=" .. format_error_value(field, seen, depth + 1)
    end
  end
  if count == 0 then
    for key, field in pairs(value) do
      count = count + 1
      if count > 12 then
        parts[#parts + 1] = "..."
        break
      end
      parts[#parts + 1] = safe_tostring(key) .. "=" .. format_error_value(field, seen, depth + 1)
    end
  end
  seen[value] = nil
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function format_error(err)
  return format_error_value(err, {}, 0)
end

local function traceback(err)
  local message = format_error(err)
  if debug and debug.traceback then return debug.traceback(message, 2) end
  return message
end
local function log(level, fmt, ...)
  local prefix = {
    INFO  = "[INFO ]",
    WARN  = "[WARN ]",
    ERROR = "[ERROR]",
    DEBUG = "[DEBUG]",
    NODE  = "[NODE ]",
    TRACK = "[TRACK]",
    PLAY  = "[PLAY ]",
    VOICE = "[VOICE]",
    CMD   = "[CMD  ]",
    BOT   = "[BOT  ]",
  }
  local tag = prefix[level] or ("[" .. level .. "]")
  local ts  = os.date("%H:%M:%S")
  print(string.format("%s %s %s", ts, tag, string.format(fmt, ...)))
end

local function log_error(context, err)
  log("ERROR", "%s\n%s", context, traceback(err))
end
local function load_commands(bot)
  local commands_dir = path.join(process.cwd(), "commands")
  local files, err = fs.readdirSync(commands_dir)
  assert(files, "Unable to read commands directory: " .. tostring(err))
  table.sort(files)

  for _, file in ipairs(files) do
    if file:match("%.lua$") then
      local module_name = file:gsub("%.lua$", "")
      local command = require(path.join(commands_dir, module_name))

      assert(type(command) == "table", "Command module must return a table: " .. file)
      assert(type(command.name) == "string" and command.name ~= "", "Command name is required: " .. file)
      assert(type(command.callback) == "function", "Command callback is required: " .. file)

      local registered = bot:slash_command(command.name, {
        description = command.description,
        options = command.options,
        callback = command.callback,
      })
      for option_name, callback in pairs(command.autocomplete or {}) do
        assert(type(callback) == "function", "Autocomplete callback must be a function: " .. file)
        registered:set_autocomplete(option_name, callback)
      end
      log("CMD", "Loaded command: %s", command.name)
    end
  end
end

return {
  log = log,
  format_error = format_error,
  traceback = traceback,
  log_error = log_error,
  load_commands = load_commands,
}