local discord = require("discord.lua")
local interaction = require("../utils/interaction")
local validation = require("../utils/validation")

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
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local count = validation.positive_integer(ctx:get_arg("number", 1))
      if not count then return interaction.fail(ctx, "Skip position must be an integer starting at 1.") end
      if not player.queue.current then return interaction.fail(ctx, "There is no active track.") end
      player:skip(count, false)
      interaction.reply(ctx, count == 1 and "Track skipped." or string.format("Skipped to queue position %d.", count))
    end)
  end,
}
