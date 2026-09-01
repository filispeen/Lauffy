local discord = require("discord.lua")
local music = require("../services/music")

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
    query = music.autocomplete,
  },
  callback = function(ctx)
    music.play(ctx, ctx:require_arg("query"), {
      immediate = ctx:get_arg("immediate", false),
      shuffle = ctx:get_arg("shuffle", false),
      skip = ctx:get_arg("skip", false),
    })
  end,
}
