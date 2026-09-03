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

local function create_nodelink_client()
  if bot.lavalink then return bot.lavalink end

  local manager = lavalink.discord(bot, {
    clientName = "lauffy/" .. bot.user.id,
    -- NodeLink v3 is Lavalink API v4 compatible.  Do not downgrade this
    -- value: v3 routes are intentionally unsupported by this application.
    apiVersion = config.nodelink.apiVersion,
    nodes = {
      {
        id = "main",
        host = config.nodelink.host,
        port = config.nodelink.port,
        authorization = config.nodelink.authorization,
        secure = config.nodelink.secure,
        apiVersion = config.nodelink.apiVersion,
        resuming = config.nodelink.resuming,
        resumeTimeout = config.nodelink.resumeTimeout,
        reconnectTries = config.nodelink.reconnectTries,
        reconnectDelay = config.nodelink.reconnectDelay,
      },
    },
    playerOptions = { defaultVolume = 100 },
  })
  -- The v0.4 discord.lua integration subscribes to voice_state_update and
  -- voice_server_update and forwards both payloads to this manager.

  manager:on("nodeReady", function(node, resumed, session_id)
    utils.log("NODE", "NodeLink %s ready (resumed: %s, session: %s)",
      node.options.id, tostring(resumed), tostring(session_id))
  end)
  manager:on("nodeConnect", function(node)
    utils.log("NODE", "NodeLink %s WebSocket connected at /v4/websocket", node.options.id)
  end)
  manager:on("nodeDisconnect", function(node, reason)
    utils.log("WARN", "NodeLink %s disconnected: %s", node.options.id, tostring(reason or "connection closed"))
  end)
  manager:on("nodeReconnecting", function(node, attempt, delay)
    utils.log("NODE", "NodeLink %s reconnect %d in %dms", node.options.id, attempt, delay)
  end)
  manager:on("nodeError", function(node, err)
    utils.log("ERROR", "NodeLink %s error: %s", node.options.id, tostring(err))
  end)
  manager:on("nodeInfoError", function(node, err)
    utils.log("WARN", "NodeLink %s /v4/info check failed: %s", node.options.id, tostring(err))
  end)
  manager:on("nodeLinkReady", function(node, info)
    utils.log("NODE", "Confirmed NodeLink v3 on %s (version: %s)", node.options.id,
      tostring(info and info.version or "unknown"))
  end)
  manager:on("error", function(player, err)
    utils.log("ERROR", "Guild %s player error: %s",
      tostring(player and player.guildId or "?"), tostring(err))
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
    utils.log("ERROR", "Guild %s: NodeLink track error: %s", tostring(player.guildId), tostring(err))
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
  bot.musicSearchSource = config.nodelink.searchSource
  -- Slash command contexts expose discord.lua's underlying Client.
  bot.client.lavalink = manager
  manager:init()
  return manager
end

bot:on("application_command_error", function(ctx, err)
  utils.log("ERROR", "Slash command failed: %s", tostring(err))
  pcall(ctx.respond, ctx, "An internal error occurred while running this command.", { ephemeral = true })
end)

bot:on("ready", function()
  utils.log("BOT", "Logged in as %s (id: %s)", bot.user.username, bot.user.id)
  create_nodelink_client()
end)

bot:run(config.token)
