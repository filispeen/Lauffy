local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "queue",
  description = "Show the current queue",
  options = {
    {
      name = "page",
      description = "Queue page, default: 1",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = false,
    },
  },
  callback = function(ctx)
    music.queue(ctx, ctx:get_arg("page", 1))
  end,
}
