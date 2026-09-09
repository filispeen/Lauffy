local discord = require("discord.lua")
local lavalink = require("lavalink.lua")
local uv = require("uv")

local env = require("./utils/env")
local settings = require("./services/settings")
local utils = require("./utils/general")
local config = env.config()

local bot = discord.Bot(nil, discord.enums.combine_intents(
  discord.enums.INTENTS.GUILDS,
  discord.enums.INTENTS.GUILD_VOICE_STATES
))

local get_application_context = bot.get_application_context
function bot:get_application_context(interaction)
  local ctx = get_application_context(self, interaction)
  ctx.member_permissions = interaction.member and interaction.member.permissions
  return ctx
end

-- Commands must be registered before bot:run() so discord.lua includes them
-- in the first automatic command synchronization after READY.
utils.load_commands(bot)

local function log_track(level, player, track)
  local title = track and track.info and track.info.title or "unknown track"
  utils.log(level, "Guild %s: %s", tostring(player.guildId), tostring(title))
end

local function create_lavalink_client()
  if bot.lavalink then return bot.lavalink end

  local manager = lavalink.discord(bot, {
    clientName = "lauffy/" .. bot.user.id,
    nodes = {
      {
        id = "main",
        host = config.lavalink.host,
        port = config.lavalink.port,
        authorization = config.lavalink.authorization,
        secure = config.lavalink.secure,
        resuming = config.lavalink.resuming,
        resumeTimeout = config.lavalink.resumeTimeout,
        reconnectTries = config.lavalink.reconnectTries,
        reconnectDelay = config.lavalink.reconnectDelay,
      },
    },
    playerOptions = { defaultVolume = 100 },
  })

  manager:on("nodeReady", function(node, resumed, session_id)
    utils.log("NODE", "Node %s ready (resumed: %s, session: %s)",
      node.options.id, tostring(resumed), tostring(session_id))
  end)
  manager:on("nodeError", function(node, err)
    if utils.format_error(err) == "<no error details>" then
      utils.log("ERROR", "Node %s (%s:%s) returned no details; check that NodeLink is running, LAVALINK_HOST/PORT/PASS, and its logs.",
        tostring(node.options.id), tostring(node.options.host), tostring(node.options.port))
      return
    end

    utils.log_error("Node " .. tostring(node.options.id) .. " error", err)
  end)
  manager:on("nodeConnect", function(node)
    utils.log("NODE", "Node %s connected to %s:%s",
      tostring(node.options.id), tostring(node.options.host), tostring(node.options.port))
  end)
  manager:on("nodeDisconnect", function(node, reason)
    utils.log("WARN", "Node %s disconnected: %s",
      tostring(node.options.id), utils.format_error(reason))
  end)
  manager:on("nodeReconnecting", function(node, attempt, delay)
    utils.log("WARN", "Node %s reconnecting (attempt %s in %sms)",
      tostring(node.options.id), tostring(attempt), tostring(delay))
  end)
  manager:on("error", function(player_or_err, err)
    -- lavalink.lua emits player errors as (player, err), but its Emitter emits
    -- listener failures as (err). Supporting both avoids masking the root cause.
    if err == nil then
      utils.log_error("Lavalink manager error", player_or_err)
      return
    end
    utils.log_error("Guild " .. tostring(player_or_err and player_or_err.guildId or "?") .. " player error", err)
  end)
  manager:on("trackStart", function(player, track)
    log_track("TRACK", player, track)
    if settings.get(player.guildId).autoAnnounceNextSong and player.textChannelId then
      local channel = bot:get_channel(player.textChannelId)
      if channel then
        local title = track and track.info and track.info.title or "track"
        pcall(channel.send, channel, "Now playing: **" .. title .. "**")
      end
    end
  end)
  manager:on("trackError", function(player, track, err)
    log_track("ERROR", player, track)
    utils.log_error("Guild " .. tostring(player.guildId) .. " Lavalink track error", err)
    player:skip(nil, false)
  end)
  manager:on("queueEnd", function(player)
    local delay = settings.get(player.guildId).waitAfterQueueEmpties
    if delay == 0 then
      utils.log("TRACK", "Guild %s: queue ended; staying connected", tostring(player.guildId))
      return
    end

    utils.log("TRACK", "Guild %s: queue ended; disconnecting in %ds", tostring(player.guildId), delay)
    local timer = uv.new_timer()
    timer:start(delay * 1000, 0, function()
      if not player.queue.current and player.voiceChannelId then player:disconnect(true) end
      timer:close()
    end)
  end)

  bot.lavalink = manager
  -- Slash command contexts expose discord.lua's underlying Client.
  bot.client.lavalink = manager
  manager:init()
  return manager
end

bot:on("application_command_error", function(ctx, err)
  utils.log_error("Slash command failed", err)
  pcall(ctx.respond, ctx, "An internal error occurred while running this command.", { ephemeral = true })
end)

bot:on("ready", function()
  utils.log("BOT", "Logged in as %s (id: %s)", bot.user.username, bot.user.id)
  create_lavalink_client()
end)

bot:run(config.token)