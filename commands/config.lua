local discord = require("discord.lua")
local music = require("../services/music")

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
    music.config(ctx, ctx:require_arg("action"), ctx:get_arg("setting"), ctx:get_arg("value"))
  end,
}
