local interaction = require("../utils/interaction")

return {
  name = "clear",
  description = "Clear upcoming tracks",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      if not player.queue.current then return interaction.fail(ctx, "There is no active track.") end
      local count = player.queue:size()
      if count == 0 then return interaction.fail(ctx, "There are no upcoming tracks to clear.") end
      player.queue:clear()
      interaction.reply(ctx, string.format("Cleared %d upcoming track%s.", count, count == 1 and "" or "s"))
    end)
  end,
}
