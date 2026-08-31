local discord = require("discord.lua")

return {
  name = "echo",
  description = "Echoes back the input text.",
  options = {
    {
      name = "text",
      description = "The text to echo back.",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
    }
  },
  callback = function(ctx)
    ctx:respond(ctx.args.text, { ephemeral = false })
  end,
}