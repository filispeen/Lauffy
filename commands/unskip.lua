local interaction = require("../utils/interaction")

return {
  name = "unskip",
  description = "Return to the previous track",
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local previous = table.remove(player.queue.previous, 1)
      if not previous then return interaction.fail(ctx, "There is no previous track.") end
      if player.queue.current then player.queue:addAt(1, player.queue.current) end
      player.queue.current = previous
      player.position = 0
      player:play()
      interaction.reply(ctx, "Returned to the previous track.")
    end)
  end,
}
