local music = require("../services/music")

return {
  name = "clear",
  description = "Clear upcoming tracks",
  callback = function(ctx)
    music.clear(ctx)
  end,
}
