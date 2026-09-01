local interaction = require("../utils/interaction")
local format = require("../utils/format")

return {
  name = "nowplaying",
  description = "Show the currently playing track",
  callback = function(ctx)
    interaction.run(ctx, function()
      local guild_id = interaction.guild_id(ctx)
      if not guild_id then return end
      local manager = interaction.manager(ctx)
      if not manager then return end
      local player = manager:getPlayer(guild_id)
      if not player or not player.queue.current then return interaction.fail(ctx, "Nothing is playing right now.") end
      interaction.reply(ctx, "", { embeds = { format.now_playing_embed(player) } })
    end)
  end,
}
