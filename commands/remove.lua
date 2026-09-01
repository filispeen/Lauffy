local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "remove",
  description = "Remove upcoming tracks from the queue",
  options = {
    {
      name = "position",
      description = "First upcoming queue position",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = true,
    },
    {
      name = "range",
      description = "Number of tracks to remove, default: 1",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = false,
    },
  },
  callback = function(ctx)
    music.remove(ctx, ctx:require_arg("position"), ctx:get_arg("range", 1))
  end,
}
