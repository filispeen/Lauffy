local discord = require("discord.lua")
local lavalink = require("lavalink.lua")
local uv = require("uv")
local http = require("coro-http")
local json = require("json")

local env = require("./utils/env")
local settings = require("./services/settings")
local utils = require("./utils/general")
local config = env.config()
local interaction_dispatch_registered = false

local bot = discord.Bot(nil, discord.enums.combine_intents(
  discord.enums.INTENTS.GUILDS,
  discord.enums.INTENTS.GUILD_VOICE_STATES
))

local function install_interaction_response_transport()
  local rest = bot.client and bot.client.rest
  if not rest then return end

  function rest:create_interaction_response(interaction_id, interaction_token, payload, files)
    if files and #files > 0 then
      error("Interaction response files are not supported by this transport.")
    end

    local url = string.format(
      "https://discord.com/api/v10/interactions/%s/%s/callback",
      tostring(interaction_id), tostring(interaction_token)
    )
    local ok, response, body = pcall(http.request, "POST", url, {
      { "Content-Type", "application/json" },
      { "User-Agent", "Lauffy" },
    }, json.encode(payload))
    if not ok then
      error("Discord interaction response request failed: " .. tostring(response))
    end
    if response.code >= 400 then
      error(string.format("Discord interaction response HTTP %d: %s", response.code, tostring(body)))
    end
    return body
  end
end

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
    utils.log("ERROR", "Node %s error: %s", node.options.id, tostring(err))
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
    utils.log("ERROR", "Guild %s: Lavalink track error: %s", tostring(player.guildId), tostring(err))
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

bot:on("application_command_error", function(_, ctx, err)
  utils.log("ERROR", "Slash command failed: %s", tostring(err))
  pcall(ctx.respond, ctx, "An internal error occurred while running this command.", { ephemeral = true })
end)

bot:on("ready", function()
  install_interaction_response_transport()

  if not interaction_dispatch_registered then
    bot.client.gateway:on_dispatch("INTERACTION_CREATE", function(interaction)
      utils.log("DEBUG", "Received interaction type %s", tostring(interaction and interaction.type))
      local ok, err = pcall(bot.dispatch_interaction, bot, interaction)
      if not ok then utils.log("ERROR", "Interaction dispatch failed: %s", tostring(err)) end
    end)
    interaction_dispatch_registered = true
  end

  utils.log("BOT", "Logged in as %s (id: %s)", bot.user.username, bot.user.id)
  create_lavalink_client()
end)

bot:run(config.token)
