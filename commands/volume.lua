local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "volume",
  description = "Set playback volume from 0 to 1000",
  options = {
    {
      name = "level",
      description = "Volume level from 0 to 1000",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = true,
    },
  },
  callback = function(ctx)
    music.volume(ctx, ctx:require_arg("level"))
  end,
}
