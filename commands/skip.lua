local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "skip",
  description = "Skip the current track or jump within the queue",
  options = {
    {
      name = "number",
      description = "Queue position to play, default: 1",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = false,
    },
  },
  callback = function(ctx)
    music.skip(ctx, ctx:get_arg("number", 1))
  end,
}
