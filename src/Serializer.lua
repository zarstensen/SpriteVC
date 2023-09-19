require 'inherit'

--- Base class for all serializers.
---
--- The main job of this and all of the derived classes is converting any userdata object into a table, that then can be stored on disk for later loading.
--- 
--- Derived serializers should use Serializer.register,
--- in order for them to be used when calling genericSerialize and genericDeserialize.
---
--- Derived classes should implement a serialize and deserialize function.
---
---@class Serializer
Serializer = inherit(NewObj, { serializers = {} })

--- Register a serializer and tie it to the passed uid.
---@param uid string
---@param serializer Serializer | any
function Serializer:register(uid, serializer)
    self.serializers[uid] = serializer
end

--- Serializes the passed object with a suitable serializer registered using Serialier.register.
--- If no suitable serializer if found, the object itself is returned.
---@param obj any
---@param ... unknown
---@return table
function Serializer:genericSerialize(obj, ...)
    for uid, s in pairs(self.serializers) do
        if s:canSerialize(obj) then
            local serialized = { uid = uid, data = s:serialize(obj, ...) }
            return serialized
        end
    end

    return obj
end

--- Deserializes a serialized object returned from genericSerialize, using the same serialier that serialized it.
--- If the serialized object did not use any serializers during genericSerialize, the serialized object is returned. 
---@param serialized table
---@param ... any
---@return any
function Serializer:genericDeserialize(serialized, ...)
    if type(serialized) ~= "table" or not serialized.uid or not self.serializers[serialized.uid] then
        return serialized
    end

    return self.serializers[serialized.uid]:deserialize(serialized.data, ...)
end

--- Converts the given object into a disk storable table
---@param obj any
---@param ... any
---@return table | nil serialized_obj nil on failure
function Serializer:serialize(obj, ...)
    self._notImplementedErr("serialize", obj)
end

--- Converts the given serialized object into a corresponding deserialized object
---@param obj table
---@param ... any
---@return any serialized_obj
--- may return nothing, if deserialized object cannot be directly created,
--- and the method depends on ... to contruct it.
function Serializer:deserialize(obj, ...)
    self._notImplementedErr("deserialize", obj)
end

--- Return whether the serializer instance is able to serialize the given object.
---@param obj any
---@return boolean | nil can_serialize nil on failure
function Serializer:canSerialize(obj)
    self._notImplementedErr("canSerialize", obj)
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

function Serializer._notImplementedErr(func_name, obj)
    local err_msg = "%s not implemented for [%s - %s]"

    if (type(obj) == "table" or type(obj) == "userdata") and obj.__name then
        err_msg = string.format(err_msg, func_name, type(obj), tostring(obj))
    else
        err_msg = string.format(err_msg, func_name, type(obj), obj)
    end

    assert(false, err_msg)
end

--- Color ========================================================

--- Serializer class for the Aseprite Color object.
---
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



--- Serializer class for serializing Aseprite Frame objects.
---@class FrameSerializer
FrameSerializer = inherit(Serializer, { })
Serializer:register("Frame", FrameSerializer)

---@param frame any
---@return boolean
function FrameSerializer:canSerialize(frame)
    return type(frame) == "userdata" and frame.__name == "FrameObj"
end

---@param frame FrameObj
---@return table
function FrameSerializer:serialize(frame)
    local frame_table = { }

    Serializer:copyFields({ "duration", "frameNumber" }, frame, frame_table, Serializer.genericSerialize)

    return frame_table
end

--- When deserializing, additional empty frames may be created inbetween the furthest current frame in sprite,
--- As frames can only differ by 1, relative to their neighbours.
---
---@param frame table
---@param sprite Sprite
---@return FrameObj
function FrameSerializer:deserialize(frame, sprite)
    
    -- as all frames between two frames need to exist, we here make sure we can access the frame.frameNumber frame in the sprite,
    -- by adding frames, until it exists in the frame list.

    while #sprite.frames < frame.frameNumber do
       sprite:newEmptyFrame()
    end

    sprite.frames[frame.frameNumber].duration = frame.duration

    return sprite.frames[frame.frameNumber]
end

--- Serializer for serializing aseprite layers.
--- Layer cannot be a group, tilemap or reference.
--- Stackindex is not serialized, so it is recommended that all layers of a sprite are serialized at once, and their stack index is stored by their position in a list.
--- cels are not serialized as these are also serialized as their own thing at a different part of the sprite (Sprite.cels).
--- 
---@class LayerSerializer
LayerSerializer = inherit(Serializer, { copy_fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous", "color", "data" } })
Serializer:register("Layer", LayerSerializer)

---@param layer any
---@return boolean
function LayerSerializer:canSerialize(layer)
    return type(layer) == "userdata" and layer.__name == "Layer" and not layer.isTilemap and not layer.isReference and not layer.isGroup
end

---@param layer Layer
---@return table
function LayerSerializer:serialize(layer)
    
    local layer_table = {}

    self:copyFields(self.copy_fields,
        layer,
        layer_table,
        Serializer.genericSerialize)

    return layer_table

end

--- Creates a new layer at the top of the sprites layerstack, and deserializes the passed serialized layer into this new layer.
--- 
---@param serialized_layer table
---@param sprite Sprite
---@return Layer
function LayerSerializer:deserialize(serialized_layer, sprite)
    local layer = sprite:newLayer()

    self:copyFields(self.copy_fields,
    serialized_layer,
    layer,
    Serializer.genericDeserialize)

    return layer
end

--- Serializer for serializing aseprite layer groups.
--- Group cannot be a layers, tilemap or reference.
--- Stackindex is handled the same as in LayerSerializer
---
---@class LayerSerializer
---@see LayerSerializer
LayerGroupSerializer = inherit(Serializer, { copy_fields = { "name", "isEditable", "isVisible", "isCollapsed", "color", "data" } })
Serializer:register("LayerGroup", LayerGroupSerializer)


---@param layer_group any
---@return false
function LayerGroupSerializer:canSerialize(layer_group)
    return type(layer_group) == "userdata" and layer_group.__name == "Layer" and layer_group.isGroup and not layer_group.isTilemap and not layer_group.isReference
end

---@param layer_group Layer
---@return table
function LayerGroupSerializer:serialize(layer_group)
    local group_table = { children = { } }

    self:copyFields(self.copy_fields,
        layer_group,
        group_table,
        Serializer.genericSerialize)

    for _, child_layer in ipairs(layer_group.layers) do
        table.insert(group_table.children, Serializer:genericSerialize(child_layer))
    end

    return group_table
end

--- Creates a new group at the top of the sprites layerstack, and deserializes the passed serialized group into this new group,
--- including all of its serialized children layers.
---
---@param layer_group table
---@param sprite Sprite
---@return Layer
function LayerGroupSerializer:deserialize(layer_group, sprite)
    local group = sprite:newGroup()

    self:copyFields(self.copy_fields,
        layer_group,
        group,
        Serializer.genericDeserialize)

    -- deserialize children.

    for _, child in ipairs(layer_group.children) do
        local child_layer = Serializer:genericDeserialize(child, sprite)
        child_layer.parent = group
    end

    return group
end

-- TODO: should be a serializer for the sprite object, not a whole separate class.
---@class SpriteConverter
SerializedSprite = {}

function SerializedSprite:_new(source_sprite)
    self.source_sprite = source_sprite

    self:serializeSpriteLayers()

end

function SerializedSprite:serializeSpriteLayers()
    self.layers = { }

    for i, layer in ipairs(self.source_sprite.layers) do
        self.layers[i] = self.layer_serialize:serialize(layer)
    end

end
