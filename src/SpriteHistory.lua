require 'Inherit'
require 'Serializer'

---@class SpriteSnapshot
SpriteSnapshot = inherit(NewObj, {})

---@param id string
---@param name string | nil
---@param is_temp boolean
---@return SpriteSnapshot
function SpriteSnapshot:new(id, name, is_temp)
    return NewObj.new(self, id, name, is_temp)
end

function SpriteSnapshot:_new(id, name, is_temp)
    self.id = id
    self.name = name
    self.is_temp = is_temp
end

---@class SpriteHistory
SpriteHistory = inherit(NewObj, {
    MAIN_BRANCH = "main"
})

--- Construct a SpriteHistory instance, that manages the history of the passed sprite.
---@param sprite SpriteHistory
function SpriteHistory:new(sprite)
    return NewObj.new(self, sprite)
end

---@see SpriteHistory.new
function SpriteHistory:_new(sprite)
    self.recent_history_size = 10
    self.all_history_size = 100

    self.sprite = sprite

    self.active_branch = self.MAIN_BRANCH

    --- In memory storage for all snapshots currently managed by the SpriteHistory instance.
    --- MAIN_BRANCH branch must not be deleted.
    ---@type table<string, SpriteSnapshot[]>
    self.branches = { [ self.MAIN_BRANCH ] = {} }

    if app.fs.isDirectory(self:historyDir()) then
        self:loadHistory(self:historyDir())
    end

end

function SpriteHistory:snapshot(name, is_temp)

    local snapshot = SpriteSnapshot:new(tostring(Uuid()), name, is_temp)

    table.insert(self.branches[self.active_branch], snapshot)
end

--- Return directory where the history of the sprite should be stored.
--- The directory will be relative to the sprites file location, or the systems temporary path, if the sprite is not associated with a file.
---@return string
function SpriteHistory:historyDir()

    if not app.fs.isFile(self.sprite.filename) then
        return app.fs.joinPath(app.fs.joinPath(app.fs.tempPath, "spritevc"), app.fs.filePathAndTitle(self.sprite.filename) .. "-history")
    end

    return app.fs.filePathAndTitle(self.sprite.filename) .. "-history"
end

function SpriteHistory:snapshotFile(branch, snapshot)
    return app.fs.joinPath(app.fs.joinPath(self:historyDir(), branch), snapshot.id .. ".aseprite")
end

function SpriteHistory:storeHistory(history_dir)
    app.fs.makeAllDirectories(history_dir)
end