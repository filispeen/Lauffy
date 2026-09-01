local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "seek",
  description = "Seek to an absolute track position",
  options = {
    {
      name = "time",
      description = "Duration: 90, 1m30s, or 01:30",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
    },
  },
  callback = function(ctx)
    music.seek(ctx, ctx:require_arg("time"))
  end,
}
