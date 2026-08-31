local discord = require("discord.lua")
local lavalink = require("lavalink.lua")

local env = require("./utils/env")
local utils = require("./utils/general")
local config = env.config()

local bot = discord.Bot(nil, discord.enums.combine_intents(
  discord.enums.INTENTS.GUILDS,
  discord.enums.INTENTS.GUILD_VOICE_STATES
))

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
  end)
  manager:on("trackError", function(player, track, err)
    log_track("ERROR", player, track)
    utils.log("ERROR", "Guild %s: Lavalink track error: %s", tostring(player.guildId), tostring(err))
    player:skip(nil, false)
  end)
  manager:on("queueEnd", function(player)
    utils.log("TRACK", "Guild %s: queue ended; disconnecting", tostring(player.guildId))
    player:disconnect(true)
  end)

  bot.lavalink = manager
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
  create_lavalink_client()
end)

bot:run(config.token)
