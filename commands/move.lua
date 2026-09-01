local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "move",
  description = "Move an upcoming track within the queue",
  options = {
    {
      name = "from",
      description = "Current upcoming queue position",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = true,
    },
    {
      name = "to",
      description = "New upcoming queue position",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = true,
    },
  },
  callback = function(ctx)
    music.move(ctx, ctx:require_arg("from"), ctx:require_arg("to"))
  end,
}
