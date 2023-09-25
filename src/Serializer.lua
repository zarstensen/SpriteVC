require 'inherit'
Json = require 'json'

--- Base class for all serializers.
---
--- The main job of this and all of the derived classes is converting any userdata object into a table, that then can be stored on disk for later loading.
--- 
--- Derived serializers should use Serializer.register,
--- in order for them to be used when calling genericSerialize and genericDeserialize.
---
--- Derived classes should implement a serialize (optional), deserialize, beforeStore (optional) and beforeLoad (optional) function.
---
---@class Serializer
Serializer = inherit(NewObj, { serializers = {}, json_file_name = "obj_data.json", copy_fields = { } })

--- Register a serializer and tie it to the passed uid.
---@param uid string
---@param serializer Serializer | any
function Serializer:register(uid, serializer)
    self.serializers[uid] = serializer
end

--- Serializes the passed object with a suitable serializer registered using Serialier.register.
--- If no suitable serializer if found, the object itself is returned.
---@param obj any
---@param serializer_uid string kwarg
--- Force serializer to use this specific serializer uid.
---@param args any [] kwarg
-- Arguments to pass to the found serializers serialize function
---@return table
function Serializer:genericSerialize(obj, kwargs)

    kwargs = kwargs or { }
    
    local serializer_uid = kwargs.uid
    local args = kwargs.args or { }
    
    if not serializer_uid then
        for uid, s in pairs(self.serializers) do
            if s:canSerialize(obj) then
                serializer_uid = uid
            end
        end
    end

    if serializer_uid then
        return { uid = serializer_uid, data = self.serializers[serializer_uid]:serialize(obj, table.unpack(args)) }
    end
    
    return obj
end

--- Deserializes a serialized object returned from genericSerialize, using the same serialier that serialized it.
--- If the serialized object did not use any serializers during genericSerialize, the serialized object is returned. 
---@param serialized table
---@param args any[] kwarg
--- Arguments to pass to the serializers deserialize function.
---@return any
function Serializer:genericDeserialize(serialized, kwargs)
    if type(serialized) ~= "table" or not serialized.uid or not self.serializers[serialized.uid] then
        return serialized
    end

    kwargs = kwargs or { }
    local args = kwargs.args or { }

    return self.serializers[serialized.uid]:deserialize(serialized.data, table.unpack(args))
end

--- Store the serialized object to the passed directory location
---@param serialized_obj table a table returned from a Serializer.genericSerialize call.
---@param location string directory to store serialized data.
function Serializer:store(serialized_obj, location)

    app.fs.makeAllDirectories(location)

    -- convert serialized object into a text compatible format.

    local storable_obj = self:makeStoreCompatible(serialized_obj, location)

    local storage_file_name = app.fs.joinPath(location, self.json_file_name)
    local storage_file = io.open(storage_file_name, 'w')

    if not storage_file then
        error(string.format("Could not open file %s!", storage_file_name))
    end 

    storage_file:write(Json.encode(storable_obj))
    storage_file:close()
end

--- Load a serialized object from disk.
---@param location string directory previously populated with data from a Serializer.store call.
---@return table | nil serialized_obj Serialized object, or nil if failed.
function Serializer:load(location)

    local storage_file_name = app.fs.joinPath(location, self.json_file_name)

    if not app.fs.isDirectory(location) or not app.fs.isFile(storage_file_name) then
        return nil
    end

    local storage_file = io.open(storage_file_name, 'r')

    local loadable_obj = Json.decode(storage_file:read("a"))

    storage_file:close()

    return self:makeLoadCompatible(loadable_obj, location)
end

--- Converts the given object into a disk storable table.
---
--- the returned object should avoid direct references to objects and instead create copies.
---@param obj any
---@return table serialized_obj
function Serializer:serialize(obj)
    local obj_table = {}

    self:copyFields(self.copy_fields, obj, obj_table, Serializer.genericSerialize)

    return obj_table
end

--- Converts the given serialized object into a corresponding deserialized object
---@param s_obj table
---@param obj any object to deserialize s_obj in to.
---@return any obj
function Serializer:deserialize(s_obj, obj)
    self:copyFields(self.copy_fields, s_obj, obj, Serializer.genericDeserialize)
    return obj
end

--- Return whether the serializer instance is able to serialize the given object.
---@param obj any
---@return boolean | nil can_serialize nil on failure
function Serializer:canSerialize(obj)
    self:_notImplementedErr("canSerialize")
end

--- Gets called before the serialized obj is saved to disk in text form.
--- Should store any additional data tied to the object, which cannot be embedded in its text form.
--- This additional data should be relative to the passed store_location.
---
--- Returns the remaining table values which can safely be converted to their text form, and stored.
---
--- By default this does nothing, and returns the passed object.
---
---@param obj any
---@param store_location string
---@return any
function Serializer:beforeStore(obj, store_location)
    return obj
end

--- Gets called after the serialized obj has been loaded into memory from its text form.
--- Should return the object loaded from disk populated with the additional data stored during the Serializer.beforeStore call.
---
--- Returns stored_obj without modifications by default.
---
---@param stored_obj any
---@param store_location any
---@return any
function Serializer:beforeLoad(stored_obj, store_location)
    return stored_obj
end

--- Copy the passed field values from source_obj to target_obj.
---@param fields string[]
---@param source_obj any
---@param target_obj any
---@param convert_method fun(ser: Serializer, field: any): any
--- Method to pass field value through, before assigning it to target_obj.
--- Should be used in order to make sure any fields of the object are also serialized / deserialized.
function Serializer:copyFields(fields, source_obj, target_obj, convert_method)
    for _, field in ipairs(fields) do
        target_obj[field] = convert_method(self, source_obj[field])
    end
end

function Serializer:_notImplementedErr(func_name)
    local serializer_id = nil

    for id, serializer in pairs(Serializer.serializers) do
        if serializer == self then
            serializer_id = id
        end
    end

    assert(false, string.format("%s not implemented for [%s]", func_name, serializer_id))
end

--- Makes the passed serialized object compatible to store at the passed store location.
---
---@param obj table
---@param location string
---@return table compatible_obj
function Serializer:makeStoreCompatible(obj, location)
    -- check if object has been serialized
    if type(obj) ~= "table" or not obj.uid then
        return obj
    end
    
    -- serialized objects may have fields which also require special processing before storing.
    -- this is only possible if they are tables.

    if type(obj.data) == "table" then
        for field, value in pairs(obj.data) do
            obj.data[field] = self:makeStoreCompatible(value, location)
        end
    end

    obj.data = self.serializers[obj.uid]:beforeStore(obj.data, location)
    
    return obj
end

--- Makes the passed serialized object loaded from disk, compatible with in memory storage.
---
---@param obj table
---@param location string
---@return table
function Serializer:makeLoadCompatible(obj, location)
        -- check if object has been serialized
        if type(obj) ~= "table" or not obj.uid then
            return obj
        end
        
        -- serialized objects may have fields which also require special processing before storing.
        -- this is only possible if they are tables.
        
        if type(obj.data) == "table" then
            for field, value in pairs(obj.data) do
                obj.data[field] = self:makeLoadCompatible(value, location)
            end
        end

        obj.data = self.serializers[obj.uid]:beforeLoad(obj.data, location)

        return obj
end


---@class ColorSerializer
ColorSerializer = inherit(Serializer, { })
Serializer:register("Color", ColorSerializer)

---@param color any
---@return boolean
function ColorSerializer:canSerialize(color)
    return type(color) == "userdata" and color.__name == "app::Color"
end

---@param color Color
---@return number
function ColorSerializer:serialize(color)
    return color.rgbaPixel
end

---@param color table
---@return Color
function ColorSerializer:deserialize(color)
    return Color(color)
end


---@class RectSerializer
RectSerializer = inherit(Serializer, { copy_fields = { "x", "y", "w", "h" } })
Serializer:register("Rectangle", RectSerializer)

---@param rect any
---@return boolean
function RectSerializer:canSerialize(rect)
    return type(rect) == "userdata" and rect.__name == "gfx::Rect"
end

---@param rect_table table
---@return Rectangle
function RectSerializer:deserialize(rect_table)
    return Rectangle(rect_table.x, rect_table.y, rect_table.w, rect_table.h)
end


---@class PointSerializer
PointSerializer = inherit(Serializer, { copy_fields = { "x", "y" } })
Serializer:register("Point", PointSerializer)

---@param point any
---@return boolean
function PointSerializer:canSerialize(point)
    return type(point) == "userdata" and point.__name == "gfx::Point"
end

---@param point_table table
---@return Point
function PointSerializer:deserialize(point_table)
    return Point(point_table.x, point_table.y)
end

---@class SizeSerializer
SizeSerializer = inherit(Serializer, { copy_fields = { "w", "h" } })
Serializer:register("Size", SizeSerializer)

---@param size any
---@return boolean
function SizeSerializer:canSerialize(size)
    return type(size) == "userdata" and size.__name == "gfx::Size"
end

---@param size_table any
---@return unknown
function SizeSerializer:deserialize(size_table)
    return Size(size_table.w, size_table.h)
end


---@class FrameSerializer
FrameSerializer = inherit(Serializer, { copy_fields = { "duration", "frameNumber" }})
Serializer:register("Frame", FrameSerializer)

---@param frame any
---@return boolean
function FrameSerializer:canSerialize(frame)
    return type(frame) == "userdata" and frame.__name == "FrameObj"
end

--- When deserializing, additional empty frames may be created inbetween the furthest current frame in sprite,
--- As frames can only differ by 1, relative to their neighbours.
---
---@param frame table
---@param sprite Sprite
---@return Frame
function FrameSerializer:deserialize(frame, sprite)
    -- all frames up to frame.frameNumber must be present in the sprite for this to work.
    sprite.frames[frame.frameNumber].duration = frame.duration

    return sprite.frames[frame.frameNumber]
end


---@class TagSerializer
TagSerializer = inherit(Serializer, { copy_fields = { "name", "aniDir", "color", "repeats", "data", "properties" } })
Serializer:register("Tag", TagSerializer)

---@param tag any
---@return boolean
function TagSerializer:canSerialize(tag)
    return type(tag) == "userdata" and tag.__name == "Tag"
end

---@param tag Tag
---@return table
function TagSerializer:serialize(tag)
    local tag_table = Serializer.serialize(self, tag)

    tag_table.from_frame = tag.fromFrame.frameNumber
    tag_table.to_frame = tag.toFrame.frameNumber

    return tag_table
end

---@param tag_table table
---@param sprite Sprite sprite to add tag to, must have all frames the tag is spanning.
---@return Tag
function TagSerializer:deserialize(tag_table, sprite)
    return Serializer.deserialize(self, tag_table, sprite:newTag(tag_table.from_frame, tag_table.to_frame))
end


--- Serializer for Aseprite Image object.
--- Id of serialized image may (probably will) change, when it is loaded from disk,
--- as the id of an image, is not modifyable by extensions. 
---
---@class ImageSerializer
ImageSerializer = inherit(Serializer, { })
Serializer:register("Image", ImageSerializer)

---@param image any
---@return boolean
function ImageSerializer:canSerialize(image)
    if type(image) ~= "userdata" or image.__name ~= "ImageObj" then
        return false
    end

    local layer = nil

    -- even if cel is not nil, it might be seen as nil internally in aseprite,
    -- so do a pcall to catch any errors which may happen if this is the case
    if image.cel then
        pcall(function()
            layer = image.cel.layer
        end)
    end

    --- @see TilemapImageSerializer for why the layer type cannot be Tilemap
    return not layer or not layer.isTilemap
end

---@param image Image
---@return Image
function ImageSerializer:serialize(image)
    -- do nothing for the image object, as the storing of the image itself happens during file store,
    -- to avoid depending on files for the in memory serialized object.
    return Image(image)
end

---@param image Image
---@return Image
function ImageSerializer:deserialize(image)
    return image
end

---@param image Image
---@param store_location string
---@return number
function ImageSerializer:beforeStore(image, store_location)
    image:saveAs(app.fs.joinPath(store_location, string.format("/images/%s.png", image.id)))

    return image.id
end

---@param image_id number
---@param store_location string
---@return Image
function ImageSerializer:beforeLoad(image_id, store_location)
    return Image{ fromFile = app.fs.joinPath(store_location, string.format("/images/%s.png", image_id)) }
end


---@class PaletteSerializer
PaletteSerializer = inherit(Serializer, { })
Serializer:register("Palette", PaletteSerializer)

---@param palette any
---@return boolean
function PaletteSerializer:canSerialize(palette)
    return type(palette) == "userdata" and palette.__name == "PaletteObj"
end

---@param palette Palette
---@return Palette
function PaletteSerializer:serialize(palette)
    -- similar to image serializer, in that all the important logic happens during store and load from disk.
    return Palette(palette)
end

---@param palette Palette
---@return Palette
function PaletteSerializer:deserialize(palette)
    return palette
end

--- Store the palette in a file identified by the palettes frame,
--- This is not really useful now, as aseprite has yet to implement multiple palettes per sprite.
---
---@param palette Palette
---@param location string
---@return string file_name
function PaletteSerializer:beforeStore(palette, location)
    
    local file_name = "palette-%i-.gpl"

    if palette.frame then
        file_name = string.format(file_name, palette.frame.frameNumber)
    else
        file_name = string.format(file_name, 0)
    end

    palette:saveAs(app.fs.joinPath(location, file_name))

    return file_name
end

---@param file_name string
---@param location string
---@return Palette
function PaletteSerializer:beforeLoad(file_name, location)
    return Palette{ fromFile = app.fs.joinPath(location, file_name) }
end


---@class CelSerializer
CelSerializer = inherit(Serializer, { copy_fields = { "position", "opacity", "zIndex", "color", "data", "properties" }})
Serializer:register("Cel", CelSerializer)

---@param cel any
---@return boolean
function CelSerializer:canSerialize(cel)
    return type(cel) == "userdata" and cel.__name == "Cel"
end


---@param cel Cel
---@param image_table table
---@return table
function CelSerializer:serialize(cel, image_table)
    local cel_table = Serializer.serialize(self, cel)

    cel_table.image_id = tostring(cel.image.id)
    cel_table.frame = cel.frameNumber

    --- Serializing a cel also requires the serialization of its image, but since cels may share images, we store these serialized images in a separate table,
    --- in order to preserve the cels shared images.

    if not image_table[cel_table.image_id] then
        image_table[cel_table.image_id] = Serializer:genericSerialize(cel.image)
    end

    return cel_table
end

---@param cel_table table
---@param layer Layer layer to add cel to.
---@param sprite Sprite sprite to add cel to.
---@param image_table table same table passed in CelSerializer.serialize
---@return Cel
function CelSerializer:deserialize(cel_table, layer, sprite, image_table)
    local cel = layer.cels[cel_table.frame]

    if not cel then
        cel = sprite:newCel(layer, cel_table.frame)
    end
    
    cel = Serializer.deserialize(self, cel_table, cel)
    
    cel.image = Serializer:genericDeserialize(image_table[cel_table.image_id])

    return cel
end


---@class SliceSerializer
SliceSerializer = inherit(Serializer, { copy_fields = { "bounds", "center", "color", "data", "name", "pivot", "properties" } })
Serializer:register("Slice", SliceSerializer)

---@param slice any
---@return boolean
function SliceSerializer:canSerialize(slice)
    return type(slice) == "userdata" and slice.__name == "Slice"
end

---@param slice_table table
---@param sprite Sprite
---@return Slice
function SliceSerializer:deserialize(slice_table, sprite)
    return Serializer.deserialize(self, slice_table, sprite:newSlice())
end


--- Stackindex is not serialized, so it is recommended that all layers of a sprite are serialized at once, and their stack index is stored by their position in a list.
---@class LayerSerializer
LayerSerializer = inherit(Serializer, { copy_fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous", "color", "data", "properties" } })
Serializer:register("Layer", LayerSerializer)

---@param layer any
---@return boolean
function LayerSerializer:canSerialize(layer)
    return type(layer) == "userdata" and layer.__name == "Layer" and not layer.isTilemap and not layer.isReference and not layer.isGroup
end

---@param layer Layer
---@return table
function LayerSerializer:serialize(layer, image_table)    
    local layer_table = Serializer.serialize(self, layer)
    layer_table.cels = { }
    
    for _, cel in ipairs(layer.cels) do
        table.insert(layer_table.cels, Serializer:genericSerialize(cel, { args = { image_table }}))
    end

    return layer_table
end

--- Creates a new layer at the top of the sprites layerstack, and deserializes the passed serialized layer into this new layer.
---@param serialized_layer table
---@param sprite Sprite
---@param image_table table table where serialized images will be inserted, with their id as their key.
---@return Layer
function LayerSerializer:deserialize(serialized_layer, sprite, image_table)
    local layer = Serializer.deserialize(self, serialized_layer, sprite:newLayer())

    for _, cel in ipairs(serialized_layer.cels) do
        Serializer:genericDeserialize(cel, { args = { layer, sprite, image_table} })
    end

    return layer
end

---@param obj table
---@param store_location string
---@return table
function LayerSerializer:beforeStore(obj, store_location)
    -- see LayerGroupSerializer.beforeStore for comments.
    for i, cel in ipairs(obj.cels) do
        obj.cels[i] = Serializer:makeStoreCompatible(cel, store_location)
    end

    return obj
end

---@param obj table
---@param store_location string
---@return table
function LayerSerializer:beforeLoad(obj, store_location)
    for i, cel in ipairs(obj.cels) do
        obj.cels[i] = Serializer:makeLoadCompatible(cel, store_location)
    end

    return obj
end


---@class LayerSerializer
---@see LayerSerializer
LayerGroupSerializer = inherit(Serializer, { copy_fields = { "name", "isEditable", "isVisible", "isCollapsed", "color", "data", "properties" } })
Serializer:register("LayerGroup", LayerGroupSerializer)

---@param layer_group any
---@return boolean
function LayerGroupSerializer:canSerialize(layer_group)
    return type(layer_group) == "userdata" and layer_group.__name == "Layer" and layer_group.isGroup
end

---@param layer_group Layer
---@param image_table table table needed to store serialized images of child layers.
---@return table
function LayerGroupSerializer:serialize(layer_group, image_table)
    local group_table = Serializer.serialize(self, layer_group)
    group_table.children = { }

    for _, child_layer in ipairs(layer_group.layers) do
        local serialized_layer = Serializer:genericSerialize(child_layer, { args = { image_table } })

        -- conditional is here for unsuported layer types (reference layer)

        if serialized_layer.data then
            table.insert(group_table.children, serialized_layer)
        end
    end

    return group_table
end

--- Creates a new group at the top of the sprites layerstack, and deserializes the passed serialized group into this new group,
--- including all of its serialized children layers.
---@param layer_group table
---@param sprite Sprite
---@param image_table table
---@return Layer
function LayerGroupSerializer:deserialize(layer_group, sprite, image_table)
    local group = Serializer.deserialize(self, layer_group, sprite:newGroup())

    -- deserialize children.

    for _, child in ipairs(layer_group.children) do
        local layer = Serializer:genericDeserialize(child, { args = { sprite, image_table } })
        layer.parent = group
    end

    return group
end

---@param obj table
---@param store_location string
---@return table
function LayerGroupSerializer:beforeStore(obj, store_location)
    -- beforeStore is only recursively called on serialized fields, and since a list of serialized value is not seen as a serialized field,
    -- we need to handler looping over the serialized child layers in the children field and make them store compatible, in the LayerGroupSerializer class itself. 
    for i, child_layer in ipairs(obj.children) do
        obj.children[i] = Serializer:makeStoreCompatible(child_layer, store_location)
    end
    
    return obj
end

---@param obj table
---@param store_location string
---@return table
function LayerGroupSerializer:beforeLoad(obj, store_location)
    for i, child_layer in ipairs(obj.children) do
        obj.children[i] = Serializer:makeLoadCompatible(child_layer, store_location)
    end

    return obj
end


---@class TileSerializer
TileSerializer = inherit(Serializer, { copy_fields = { "image", "color", "data", "properties" } })
Serializer:register("Tile", TileSerializer)

---@param tile any
---@return boolean
function TileSerializer:canSerialize(tile)
    return type(tile) == "userdata" and tile.__name == "Tile"
end

---@param tile_table table
---@param sprite Sprite
---@param tileset Tileset tileset to add new tile to.
---@return Tile
function TileSerializer:deserialize(tile_table, sprite, tileset)
    return Serializer.deserialize(self, tile_table, sprite:newTile(tileset))
end

---@class TilesetSerializer
TilesetSerializer = inherit(Serializer, { copy_fields = { "name", "baseIndex", "color", "data", "properties" } })
Serializer:register("Tileset", TilesetSerializer)

---@param tileset any
---@return boolean
function TilesetSerializer:canSerialize(tileset)
    return type(tileset) == "userdata" and tileset.__name == "Tileset"
end

---@param tileset Tileset
function TilesetSerializer:serialize(tileset)
    local tileset_table = Serializer.serialize(self, tileset)

    tileset_table.grid = Serializer:genericSerialize(Rectangle(tileset.grid.origin.x, tileset.grid.origin.y, tileset.grid.tileSize.w, tileset.grid.tileSize.h))

    tileset_table.tiles = { }

    -- you cannot currently get the number of tiles in a tileset,
    -- so instead we iterate over the tiles, until we hit a nil value for an index.

    local tile = tileset:tile(#tileset_table.tiles)

    while tile do
        table.insert(tileset_table.tiles, Serializer:genericSerialize(tile))

        tile = tileset:tile(#tileset_table.tiles)
    end

    return tileset_table
end

---@param tileset_table table
---@param sprite Sprite sprite to add tileset to
---@return Tileset
function TilesetSerializer:deserialize(tileset_table, sprite)
    local rect = Serializer:genericDeserialize(tileset_table.grid)
    local tileset = Serializer.deserialize(self, tileset_table, sprite:newTileset(Grid(Serializer:genericDeserialize(tileset_table.grid))))

    for _, tile in ipairs(tileset_table.tiles) do
        Serializer:genericDeserialize(tile, { args = { sprite, tileset } })
    end

    return tileset
end

---@param tileset_table table
---@param location string
---@return table
function TilesetSerializer:beforeStore(tileset_table, location)
    for i, tile in ipairs(tileset_table.tiles) do
        tileset_table.tiles[i] = Serializer:makeStoreCompatible(tile, location)
    end

    return tileset_table
end

---@param tileset_table table
---@param location string
---@return table
function TilesetSerializer:beforeLoad(tileset_table, location)
    for i, tile in ipairs(tileset_table.tiles) do
        tileset_table.tiles[i] = Serializer:makeLoadCompatible(tile, location)
    end

    return tileset_table
end


---@class TilemapSerializer
TilemapSerializer = inherit(Serializer, { copy_fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous", "color", "data", "properties" } })
Serializer:register("Tilemap", TilemapSerializer)

---@param tilemap Tilemap
---@return boolean
function TilemapSerializer:canSerialize(tilemap)
    return type(tilemap) == "userdata" and tilemap.__name == "Layer" and tilemap.isTilemap
end

---@param tilemap Tilemap
---@return table
function TilemapSerializer:serialize(tilemap, image_table)
    local tilemap_table = Serializer.serialize(self, tilemap)
    tilemap_table.tileset = Serializer:genericSerialize(tilemap.tileset)
    
    tilemap_table.cels = { }
    
    for _, cel in ipairs(tilemap.cels) do
        table.insert(tilemap_table.cels, Serializer:genericSerialize(cel, { args = { image_table }}))
    end

    return tilemap_table
end

---@param tilemap_table table
---@param sprite Sprite
---@return Tilemap
function TilemapSerializer:deserialize(tilemap_table, sprite, image_table)
    -- !!! TODO !!!: Aseprite does not support creating tilemaps through its sprite objects yet,
    -- so as a workaround we instead create one through the app.commands interface.
    -- [This assumes that the passed sprite is equal to app.sprite], which is probably true anyway,
    -- but it does lead to a discrepancy between how the sprite is handled in all other serializers.
    --
    -- So fix this workaround when aseprite adds suppot for adding tilemaps through a sprite object.

    -- create layer
    app.command.NewLayer{ tilemap = true, ask = false }
    local tilemap = app.layer
    local tilemap = Serializer.deserialize(self, tilemap_table, tilemap)

    tilemap.tileset = Serializer:genericDeserialize(tilemap_table.tileset, { args = { sprite } })

    for _, cel in ipairs(tilemap_table.cels) do
        Serializer:genericDeserialize(cel, { args = { tilemap, sprite, image_table} })
    end

    return tilemap
end

---@param tilemap_table table
---@param store_location string
---@return table
function TilemapSerializer:beforeStore(tilemap_table, store_location)
    -- beforeStore is only recursively called on serialized fields, and since a list of serialized value is not seen as a serialized field,
    -- we need to handler looping over the serialized child layers in the children field and make them store compatible, in the LayerGroupSerializer class itself. 
    for i, child_layer in ipairs(tilemap_table.cels) do
        tilemap_table.cels[i] = Serializer:makeStoreCompatible(child_layer, store_location)
    end
    
    return tilemap_table
end

---@param tilemap_table table
---@param store_location string
---@return table
function TilemapSerializer:beforeLoad(tilemap_table, store_location)
    for i, child_layer in ipairs(tilemap_table.cels) do
        tilemap_table.cels[i] = Serializer:makeLoadCompatible(child_layer, store_location)
    end

    return tilemap_table
end


--- Aseprite currently segfaults if an image in a tilemap is saved, (see: https://github.com/aseprite/aseprite/issues/4069).
--- Aditionally, the expected behaviour will be to save an image of the tilemap and not the index references, which is not what we want to store here,
--- so this will probably be the required solution, even if this issue is fixed.
---@class TilemapImageSerializer
TilemapImageSerializer = inherit(Serializer, { copy_fields = { "width", "height", "colorMode", "bytes" }})
Serializer:register("TilemapImage", TilemapImageSerializer)

---@param image any
---@return boolean
function TilemapImageSerializer:canSerialize(image)
    if type(image) ~= "userdata" or image.__name ~= "ImageObj" then
        return false
    end

    local layer = nil

    if image.cel then
        pcall(function()
            layer = image.cel.layer
        end)
    end

    return (layer and layer.isTilemap) == true -- convert to boolean
end

---@param image_table any
---@return unknown
function TilemapImageSerializer:deserialize(image_table)
    local image = Image(image_table.width, image_table.height, image_table.colorMode)
    image.bytes = image_table.bytes
    return image
end


--- Serializer (not really) for Aseprite reference layers.
--- 
--- Since there does not seem to exist a way to manipulate reference layers through code,
--- they are deemed as unserializable, and are simply ignored by this serializer.
---
--- TODO: maybe commands can be used as a work around.
--- (NewLayer with reference = true, not sure how to pass file, as the user will be prompted to do so, but it should be determined through code)
---@class LayerReferenceSerializer
LayerReferenceSerializer = inherit(Serializer, { })
Serializer:register("LayerReference", LayerReferenceSerializer)

---@param layer_ref any
---@return false
function LayerReferenceSerializer:canSerialize(layer_ref)
    return type(layer_ref) == "userdata" and layer_ref.__name == "Layer" and layer_ref.isReference
end

---@param _ Layer
---@return nil
function LayerReferenceSerializer:serialize(_)
    return nil
end

---@param _ nil
---@return nil
function LayerReferenceSerializer:deserialize(_)
    return nil
end


--- Serializer for Aseprite properties object.
--- Elements in the keys list, specify which properties will be transfered,
--- allowing one to pick and choose which extension properties should be kept track off.
---
--- @class PropertiesSerializer
PropertiesSerializer = inherit(Serializer, { keys = { } })
Serializer:register("Properties", PropertiesSerializer)

---@param props any
---@return boolean
function PropertiesSerializer:canSerialize(props)
    -- Properties.__name returns nil for some reason, instead of "Properties" or something similar, so we use the tostring string instead.
    return type(props) == "userdata" and tostring(props):match("Properties: 0x%x+")
end

---@param properties Properties
---@return table
function PropertiesSerializer:serialize(properties)
    local properties_table = {  }

    -- we always serialize user proeprties, which is stored in the empty key.
    local property_keys = { "" }

    for key, _ in pairs(self.keys) do
        table.insert(property_keys, key)
    end

    for _, prop_key in ipairs(property_keys) do

        properties_table[prop_key] = { }

        for key, value in pairs(properties(prop_key)) do
            properties_table[prop_key][key] = Serializer:genericSerialize(value)
        end
    end

    return properties_table
end

---@param prop_table table
---@param properties Properties
---@return Properties
function PropertiesSerializer:deserialize(prop_table, properties)
    for prop_key, key_props in pairs(prop_table) do
        for key, value in pairs(key_props) do
            properties(prop_key)[key] = Serializer:genericDeserialize(value)
        end
    end

    return properties
end

---@param prop_table table
---@param location string
function PropertiesSerializer:beforeStore(prop_table, location)
    for prop_key, key_props in pairs(prop_table) do
        for key, value in pairs(key_props) do
            prop_table[prop_key][key] = Serializer:makeStoreCompatible(value, location)
        end
    end

    return prop_table
end

---@param prop_table table
---@param location string
---@return table
function PropertiesSerializer:beforeLoad(prop_table, location) 
    for prop_key, key_props in pairs(prop_table) do
        for key, value in pairs(key_props) do
            prop_table[prop_key][key] = Serializer:makeLoadCompatible(value, location)
        end
    end

    return prop_table
end


---@class SpriteSerializer
SpriteSerializer = inherit(Serializer, {
    copy_fields = { "gridBounds", "pixelRatio", "color", "data", "tileManagementPlugin", "properties" },
})
Serializer:register("Sprite", SpriteSerializer)

---@param sprite any
---@return boolean
function SpriteSerializer:canSerialize(sprite)
    return type(sprite) == "userdata" and sprite.__name == "doc::Sprite"
end

--- Serializes every part of the sprite EXCEPT for reference layers, as these are not supported.
---@param sprite Sprite
---@return table
function SpriteSerializer:serialize(sprite)
    local sprite_table = Serializer.serialize(self, sprite)

    sprite_table.width = sprite.width
    sprite_table.height = sprite.height
    sprite_table.color_mode = sprite.colorMode

    -- frames, tags and slices

    sprite_table.frames = { }
    sprite_table.tags = { }
    sprite_table.slices = { }

    for _, array in ipairs({ "frames", "tags", "slices" }) do
        for _, elem in ipairs(sprite[array]) do
            table.insert(sprite_table[array], Serializer:genericSerialize(elem))
        end
    end

    -- layers & cels + images

    sprite_table.images = { }
    sprite_table.layers = { }

    for _, layer in ipairs(sprite.layers) do
        table.insert(sprite_table.layers, Serializer:genericSerialize(layer, { args = { sprite_table.images} }))
    end

    -- palette

    -- TODO: should be a list of palettes, when aseprite adds support for multiple pallets.

    sprite_table.palette = Serializer:genericSerialize(sprite.palettes[1])

    return sprite_table
end

---@param sprite_table table
---@return Sprite
function SpriteSerializer:deserialize(sprite_table)
    local sprite = Serializer.deserialize(self, sprite_table, Sprite(sprite_table.width, sprite_table.height, sprite_table.colorMode))
    
    -- sprites are created with an initial layer, however we do not want it present,
    -- as they it mess up our deserialization of the serialized layers,
    -- so we remove them here.
    
    sprite:deleteLayer(sprite.layers[1])
    
    -- all proceeding deserializations require all of the frames of the sprite to be present, so we add them here whilst deserializing frames.

    for frame_num, _ in ipairs(sprite_table.frames) do
        if #sprite.frames < frame_num then
            sprite:newEmptyFrame()
        end

    end

    for _, array in ipairs({ sprite_table.frames, sprite_table.tags, sprite_table.slices}) do
        for _, elem in ipairs(array) do
            Serializer:genericDeserialize(elem, { args = { sprite }})
        end
    end
    
    for _, layer in ipairs(sprite_table.layers) do
        Serializer:genericDeserialize(layer, { args = { sprite, sprite_table.images } })
    end

    return sprite
end

---@param sprite_table table
---@param location string
---@return table
function SpriteSerializer:beforeStore(sprite_table, location)
    
    for _, list in ipairs({ sprite_table.frames, sprite_table.layers, sprite_table.tags }) do
        for i, element in ipairs(list) do
            list[i] = Serializer:makeStoreCompatible(element, location)            
        end
    end

    for id, image in pairs(sprite_table.images) do
        sprite_table.images[id] = Serializer:makeStoreCompatible(image, location)
    end

    return sprite_table
end

---@param sprite_table table
---@param location string
---@return table
function SpriteSerializer:beforeLoad(sprite_table, location)
    for _, list in ipairs({ sprite_table.frames, sprite_table.layers }) do
        for i, element in ipairs(list) do
            list[i] = Serializer:makeLoadCompatible(element, location)
        end
    end

    for id, image in pairs(sprite_table.images) do
        sprite_table.images[id] = Serializer:makeLoadCompatible(image, location)
    end

    return sprite_table
end
