local discord = require("discord.lua")
local bit = require("bit")
local interaction = require("../utils/interaction")
local settings = require("../services/settings")

local function boolean_value(value)
  value = type(value) == "string" and value:lower():match("^%s*(.-)%s*$") or ""
  if value == "true" or value == "yes" or value == "on" then return true end
  if value == "false" or value == "no" or value == "off" then return false end
  return nil
end

local function can_manage_guild(ctx)
  local permissions = tonumber(ctx.member_permissions)
  return permissions and bit and (bit.band(permissions, 8) ~= 0 or bit.band(permissions, 32) ~= 0)
end

return {
  name = "config",
  description = "Configure guild music settings",
  options = {
    {
      name = "action",
      description = "Show or update a setting",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
      choices = {
        { name = "Get", value = "get" },
        { name = "Set", value = "set" },
      },
    },
    {
      name = "setting",
      description = "Guild setting",
      type = discord.enums.OPTION_TYPE.STRING,
      required = false,
      choices = {
        { name = "Playlist limit", value = "playlist_limit" },
        { name = "Default queue page size", value = "queue_page_size" },
        { name = "Default volume", value = "default_volume" },
        { name = "Hide queue responses", value = "queue_add_hidden" },
        { name = "Announce next track", value = "auto_announce" },
        { name = "Leave after queue ends", value = "queue_end_delay" },
      },
    },
    {
      name = "value",
      description = "New value for set",
      type = discord.enums.OPTION_TYPE.STRING,
      required = false,
    },
  },
  callback = function(ctx)
    interaction.run(ctx, function()
      local guild_id = interaction.guild_id(ctx)
      if not guild_id then return end
      local action = ctx:require_arg("action")
      local current = settings.get(guild_id)
      if action == "get" then
        return interaction.reply(ctx, "", { embeds = {{
          title = "Music settings",
          color = 0x5865F2,
          fields = {
            { name = "Playlist limit", value = tostring(current.playlistLimit), inline = true },
            { name = "Queue page size", value = tostring(current.defaultQueuePageSize), inline = true },
            { name = "Default volume", value = tostring(current.defaultVolume) .. "%", inline = true },
            { name = "Hide queue responses", value = current.queueAddResponseHidden and "On" or "Off", inline = true },
            { name = "Auto announce", value = current.autoAnnounceNextSong and "On" or "Off", inline = true },
            { name = "Leave after queue ends", value = tostring(current.waitAfterQueueEmpties) .. "s", inline = true },
          },
        }}, ephemeral = true })
      end
      if action ~= "set" then return interaction.fail(ctx, "Action must be get or set.") end
      if not can_manage_guild(ctx) then
        return interaction.fail(ctx, "You need Manage Server permission to change settings.")
      end
      local setting, value = ctx:get_arg("setting"), ctx:get_arg("value")
      local number = tonumber(value)
      local updates
      if setting == "playlist_limit" and number and number >= 1 and number % 1 == 0 then
        updates = { playlistLimit = number }
      elseif setting == "queue_page_size" and number and number >= 1 and number <= 30 and number % 1 == 0 then
        updates = { defaultQueuePageSize = number }
      elseif setting == "default_volume" and number and number >= 0 and number <= 1000 and number % 1 == 0 then
        updates = { defaultVolume = number }
      elseif setting == "queue_add_hidden" then
        local parsed = boolean_value(value)
        if parsed ~= nil then updates = { queueAddResponseHidden = parsed } end
      elseif setting == "auto_announce" then
        local parsed = boolean_value(value)
        if parsed ~= nil then updates = { autoAnnounceNextSong = parsed } end
      elseif setting == "queue_end_delay" and number and number >= 0 and number % 1 == 0 then
        updates = { waitAfterQueueEmpties = number }
      end
      if not updates then return interaction.fail(ctx, "That value is invalid for the selected setting.") end
      settings.update(guild_id, updates)
      interaction.reply(ctx, "Setting updated.", { ephemeral = true })
    end)
  end,
}
