local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "fseek",
  description = "Seek forward in the current track",
  options = {
    {
      name = "time",
      description = "Duration: 90, 1m30s, or 01:30",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
    },
  },
  callback = function(ctx)
    music.fseek(ctx, ctx:require_arg("time"))
  end,
}
