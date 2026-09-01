local discord = require("discord.lua")
local music = require("../services/music")

return {
  name = "favorites",
  description = "Save and play favorite Lavalink queries",
  options = {
    {
      name = "action",
      description = "Favorite action",
      type = discord.enums.OPTION_TYPE.STRING,
      required = true,
      choices = {
        { name = "Use", value = "use" },
        { name = "List", value = "list" },
        { name = "Create", value = "create" },
        { name = "Remove", value = "remove" },
      },
    },
    {
      name = "name",
      description = "Favorite name",
      type = discord.enums.OPTION_TYPE.STRING,
      required = false,
    },
    {
      name = "query",
      description = "Search text or a provider URL for create",
      type = discord.enums.OPTION_TYPE.STRING,
      required = false,
    },
    {
      name = "immediate",
      description = "Add the favorite to the front of the queue",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
    {
      name = "shuffle",
      description = "Shuffle tracks loaded from the favorite",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
    {
      name = "skip",
      description = "Skip the current track after adding",
      type = discord.enums.OPTION_TYPE.BOOLEAN,
      required = false,
    },
  },
  autocomplete = {
    name = music.favorite_autocomplete,
  },
  callback = function(ctx)
    music.favorites(ctx, ctx:require_arg("action"), ctx:get_arg("name"), ctx:get_arg("query"), {
      immediate = ctx:get_arg("immediate", false),
      shuffle = ctx:get_arg("shuffle", false),
      skip = ctx:get_arg("skip", false),
    })
  end,
}
