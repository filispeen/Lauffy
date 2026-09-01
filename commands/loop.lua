local discord = require("discord.lua")
local interaction = require("../utils/interaction")

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
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local mode = ctx:require_arg("mode")
      if mode ~= "off" and mode ~= "track" and mode ~= "queue" then
        return interaction.fail(ctx, "Loop mode must be off, track, or queue.")
      end
      player:setRepeatMode(mode)
      interaction.reply(ctx, "Loop mode set to " .. mode .. ".")
    end)
  end,
}
