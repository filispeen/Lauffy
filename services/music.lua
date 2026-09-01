local lavalink = require("lavalink.lua")
local format = require("../utils/format")
local general = require("../utils/general")
local settings = require("./settings")
local bit = require("bit")

local M = {}
local QUEUE_PAGE_SIZE = 10
local AUTOCOMPLETE_LIMIT = 10

local function is_url(value)
  return value:match("^https?://") ~= nil
end

local function parse_duration(value)
  if type(value) ~= "string" then return nil end
  value = value:lower():match("^%s*(.-)%s*$")
  if value == "" then return nil end

  if value:match("^%d+$") then
    return tonumber(value) * 1000
  end

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
    if seconds < 60 then
      return (tonumber(minutes) * 60 + seconds) * 1000
    end
    return nil
  end

  local total = 0
  local consumed = ""
  for amount, unit in value:gmatch("(%d+)([hms])") do
    local multiplier = unit == "h" and 3600 or (unit == "m" and 60 or 1)
    total = total + tonumber(amount) * multiplier
    consumed = consumed .. amount .. unit
  end
  if consumed == value then return total * 1000 end
  return nil
end

local function positive_integer(value)
  value = tonumber(value)
  if not value or value < 1 or value % 1 ~= 0 then return nil end
  return value
end

local function reply(ctx, content, options)
  return ctx:respond(content or "", options)
end

local function fail(ctx, message)
  return reply(ctx, message, { ephemeral = true })
end

local function run(ctx, callback)
  local ok, err = pcall(callback)
  if not ok then
    general.log("ERROR", "Music command failed: %s", tostring(err))
    pcall(fail, ctx, "Lavalink could not complete this command.")
  end
end

local function guild_id(ctx)
  if not ctx.guild or not ctx.guild.id then
    fail(ctx, "This music command can only be used in a Discord server.")
    return nil
  end
  return ctx.guild.id
end

local function manager(ctx)
  local client = ctx.bot
  local value = client and client.lavalink
  if not value then
    fail(ctx, "Lavalink is not ready yet. Please try again in a few seconds.")
    return nil
  end
  return value
end

local function author_voice_channel(ctx, current_guild_id)
  local author = ctx.author
  local channel_id = author and ctx.bot:get_voice_channel_id(current_guild_id, author.id)
  if not channel_id then
    fail(ctx, "Join a voice channel first.")
    return nil
  end
  return channel_id
end

local function controlled_player(ctx)
  local current_guild_id = guild_id(ctx)
  if not current_guild_id then return nil end

  local current_manager = manager(ctx)
  if not current_manager then return nil end

  local player = current_manager:getPlayer(current_guild_id)
  if not player or not player.voiceChannelId then
    fail(ctx, "I am not connected to a voice channel.")
    return nil
  end

  local author_channel_id = author_voice_channel(ctx, current_guild_id)
  if not author_channel_id then return nil end

  if tostring(player.voiceChannelId) ~= tostring(author_channel_id) then
    fail(ctx, "You must be in the same voice channel as the bot.")
    return nil
  end

  return player
end

local function shuffle_tracks(tracks)
  for index = #tracks, 2, -1 do
    local swap = math.random(1, index)
    tracks[index], tracks[swap] = tracks[swap], tracks[index]
  end
end

local function limit_tracks(tracks, limit)
  if #tracks <= limit then return tracks end
  local limited = {}
  for index = 1, limit do limited[index] = tracks[index] end
  return limited
end

local function queue_tracks(player, tracks, options)
  if options.immediate then
    for index = #tracks, 1, -1 do player.queue:addAt(1, tracks[index]) end
  else
    player.queue:add(tracks)
  end
end

function M.play(ctx, query, options)
  run(ctx, function()
    local current_guild_id = guild_id(ctx)
    if not current_guild_id then return end
    options = options or {}

    if type(query) ~= "string" or not query:match("%S") then
      fail(ctx, "Provide a search query or URL.")
      return
    end

    local author_channel_id = author_voice_channel(ctx, current_guild_id)
    if not author_channel_id then return end

    local current_manager = manager(ctx)
    if not current_manager then return end

    local player = current_manager:getPlayer(current_guild_id)
    if player and player.voiceChannelId and tostring(player.voiceChannelId) ~= tostring(author_channel_id) then
      fail(ctx, "You must be in the same voice channel as the bot.")
      return
    end

    local searched, result = pcall(function()
      if is_url(query) then return current_manager:search(query) end
      return current_manager:search(query, { source = "ytsearch" })
    end)
    if not searched then
      general.log("ERROR", "Lavalink search failed: %s", tostring(result))
      fail(ctx, "Lavalink could not find or load that query.")
      return
    end

    local found = lavalink.utils.splitSearchResult(result.loadType, result)
    if #found == 0 then
      fail(ctx, "No tracks found.")
      return
    end

    local guild_settings = settings.get(current_guild_id)
    local tracks = result.loadType == "playlist" and found or { found[1] }
    tracks = limit_tracks(tracks, guild_settings.playlistLimit)
    if options.shuffle and #tracks > 1 then shuffle_tracks(tracks) end
    for _, track in ipairs(tracks) do
      track.requestedBy = ctx.author and ctx.author.id or nil
    end

    local created
    if not player then
      player, created = current_manager:createPlayer({
        guildId = current_guild_id,
        voiceChannelId = author_channel_id,
        textChannelId = ctx.channel and ctx.channel.id,
        selfDeaf = true,
        volume = guild_settings.defaultVolume,
      })
    end

    if created then
      player:connect()
    elseif not player.voiceChannelId then
      player.voiceChannelId = author_channel_id
      player:connect()
    end

    player.textChannelId = ctx.channel and ctx.channel.id or player.textChannelId
    queue_tracks(player, tracks, options)
    if not player.playing then
      player:play()
    elseif options.skip and player.queue.current then
      player:skip(1, false)
    end

    local playlist_name = result.data and result.data.info and result.data.info.name
    reply(ctx, "", {
      embeds = { format.play_embed(tracks, playlist_name) },
      ephemeral = guild_settings.queueAddResponseHidden,
    })
  end)
end

function M.pause(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    if player.paused then
      fail(ctx, "Playback is already paused.")
      return
    end
    player:pause(true)
    reply(ctx, "Playback paused.")
  end)
end

function M.resume(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    if not player.paused then
      fail(ctx, "Playback is not paused.")
      return
    end
    player:resume()
    reply(ctx, "Playback resumed.")
  end)
end

function M.skip(ctx, count)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    count = positive_integer(count or 1)
    if not count then
      fail(ctx, "Skip position must be an integer starting at 1.")
      return
    end
    if not player.queue.current then
      fail(ctx, "There is no active track.")
      return
    end

    player:skip(count, false)
    reply(ctx, count == 1 and "Track skipped." or string.format("Skipped to queue position %d.", count))
  end)
end

function M.stop(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    player:stopPlaying(true)
    reply(ctx, "Playback stopped and the queue was cleared.")
  end)
end

function M.disconnect(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    player:disconnect(true)
    reply(ctx, "Disconnected from the voice channel.")
  end)
end

function M.clear(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    if not player.queue.current then
      fail(ctx, "There is no active track.")
      return
    end

    local count = player.queue:size()
    if count == 0 then
      fail(ctx, "There are no upcoming tracks to clear.")
      return
    end

    player.queue:clear()
    reply(ctx, string.format("Cleared %d upcoming track%s.", count, count == 1 and "" or "s"))
  end)
end

function M.remove(ctx, position, range)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    position = positive_integer(position)
    range = positive_integer(range or 1)
    if not position or not range then
      fail(ctx, "Position and range must be positive integers.")
      return
    end

    local size = player.queue:size()
    local finish = position + range - 1
    if position > size or finish > size then
      fail(ctx, "That queue range does not exist.")
      return
    end

    player.queue:remove(position, finish)
    reply(ctx, string.format("Removed %d upcoming track%s.", range, range == 1 and "" or "s"))
  end)
end

function M.move(ctx, from, to)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    from = positive_integer(from)
    to = positive_integer(to)
    if not from or not to then
      fail(ctx, "From and to must be positive integers.")
      return
    end

    local size = player.queue:size()
    if from > size or to > size then
      fail(ctx, "That queue position does not exist.")
      return
    end
    if from == to then
      fail(ctx, "That track is already at that position.")
      return
    end

    local track = player.queue:remove(from)
    player.queue:addAt(to, track[1])
    reply(ctx, string.format("Moved track from %d to %d.", from, to))
  end)
end

local function seek_to(ctx, player, position)
  local track = player.queue.current
  if not track then
    fail(ctx, "There is no active track.")
    return false
  end
  if track.info and track.info.isStream then
    fail(ctx, "Live streams cannot be seeked.")
    return false
  end

  local length = track.info and track.info.length
  if type(length) == "number" and position > length then
    fail(ctx, "That position is beyond the end of the track.")
    return false
  end

  player:seek(position)
  return true
end

function M.seek(ctx, duration)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    local position = parse_duration(duration)
    if not position then
      fail(ctx, "Use a duration such as 90, 1m30s, or 01:30.")
      return
    end

    if seek_to(ctx, player, position) then
      reply(ctx, "Seeked to " .. format.duration(position) .. ".")
    end
  end)
end

function M.fseek(ctx, duration)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    local offset = parse_duration(duration)
    if not offset then
      fail(ctx, "Use a duration such as 90, 1m30s, or 01:30.")
      return
    end

    local position = player:getPosition() + offset
    if seek_to(ctx, player, position) then
      reply(ctx, "Seeked forward to " .. format.duration(position) .. ".")
    end
  end)
end

function M.replay(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    if seek_to(ctx, player, 0) then reply(ctx, "Track restarted.") end
  end)
end

function M.unskip(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    local previous = table.remove(player.queue.previous, 1)
    if not previous then
      fail(ctx, "There is no previous track.")
      return
    end

    if player.queue.current then player.queue:addAt(1, player.queue.current) end
    player.queue.current = previous
    player.position = 0
    player:play()
    reply(ctx, "Returned to the previous track.")
  end)
end

function M.queue(ctx, page, page_size)
  run(ctx, function()
    local current_guild_id = guild_id(ctx)
    if not current_guild_id then return end

    local current_manager = manager(ctx)
    if not current_manager then return end

    local player = current_manager:getPlayer(current_guild_id)
    if not player or not player.queue.current then
      fail(ctx, "The queue is empty.")
      return
    end

    page = tonumber(page) or 1
    page_size = tonumber(page_size) or settings.get(current_guild_id).defaultQueuePageSize or QUEUE_PAGE_SIZE
    if page < 1 or page % 1 ~= 0 then
      fail(ctx, "Page must be an integer starting at 1.")
      return
    end
    if page_size < 1 or page_size > 30 or page_size % 1 ~= 0 then
      fail(ctx, "Page size must be an integer between 1 and 30.")
      return
    end

    local embed, total_pages = format.queue_embed(player, page, page_size)
    if page > total_pages then
      fail(ctx, string.format("That page does not exist. Available pages: %d.", total_pages))
      return
    end

    reply(ctx, "", { embeds = { embed } })
  end)
end

function M.nowplaying(ctx)
  run(ctx, function()
    local current_guild_id = guild_id(ctx)
    if not current_guild_id then return end

    local current_manager = manager(ctx)
    if not current_manager then return end

    local player = current_manager:getPlayer(current_guild_id)
    if not player or not player.queue.current then
      fail(ctx, "Nothing is playing right now.")
      return
    end

    reply(ctx, "", { embeds = { format.now_playing_embed(player) } })
  end)
end

function M.volume(ctx, level)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end

    level = tonumber(level)
    if not level or level < 0 or level > 1000 or level % 1 ~= 0 then
      fail(ctx, "Volume must be an integer between 0 and 1000.")
      return
    end

    player:setVolume(level)
    reply(ctx, string.format("Volume set to %d%%.", level))
  end)
end

function M.shuffle(ctx)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    if player.queue:size() < 2 then
      fail(ctx, "At least two queued tracks are required to shuffle.")
      return
    end
    player.queue:shuffle()
    reply(ctx, "Queue shuffled.")
  end)
end

function M.loop(ctx, mode)
  run(ctx, function()
    local player = controlled_player(ctx)
    if not player then return end
    if mode ~= "off" and mode ~= "track" and mode ~= "queue" then
      fail(ctx, "Loop mode must be off, track, or queue.")
      return
    end
    player:setRepeatMode(mode)
    reply(ctx, "Loop mode set to " .. mode .. ".")
  end)
end

local function autocomplete_response(ctx, choices)
  local interaction = ctx and ctx.interaction
  local client = ctx and ctx.bot
  if not interaction or not client or not client.rest then return end
  return client.rest:create_interaction_response(interaction.id, interaction.token, {
    type = 8,
    data = { choices = choices },
  })
end

local function autocomplete_label(track)
  local title = format.track_title(track)
  local author = track and track.info and track.info.author
  local label = author and (title .. " — " .. author) or title
  if #label > 100 then label = label:sub(1, 97) .. "..." end
  return label
end

function M.autocomplete(ctx)
  local query = type(ctx and ctx.value) == "string" and ctx.value:match("^%s*(.-)%s*$") or ""
  if query == "" or is_url(query) then return autocomplete_response(ctx, {}) end

  local current_manager = ctx.bot and ctx.bot.lavalink
  if not current_manager then return autocomplete_response(ctx, {}) end

  local ok, result = pcall(function()
    return current_manager:search(query, { source = "ytsearch" })
  end)
  if not ok then
    general.log("WARN", "Lavalink autocomplete failed: %s", tostring(result))
    return autocomplete_response(ctx, {})
  end

  local choices, values = {}, {}
  for _, track in ipairs(lavalink.utils.splitSearchResult(result.loadType, result)) do
    local value = track.info and track.info.uri
    if value and not values[value] then
      values[value] = true
      table.insert(choices, { name = autocomplete_label(track), value = value })
      if #choices >= AUTOCOMPLETE_LIMIT then break end
    end
  end
  return autocomplete_response(ctx, choices)
end

function M.favorite_autocomplete(ctx)
  local guild = ctx and ctx.interaction and ctx.interaction.guild_id
  if not guild then return autocomplete_response(ctx, {}) end

  local query = type(ctx.value) == "string" and ctx.value:lower() or ""
  local action = ctx.options and ctx.options.action
  local choices = {}
  for _, favorite in ipairs(settings.get(guild).favorites) do
    local allowed = action ~= "remove"
      or (ctx.interaction.member and ctx.interaction.member.user
        and tostring(favorite.authorId) == tostring(ctx.interaction.member.user.id))
    if allowed and favorite.name:lower():find(query, 1, true) then
      table.insert(choices, { name = favorite.name, value = favorite.name })
      if #choices >= 25 then break end
    end
  end
  return autocomplete_response(ctx, choices)
end

local function favorite_embed(favorites)
  local lines = {}
  for _, favorite in ipairs(favorites) do
    table.insert(lines, string.format("**%s** — <@%s>", favorite.name, favorite.authorId))
  end
  return {
    title = "Favorites",
    color = 0xF1C40F,
    description = #lines > 0 and table.concat(lines, "\n") or "No favorites saved.",
  }
end

function M.favorites(ctx, action, name, query, options)
  run(ctx, function()
    local current_guild_id = guild_id(ctx)
    if not current_guild_id then return end

    if action == "list" then
      reply(ctx, "", { embeds = { favorite_embed(settings.get(current_guild_id).favorites) }, ephemeral = true })
      return
    end

    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then
      fail(ctx, "Provide a favorite name.")
      return
    end

    if action == "create" then
      query = type(query) == "string" and query:match("^%s*(.-)%s*$") or ""
      if query == "" then
        fail(ctx, "Provide a search query or URL to save.")
        return
      end
      local _, err = settings.add_favorite(current_guild_id, name, query, ctx.author and ctx.author.id)
      if err then
        fail(ctx, err)
        return
      end
      reply(ctx, "Favorite saved.", { ephemeral = true })
      return
    end

    if action == "remove" then
      local favorite = settings.find_favorite(current_guild_id, name)
      if not favorite then
        fail(ctx, "That favorite does not exist.")
        return
      end
      if tostring(favorite.authorId) ~= tostring(ctx.author and ctx.author.id) then
        fail(ctx, "You can only remove your own favorites.")
        return
      end
      settings.remove_favorite(current_guild_id, name)
      reply(ctx, "Favorite removed.", { ephemeral = true })
      return
    end

    if action == "use" then
      local favorite = settings.find_favorite(current_guild_id, name)
      if not favorite then
        fail(ctx, "That favorite does not exist.")
        return
      end
      M.play(ctx, favorite.query, options)
      return
    end

    fail(ctx, "Action must be use, list, create, or remove.")
  end)
end

local function can_manage_guild(ctx)
  local permissions = tonumber(ctx.member_permissions)
  if not permissions or not bit then return false end
  return bit.band(permissions, 8) ~= 0 or bit.band(permissions, 32) ~= 0
end

local function boolean_value(value)
  value = type(value) == "string" and value:lower():match("^%s*(.-)%s*$") or ""
  if value == "true" or value == "yes" or value == "on" then return true end
  if value == "false" or value == "no" or value == "off" then return false end
  return nil
end

function M.config(ctx, action, setting, value)
  run(ctx, function()
    local current_guild_id = guild_id(ctx)
    if not current_guild_id then return end
    local current = settings.get(current_guild_id)

    if action == "get" then
      reply(ctx, "", {
        embeds = {{
          title = "Music settings",
          color = 0x5865F2,
          fields = {
            { name = "Playlist limit", value = tostring(current.playlistLimit), inline = true },
            { name = "Queue page size", value = tostring(current.defaultQueuePageSize), inline = true },
            { name = "Default volume", value = tostring(current.defaultVolume) .. "%", inline = true },
            { name = "Hide queue responses", value = current.queueAddResponseHidden and "On" or "Off", inline = true },
            { name = "Auto announce", value = current.autoAnnounceNextSong and "On" or "Off", inline = true },
            { name = "Leave after queue ends", value = tostring(current.waitAfterQueueEmpties) .. "s", inline = true },
          },
        }},
        ephemeral = true,
      })
      return
    end

    if action ~= "set" then
      fail(ctx, "Action must be get or set.")
      return
    end
    if not can_manage_guild(ctx) then
      fail(ctx, "You need Manage Server permission to change settings.")
      return
    end

    local number = tonumber(value)
    local updates
    if setting == "playlist_limit" and number and number >= 1 and number % 1 == 0 then
      updates = { playlistLimit = number }
    elseif setting == "queue_page_size" and number and number >= 1 and number <= 30 and number % 1 == 0 then
      updates = { defaultQueuePageSize = number }
    elseif setting == "default_volume" and number and number >= 0 and number <= 1000 and number % 1 == 0 then
      updates = { defaultVolume = number }
    elseif setting == "queue_add_hidden" then
      local parsed = boolean_value(value)
      if parsed ~= nil then updates = { queueAddResponseHidden = parsed } end
    elseif setting == "auto_announce" then
      local parsed = boolean_value(value)
      if parsed ~= nil then updates = { autoAnnounceNextSong = parsed } end
    elseif setting == "queue_end_delay" and number and number >= 0 and number % 1 == 0 then
      updates = { waitAfterQueueEmpties = number }
    end

    if not updates then
      fail(ctx, "That value is invalid for the selected setting.")
      return
    end
    settings.update(current_guild_id, updates)
    reply(ctx, "Setting updated.", { ephemeral = true })
  end)
end

return M
