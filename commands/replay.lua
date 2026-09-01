local interaction = require("../utils/interaction")

return {
  name = "replay",
  description = "Restart the current track",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local track = player.queue.current
      if not track then return interaction.fail(ctx, "There is no active track.") end
      if track.info and track.info.isStream then return interaction.fail(ctx, "Live streams cannot be seeked.") end
      player:seek(0)
      interaction.reply(ctx, "Track restarted.")
    end)
  end,
}
