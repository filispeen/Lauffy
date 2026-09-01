local discord = require("discord.lua")
local format = require("../utils/format")
local interaction = require("../utils/interaction")
local settings = require("../services/settings")

return {
  name = "queue",
  description = "Show the current queue",
  options = {
    {
      name = "page",
      description = "Queue page, default: 1",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = false,
    },
    {
      name = "page_size",
      description = "Tracks per page, default: guild setting",
      type = discord.enums.OPTION_TYPE.INTEGER,
      required = false,
    },
  },
  callback = function(ctx)
    interaction.run(ctx, function()
      local guild_id = interaction.guild_id(ctx)
      if not guild_id then return end
      local manager = interaction.manager(ctx)
      if not manager then return end
      local player = manager:getPlayer(guild_id)
      if not player or not player.queue.current then return interaction.fail(ctx, "The queue is empty.") end
      local page = tonumber(ctx:get_arg("page", 1)) or 1
      local page_size = tonumber(ctx:get_arg("page_size")) or settings.get(guild_id).defaultQueuePageSize or 10
      if page < 1 or page % 1 ~= 0 then return interaction.fail(ctx, "Page must be an integer starting at 1.") end
      if page_size < 1 or page_size > 30 or page_size % 1 ~= 0 then
        return interaction.fail(ctx, "Page size must be an integer between 1 and 30.")
      end
      local embed, total_pages = format.queue_embed(player, page, page_size)
      if page > total_pages then
        return interaction.fail(ctx, string.format("That page does not exist. Available pages: %d.", total_pages))
      end
      interaction.reply(ctx, "", { embeds = { embed } })
    end)
  end,
}
