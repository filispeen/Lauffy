local discord = require("discord.lua")
local interaction = require("../utils/interaction")
local validation = require("../utils/validation")

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
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local from = validation.positive_integer(ctx:require_arg("from"))
      local to = validation.positive_integer(ctx:require_arg("to"))
      if not from or not to then return interaction.fail(ctx, "From and to must be positive integers.") end
      local size = player.queue:size()
      if from > size or to > size then return interaction.fail(ctx, "That queue position does not exist.") end
      if from == to then return interaction.fail(ctx, "That track is already at that position.") end
      local track = player.queue:remove(from)
      player.queue:addAt(to, track[1])
      interaction.reply(ctx, string.format("Moved track from %d to %d.", from, to))
    end)
  end,
}
