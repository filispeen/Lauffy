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

local function favorite_autocomplete(ctx)
  local guild_id = ctx and ctx.interaction and ctx.interaction.guild_id
  if not guild_id then return autocomplete_response(ctx, {}) end
  local query = type(ctx.value) == "string" and ctx.value:lower() or ""
  local action = ctx.options and ctx.options.action
  local choices = {}
  for _, favorite in ipairs(settings.get(guild_id).favorites) do
    local author = ctx.interaction.member and ctx.interaction.member.user
    local allowed = action ~= "remove" or (author and tostring(favorite.authorId) == tostring(author.id))
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

return {
  name = "favorites",
  description = "Save and play favorite Lavalink queries",
  options = {
    {
      name = "action",
      description = "Favorite action",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
      choices = {
        { name = "Use", value = "use" },
        { name = "List", value = "list" },
        { name = "Create", value = "create" },
        { name = "Remove", value = "remove" },
      },
    },
    {
      name = "name",
      description = "Favorite name",
      type = discord.enums.OPTION_TYPE.STRING,
      required = false,
    },
    {
      name = "query",
      description = "Search text or a provider URL for create",
      type = discord.enums.OPTION_TYPE.STRING,
      required = false,
    },
    {
      name = "immediate",
      description = "Add the favorite to the front of the queue",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
    {
      name = "shuffle",
      description = "Shuffle tracks loaded from the favorite",
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
    name = favorite_autocomplete,
  },
  callback = function(ctx)
    interaction.run(ctx, function()
      local guild_id = interaction.guild_id(ctx)
      if not guild_id then return end
      local action = ctx:require_arg("action")
      if action == "list" then
        return interaction.reply(ctx, "", {
          embeds = { favorite_embed(settings.get(guild_id).favorites) },
          ephemeral = true,
        })
      end
      local name = type(ctx:get_arg("name")) == "string" and ctx:get_arg("name"):match("^%s*(.-)%s*$") or ""
      if name == "" then return interaction.fail(ctx, "Provide a favorite name.") end
      if action == "create" then
        local query = ctx:get_arg("query")
        if type(query) ~= "string" or not query:match("%S") then
          return interaction.fail(ctx, "Provide a search query or URL to save.")
        end
        local _, err = settings.add_favorite(guild_id, name, query, ctx.author and ctx.author.id)
        if err then return interaction.fail(ctx, err) end
        return interaction.reply(ctx, "Favorite saved.", { ephemeral = true })
      end
      if action == "remove" then
        local favorite = settings.find_favorite(guild_id, name)
        if not favorite then return interaction.fail(ctx, "That favorite does not exist.") end
        if tostring(favorite.authorId) ~= tostring(ctx.author and ctx.author.id) then
          return interaction.fail(ctx, "You can only remove your own favorites.")
        end
        settings.remove_favorite(guild_id, name)
        return interaction.reply(ctx, "Favorite removed.", { ephemeral = true })
      end
      if action ~= "use" then return interaction.fail(ctx, "Action must be use, list, create, or remove.") end
      local favorite = settings.find_favorite(guild_id, name)
      if not favorite then return interaction.fail(ctx, "That favorite does not exist.") end
      local voice_channel_id = interaction.author_voice_channel(ctx, guild_id)
      if not voice_channel_id then return end
      local manager = interaction.manager(ctx)
      if not manager then return end
      local player = manager:getPlayer(guild_id)
      if player and player.voiceChannelId and tostring(player.voiceChannelId) ~= tostring(voice_channel_id) then
        return interaction.fail(ctx, "You must be in the same voice channel as the bot.")
      end
      local searched, result = pcall(function()
        if is_url(favorite.query) then return manager:search(favorite.query) end
        return manager:search(favorite.query, { source = "ytsearch" })
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
