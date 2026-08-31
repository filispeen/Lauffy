local lavalink = require("lavalink.lua")
local format = require("../utils/format")
local general = require("../utils/general")

local M = {}
local QUEUE_PAGE_SIZE = 10

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

function M.play(ctx, query)
  run(ctx, function()
    local current_guild_id = guild_id(ctx)
    if not current_guild_id then return end

    query = type(query) == "string" and query:match("^%s*(.-)%s*$") or ""
    if query == "" then
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

    -- URLs are passed to Lavalink unchanged. Text queries are resolved by its
    -- configured YouTube provider; this bot does not download or transcode media.
    local searched, result = pcall(current_manager.search, current_manager, query, { source = "ytsearch" })
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

    local tracks = result.loadType == "playlist" and found or { found[1] }
    local created
    if not player then
      player, created = current_manager:createPlayer({
        guildId = current_guild_id,
        voiceChannelId = author_channel_id,
        textChannelId = ctx.channel and ctx.channel.id,
        selfDeaf = true,
      })
    end

    if created then
      player:connect()
    elseif not player.voiceChannelId then
      player.voiceChannelId = author_channel_id
      player:connect()
    end

    player.textChannelId = ctx.channel and ctx.channel.id or player.textChannelId
    player.queue:add(tracks)
    if not player.playing then player:play() end

    local playlist_name = result.data and result.data.info and result.data.info.name
    reply(ctx, "", { embeds = { format.play_embed(tracks, playlist_name) } })
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

    count = tonumber(count) or 1
    if count < 1 or count % 1 ~= 0 then
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

function M.queue(ctx, page)
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
    if page < 1 or page % 1 ~= 0 then
      fail(ctx, "Page must be an integer starting at 1.")
      return
    end

    local embed, total_pages = format.queue_embed(player, page, QUEUE_PAGE_SIZE)
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

return M
