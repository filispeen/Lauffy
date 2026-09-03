local interaction = require("../utils/interaction")

return {
  name = "stop",
  description = "Stop playback and clear the queue",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      player:stopPlaying(true)
      player:disconnect(true)
      interaction.reply(ctx, "Playback stopped and the queue was cleared.")
    end)
  end,
}
