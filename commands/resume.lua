local interaction = require("../utils/interaction")

return {
  name = "resume",
  description = "Resume the current track",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      if not player.paused then return interaction.fail(ctx, "Playback is not paused.") end
      player:resume()
      interaction.reply(ctx, "Playback resumed.")
    end)
  end,
}
