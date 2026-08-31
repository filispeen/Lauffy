local music = require("../services/music")

return {
  name = "disconnect",
  description = "Leave the voice channel",
  callback = function(ctx)
    music.disconnect(ctx)
  end,
}
