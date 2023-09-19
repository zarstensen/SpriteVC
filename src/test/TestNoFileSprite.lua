require 'Test'
require 'SpriteHistory'

TestNoFileSprite = inherit(Test, {})

function TestNoFileSprite:_new()
    Test._new(self, "No File Sprite")
end

function TestNoFileSprite:spriteHistoryLocation()
    local history = self._createNoFileSpriteHisory()

    -- create sprite history object

    history:storeHistory(history:historyDir())

    print(history:historyDir())
    assert(app.fs.isDirectory(app.fs.joinPath(app.fs.tempPath, "spritevc/Sprite-0001-history")), "Sprite history folder is missing")
    
    app.sprite:close()
end

function TestNoFileSprite._createNoFileSpriteHisory()
    -- create new sprite
    app.command.NewFile{ ui=false, width = 16, height = 16 }
    
    assert(app.sprite, "New sprite is not active sprite.")
    assert(not app.fs.isFile(app.sprite.filename), string.format("New sprite is associated with a file on disk.\nFilename: '%s'", app.sprite.filename))
    
    local history = SpriteHistory:new(app.sprite)

    assert(history, "Failed to create SpriteHistory for app")

    return history
end
