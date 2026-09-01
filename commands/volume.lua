local discord = require("discord.lua")
local interaction = require("../utils/interaction")

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
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local level = tonumber(ctx:require_arg("level"))
      if not level or level < 0 or level > 1000 or level % 1 ~= 0 then
        return interaction.fail(ctx, "Volume must be an integer between 0 and 1000.")
      end
      player:setVolume(level)
      interaction.reply(ctx, string.format("Volume set to %d%%.", level))
    end)
  end,
}
