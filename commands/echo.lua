local discord = require("discord.lua")
local lavalink = require("lavalink.lua")
local format = require("../utils/format")
local general = require("../utils/general")
local interaction = require("../utils/interaction")
local settings = require("../services/settings")

local function is_url(value)
  return value:match("^https?://") ~= nil
end

local function autocomplete_response(ctx, choices)
  local request, bot = ctx and ctx.interaction, ctx and ctx.bot
  if not request or not bot or not bot.rest then return end
  return bot.rest:create_interaction_response(request.id, request.token, {
    type = 8,
    data = { choices = choices },
  })
end

local function autocomplete(ctx)
  local query = type(ctx and ctx.value) == "string" and ctx.value:match("^%s*(.-)%s*$") or ""
  if query == "" or is_url(query) then return autocomplete_response(ctx, {}) end
  local manager = ctx.bot and ctx.bot.lavalink
  if not manager then return autocomplete_response(ctx, {}) end
  local ok, result = pcall(function()
    return manager:search(query, { source = "ytsearch" })
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
      local title = format.track_title(track)
      local author = track.info and track.info.author
      local label = author and (title .. " — " .. author) or title
      if #label > 100 then label = label:sub(1, 97) .. "..." end
      table.insert(choices, { name = label, value = value })
      if #choices >= 10 then break end
    end
  end
  return autocomplete_response(ctx, choices)
end

return {
  name = "play",
  description = "Play a Lavalink search query or URL",
  options = {
    {
      name = "query",
      description = "Search text or a provider URL",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
    },
    {
      name = "immediate",
      description = "Add tracks to the front of the queue",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
    {
      name = "shuffle",
      description = "Shuffle tracks loaded from a playlist",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
    {
      name = "skip",
      description = "Skip the current track after adding",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
  },
  autocomplete = {
    query = autocomplete,
  },
  callback = function(ctx)
    interaction.run(ctx, function()
      local guild_id = interaction.guild_id(ctx)
      if not guild_id then return end
      local query = ctx:require_arg("query")
      if type(query) ~= "string" or not query:match("%S") then
        return interaction.fail(ctx, "Provide a search query or URL.")
      end
      local voice_channel_id = interaction.author_voice_channel(ctx, guild_id)
      if not voice_channel_id then return end
      local manager = interaction.manager(ctx)
      if not manager then return end
      local player = manager:getPlayer(guild_id)
      if player and player.voiceChannelId and tostring(player.voiceChannelId) ~= tostring(voice_channel_id) then
        return interaction.fail(ctx, "You must be in the same voice channel as the bot.")
      end
      local searched, result = pcall(function()
        if is_url(query) then return manager:search(query) end
        return manager:search(query, { source = "ytsearch" })
      end)
      if not searched then
        general.log("ERROR", "Lavalink search failed: %s", tostring(result))
        return interaction.fail(ctx, "Lavalink could not find or load that query.")
      end
      local found = lavalink.utils.splitSearchResult(result.loadType, result)
      if #found == 0 then return interaction.fail(ctx, "No tracks found.") end
      local guild_settings = settings.get(guild_id)
      local tracks = result.loadType == "playlist" and found or { found[1] }
      while #tracks > guild_settings.playlistLimit do table.remove(tracks) end
      if ctx:get_arg("shuffle", false) then
        for index = #tracks, 2, -1 do
          local swap = math.random(1, index)
          tracks[index], tracks[swap] = tracks[swap], tracks[index]
        end
      end
      for _, track in ipairs(tracks) do track.requestedBy = ctx.author and ctx.author.id or nil end
      local created
      if not player then
        player, created = manager:createPlayer({
          guildId = guild_id,
          voiceChannelId = voice_channel_id,
          textChannelId = ctx.channel and ctx.channel.id,
          selfDeaf = true,
          volume = guild_settings.defaultVolume,
        })
      end
      if created then
        player:connect()
      elseif not player.voiceChannelId then
        player.voiceChannelId = voice_channel_id
        player:connect()
      end
      player.textChannelId = ctx.channel and ctx.channel.id or player.textChannelId
      if ctx:get_arg("immediate", false) then
        for index = #tracks, 1, -1 do player.queue:addAt(1, tracks[index]) end
      else
        player.queue:add(tracks)
      end
      if not player.playing then
        player:play()
      elseif ctx:get_arg("skip", false) and player.queue.current then
        player:skip(1, false)
      end
      local playlist_name = result.data and result.data.info and result.data.info.name
      interaction.reply(ctx, "", {
        embeds = { format.play_embed(tracks, playlist_name) },
        ephemeral = guild_settings.queueAddResponseHidden,
      })
    end)
  end,
}
