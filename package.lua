return {
  name = "Lauffy",
  version = "0.1.0",
  description = "Discord music bot written in Lua with discord.lua and Lavalink",
  tags = { "discord", "music", "lavalink", "discord-lua" },
  license = "MIT",
  author = { name = "filispeen", email = "illayfilisp@gmail.com" },
  homepage = "https://github.com/filispeen/Lauffy",
  dependencies = {
    "filispeen/discord.lua@v1.0.3",
    "filispeen/lavalink.lua@v0.4.5"
  },
  files = {
    "main.lua",
    "!test*",
    "utils/**.lua",
    "services/**.lua",
    "commands/**.lua",
  }
}
