local discord = require("discord.lua")
local lavalink = require("lavalink.lua")

local env = require("./utils/env")
local utils = require("./utils/general")
env.load()

local token = process.env.TOKEN
if type(token) ~= "string" or token:match("^%s*$") then
  error("TOKEN is required. Set TOKEN in .env or provide it as an environment variable.")
end

local bot = discord(nil, discord.enums.combine_intents(
  discord.enums.INTENTS.GUILDS,
  discord.enums.INTENTS.GUILD_VOICE_STATES
))

utils.load_commands(bot)

local function log_track(level, player, track)
  local title = track and track.info and track.info.title or "unknown track"
  utils.log(level, "Guild %s: %s", tostring(player.guildId), tostring(title))
end

local function create_lavalink_manager()
  if bot.lavalink then return bot.lavalink end

  local manager = lavalink.discord(bot, {
    clientName = "lavalink-lua_" .. bot.user.id,
    nodes = {
      {
        id = "main",
        host = env.string(process.env.LAVALINK_HOST, "localhost"),
        port = env.number(process.env.LAVALINK_PORT, 2333, "LAVALINK_PORT"),
        authorization = env.string(process.env.LAVALINK_PASS, "youshallnotpass"),
        secure = env.boolean(process.env.LAVALINK_SECURE, false, "LAVALINK_SECURE"),
        resuming = env.boolean(process.env.LAVALINK_RESUME, true, "LAVALINK_RESUME"),
        resumeTimeout = env.number(process.env.LAVALINK_RESUME_TIMEOUT, 60, "LAVALINK_RESUME_TIMEOUT"),
        reconnectTries = env.number(process.env.LAVALINK_RECONNECT_TRIES, 5, "LAVALINK_RECONNECT_TRIES"),
        reconnectDelay = env.number(process.env.LAVALINK_RECONNECT_DELAY, 5000, "LAVALINK_RECONNECT_DELAY"),
      },
    },
    playerOptions = { defaultVolume = 100 },
  })

  manager:on("nodeReady", function(node, resumed, session_id)
    utils.log("NODE", "Node %s ready (resumed: %s, session: %s)", node.options.id, tostring(resumed), tostring(session_id))
  end)
  manager:on("nodeError", function(node, err)
    utils.log("ERROR", "Node %s error: %s", node.options.id, tostring(err))
  end)
  manager:on("error", function(player, err)
    utils.log("ERROR", "Guild %s player error: %s", tostring(player.guildId), tostring(err))
  end)
  manager:on("trackStart", function(player, track)
    log_track("TRACK", player, track)
  end)
  manager:on("queueEnd", function(player)
    utils.log("TRACK", "Guild %s: queue ended", tostring(player.guildId))
  end)

  bot.lavalink = manager
  manager:init()
  return manager
end

bot:on("ready", function()
  utils.log("BOT", "Logged in as %s (id: %s)", bot.user.username, "<@" .. bot.user.id .. ">")
  create_lavalink_manager()
end)

bot:run(token)