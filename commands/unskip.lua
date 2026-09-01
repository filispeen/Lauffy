local music = require("../services/music")

return {
  name = "unskip",
  description = "Return to the previous track",
  callback = function(ctx)
    music.unskip(ctx)
  end,
}
