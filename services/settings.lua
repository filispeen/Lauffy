local fs = require("fs")
local json = require("json")
local path = require("path")

local M = {}
local DATA_DIRECTORY = path.join(process.cwd(), "data")
local DATA_FILE = path.join(DATA_DIRECTORY, "guild-settings.json")

local defaults = {
  playlistLimit = 50,
  defaultQueuePageSize = 10,
  defaultVolume = 100,
  queueAddResponseHidden = false,
  autoAnnounceNextSong = false,
  waitAfterQueueEmpties = 30,
}

local store

local function copy_defaults()
  local value = {}
  for key, default in pairs(defaults) do value[key] = default end
  value.favorites = {}
  return value
end

local function load()
  if store then return store end
  store = { guilds = {} }

  local ok, content = pcall(fs.readFileSync, DATA_FILE)
  if not ok or not content then return store end

  local decoded_ok, decoded = pcall(json.decode, content)
  if decoded_ok and type(decoded) == "table" and type(decoded.guilds) == "table" then
    store = decoded
  end
  return store
end

local function save()
  pcall(fs.mkdirSync, DATA_DIRECTORY)
  fs.writeFileSync(DATA_FILE, json.encode(load()))
end

function M.get(guild_id)
  local current = load()
  local key = tostring(guild_id)
  local value = current.guilds[key]
  if not value then
    value = copy_defaults()
    current.guilds[key] = value
  end

  for name, default in pairs(defaults) do
    if value[name] == nil then value[name] = default end
  end
  if type(value.favorites) ~= "table" then value.favorites = {} end
  return value
end

function M.update(guild_id, values)
  local value = M.get(guild_id)
  for name, setting in pairs(values) do value[name] = setting end
  save()
  return value
end

function M.find_favorite(guild_id, name)
  local target = type(name) == "string" and name:lower() or ""
  for _, favorite in ipairs(M.get(guild_id).favorites) do
    if favorite.name:lower() == target then return favorite end
  end
  return nil
end

function M.add_favorite(guild_id, name, query, author_id)
  local value = M.get(guild_id)
  if M.find_favorite(guild_id, name) then return nil, "A favorite with that name already exists." end
  local favorite = {
    name = name,
    query = query,
    authorId = tostring(author_id),
  }
  table.insert(value.favorites, favorite)
  save()
  return favorite
end

function M.remove_favorite(guild_id, name)
  local favorites = M.get(guild_id).favorites
  local target = type(name) == "string" and name:lower() or ""
  for index, favorite in ipairs(favorites) do
    if favorite.name:lower() == target then
      table.remove(favorites, index)
      save()
      return favorite
    end
  end
  return nil
end

return M
