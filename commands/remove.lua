local discord = require("discord.lua")
local interaction = require("../utils/interaction")
local validation = require("../utils/validation")

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
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local position = validation.positive_integer(ctx:require_arg("position"))
      local range = validation.positive_integer(ctx:get_arg("range", 1))
      if not position or not range then
        return interaction.fail(ctx, "Position and range must be positive integers.")
      end
      local finish = position + range - 1
      if position > player.queue:size() or finish > player.queue:size() then
        return interaction.fail(ctx, "That queue range does not exist.")
      end
      player.queue:remove(position, finish)
      interaction.reply(ctx, string.format("Removed %d upcoming track%s.", range, range == 1 and "" or "s"))
    end)
  end,
}
