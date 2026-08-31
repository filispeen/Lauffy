  return {
    name = "Lauffy",
    version = "0.0.1",
    description = "Discord music bot written in lua using disocrd.lua",
    tags = { "discord", "music", "discord-lua" },
    license = "MIT",
    author = { name = "filispeen", email = "illayfilisp@gmail.com" },
    homepage = "https://github.com/filispeen/Lauffy",
    dependencies = {
      "filispeen/discord.lua@v1.0.1",
      "filispeen/lavalink.lua@v0.3.5"
    },
    files = {
      "main.lua",
      "!test*",
      "utils/**.lua",
      "commands/**.lua",
    }
  }