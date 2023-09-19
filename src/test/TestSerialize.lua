require 'Test'
require 'Serializer'

---@class TestSpriteSerialize
TestSerializer = inherit(Test, {})

function TestSerializer:_new()
    Test._new(self, "Serializer")
end

function TestSerializer:ColorSerialize()
    local color = Color{r = 255, g = 125, b = 0}

    local serialized = self._serialize(color, "Color")

    Test.assert(0, serialized.data == color.rgbaPixel, "Color was not serialized to its pixelcolor.")

    local deserialized = Serializer:genericDeserialize(serialized)

    Test.assert(0, deserialized ~= serialized, "Serialized color was not deserialized")
    Test.assertEq(0, deserialized.rgbaPixel, color.rgbaPixel, "Original and deserialized colors did not match.")
end

function TestSerializer:FramesSerialize()
    local sprite = self._testSprite()

    local frame_1 = sprite.frames[1]
    local frame_2 = sprite:newFrame()

    local f1_duration = 500
    local f2_duration = 1000

    frame_1.duration = f1_duration
    frame_2.duration = f2_duration

    local s_frame_1 = self._serialize(frame_1, "Frame")
    local s_frame_2 = self._serialize(frame_2, "Frame")

    local fields = { "duration", "frameNumber" }

    self._compareFields(fields, s_frame_1.data, frame_1)
    self._compareFields(fields, s_frame_2.data, frame_2)

    -- deserialize into new sprite, and check if new sprite and original sprite match field values that were serialized.

    local new_sprite = self._testSprite()

    Serializer:genericDeserialize(s_frame_1, new_sprite)
    Serializer:genericDeserialize(s_frame_2, new_sprite)

    Test.assertEq(0, #new_sprite.frames, 2, "Incorrect frame count.")

    for i, frame in ipairs(new_sprite.frames) do
        self._compareFields(fields, frame, sprite.frames[i])
    end
end

function TestSerializer:LayerSerialize()
    local sprite = self._testSprite()
    sprite:newLayer()

    local layer = sprite.layers[1]

    local serialized_layer = self._serialize(layer, "Layer")
    
    local fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous" }

    self._compareFields(fields, serialized_layer.data, layer, "Is serialized")

    local new_sprite = Sprite{ ui = false, width = 1, height = 1 }

    Serializer:genericDeserialize(serialized_layer, new_sprite)

    local new_layer = new_sprite.layers[1]

    self._compareFields(fields, new_layer, layer, "Is deserialized")

end

function TestSerializer:LayerGroupSerialize()
    local sprite = self._testSprite()
    local group = sprite:newGroup()
    local layer_1 = sprite:newLayer()
    local layer_2 = sprite:newLayer()

    layer_1.opacity = 0
    layer_1.isVisible = false
    layer_1.isContinuous = true

    layer_1.parent = group
    layer_2.parent = group

    local serialized_group = self._serialize(group, "LayerGroup")

    self._compareFields({ "name", "isEditable", "isVisible" }, serialized_group.data, group, "Is serialized")

    Test.assertEq(0, #serialized_group.data.children, 2, "Serialized group contains incorrect number of children.")

    local serialized_layers = { Serializer:genericSerialize(layer_1), Serializer:genericSerialize(layer_2) }

    -- check child layers were serialized correctly

    local fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous", "color" }

    for _, serialized_layer in ipairs(serialized_layers) do
        self._compareFields(fields, serialized_group.data.children, serialized_layer, "Is deserialized")
    end

    local new_sprite = self._testSprite()
    local top_level = new_sprite.layers[1]
    new_sprite:deleteLayer(top_level)

    local new_group = Serializer:genericDeserialize(serialized_group, new_sprite)


    Test.assertEq(0, #new_sprite.layers, 1, "Incorrect sprite layer count.")
    Test.assertEq(0, #new_sprite.layers[1].layers, 2, "Incorrect group layer count.")

    self._compareFields(fields, new_group, group)

    -- check child layers were deserialized correctly
    self._compareFields(fields, group.layers[1], new_group.layers[1])
    self._compareFields(fields, group.layers[2], new_group.layers[2])

end

--- construct a simple sprite of width and height 1.
---@return Sprite
function TestSerializer._testSprite()
    return Sprite{ ui = false, width = 1, height = 1 }
end

--- Attempt to serialize passed object, asserts with error message if serialization fails.
---
---@param obj any
---@param expected_uid string uid of serializer, that should serialize obj.
---@return table
function TestSerializer._serialize(obj, expected_uid)
    local serialized = Serializer:genericSerialize(obj)

    Test.assert(1, obj ~= serialized, string.format("%s was not serialized", expected_uid))
    Test.assert(1, serialized.uid == expected_uid, string.format("Incorrect serialized id.\nExpected: %s\nGot: %s", serialized.uid, expected_uid))

    return serialized
end

--- Compare all the passed fields in the first and second object.
--- Asserts with failure message and field info if fields are not all equal.
---
---@param fields any
---@param first any
---@param second any
---@param failure_message any
function TestSerializer._compareFields(fields, first, second, failure_message)

    failure_message = failure_message or ""

    for _, field in ipairs(fields) do
        Test.assertEq(1, first[field], second[field], string.format("%s did not match.\n%s", field, failure_message))
    end
end
