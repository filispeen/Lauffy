local interaction = require("../utils/interaction")

return {
  name = "disconnect",
  description = "Leave the voice channel",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      player:disconnect(true)
      interaction.reply(ctx, "Disconnected from the voice channel.")
    end)
  end,
}
