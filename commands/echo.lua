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
  },
  callback = function(ctx)
    music.play(ctx, ctx:require_arg("query"))
  end,
}
