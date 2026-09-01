local fs = require("fs")
local path = require("path")

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
  load_commands = load_commands,
}