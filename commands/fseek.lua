local discord = require("discord.lua")
local format = require("../utils/format")
local interaction = require("../utils/interaction")
local validation = require("../utils/validation")

return {
  name = "fseek",
  description = "Seek forward in the current track",
  options = {
    {
      name = "time",
      description = "Duration: 90, 1m30s, or 01:30",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
    },
  },
  callback = function(ctx)
    interaction.run(ctx, function()
      local player = interaction.controlled_player(ctx)
      if not player then return end
      local offset = validation.parse_duration(ctx:require_arg("time"))
      if not offset then return interaction.fail(ctx, "Use a duration such as 90, 1m30s, or 01:30.") end
      local position = player:getPosition() + offset
      local track = player.queue.current
      if not track then return interaction.fail(ctx, "There is no active track.") end
      if track.info and track.info.isStream then return interaction.fail(ctx, "Live streams cannot be seeked.") end
      if type(track.info and track.info.length) == "number" and position > track.info.length then
        return interaction.fail(ctx, "That position is beyond the end of the track.")
      end
      player:seek(position)
      interaction.reply(ctx, "Seeked forward to " .. format.duration(position) .. ".")
    end)
  end,
}
