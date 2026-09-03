local general = require("./general")

local M = {}

function M.reply(ctx, content, options)
  return ctx:respond(content or "", options)
end

function M.fail(ctx, message)
  return M.reply(ctx, message, { ephemeral = true })
end

function M.run(ctx, callback)
  local ok, err = pcall(callback)
  if not ok then
    general.log("ERROR", "Command failed: %s", tostring(err))
    pcall(M.fail, ctx, "Lavalink could not complete this command.")
  end
end

function M.guild_id(ctx)
  if not ctx.guild or not ctx.guild.id then
    M.fail(ctx, "This music command can only be used in a Discord server.")
    return nil
  end
  return ctx.guild.id
end

function M.manager(ctx)
  local manager = ctx.bot and ctx.bot.lavalink
  if not manager then
    M.fail(ctx, "Lavalink is not ready yet. Please try again in a few seconds.")
    return nil
  end
  return manager
end

function M.search_source(ctx)
  return (ctx and ctx.bot and ctx.bot.musicSearchSource) or "ytmsearch"
end

function M.author_voice_channel(ctx, guild_id)
  local author = ctx.author
  local channel_id = author and ctx.bot:get_voice_channel_id(guild_id, author.id)
  if not channel_id then
    M.fail(ctx, "Join a voice channel first.")
    return nil
  end
  return channel_id
end

function M.controlled_player(ctx)
  local guild_id = M.guild_id(ctx)
  if not guild_id then return nil end

  local manager = M.manager(ctx)
  if not manager then return nil end

  local player = manager:getPlayer(guild_id)
  if not player or not player.voiceChannelId then
    M.fail(ctx, "I am not connected to a voice channel.")
    return nil
  end

  local channel_id = M.author_voice_channel(ctx, guild_id)
  if not channel_id then return nil end
  if tostring(player.voiceChannelId) ~= tostring(channel_id) then
    M.fail(ctx, "You must be in the same voice channel as the bot.")
    return nil
  end
  return player
end

return M
