local interaction = require("../utils/interaction")

return {
  name = "shuffle",
  description = "Shuffle upcoming tracks",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      if player.queue:size() < 2 then
        return interaction.fail(ctx, "At least two queued tracks are required to shuffle.")
      end
      player.queue:shuffle()
      interaction.reply(ctx, "Queue shuffled.")
    end)
  end,
}
