local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "loop",
  description = "Set the playback loop mode",
  options = {
    {
      name = "mode",
      description = "Loop mode",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
      choices = {
        { name = "Off", value = "off" },
        { name = "Track", value = "track" },
        { name = "Queue", value = "queue" },
      },
    },
  },
  callback = function(ctx)
    music.loop(ctx, ctx:require_arg("mode"))
  end,
}
