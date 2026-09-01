local interaction = require("../utils/interaction")

return {
  name = "pause",
  description = "Pause the current track",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      if player.paused then return interaction.fail(ctx, "Playback is already paused.") end
      player:pause(true)
      interaction.reply(ctx, "Playback paused.")
    end)
  end,
}
