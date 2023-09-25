require 'Test'
require 'Serializer'

---@class TestSpriteSerialize
TestSerializer = inherit(Test, {})

function TestSerializer:_new()
    Test._new(self, "Serialize Sprite")
end

-- TODO: Tilemap test
-- TODO: sprite test

function TestSerializer:ColorSerialize()
    local color = Color{r = 255, g = 125, b = 0}

    local serialized = self._serialize(color, "Color")

    Test.assert(0, serialized.data == color.rgbaPixel, "Color was not serialized to its pixelcolor.")

    local deserialized = Serializer:genericDeserialize(serialized)

    Test.assert(0, deserialized ~= serialized, "Serialized color was not deserialized")
    Test.assertEq(0, deserialized.rgbaPixel, color.rgbaPixel, "Original and deserialized colors did not match.")
end

function TestSerializer:PointSerialize()
    local point = Point(10, 20)

    local s_point = self._serialize(point, "Point")

    local fields = { "x", "y" }

    Test.assertEqFields(0, fields, s_point.data, point)

    local new_point = Serializer:genericDeserialize(s_point)

    Test.assertEqFields(0, fields, new_point, point)
end

function TestSerializer:RectangleSerialize()
    local rect = Rectangle(10, 20, 30, 40)

    local s_rect = self._serialize(rect, "Rectangle")

    local fields = { "x", "y", "w", "h" }

    Test.assertEqFields(0, fields, s_rect.data, rect)

    local new_rect = Serializer:genericDeserialize(s_rect)

    Test.assertEqFields(0, fields, new_rect, rect)
end

function TestSerializer:FramesSerialize()
    local sprite = self._testSprite()

    local frame_1 = sprite.frames[1]
    local frame_2 = sprite:newEmptyFrame()

    local f1_duration = 500
    local f2_duration = 1000

    frame_1.duration = f1_duration
    frame_2.duration = f2_duration

    local s_frame_1 = self._serialize(frame_1, "Frame")
    local s_frame_2 = self._serialize(frame_2, "Frame")

    local fields = { "duration", "frameNumber" }

    Test.assertEqFields(0, fields, s_frame_1.data, frame_1)
    Test.assertEqFields(0, fields, s_frame_2.data, frame_2)

    -- deserialize into new sprite, and check if new sprite and original sprite match field values that were serialized.

    local new_sprite = self._testSprite()
    new_sprite:newEmptyFrame()

    Serializer:genericDeserialize(s_frame_1, { args = { new_sprite } })
    Serializer:genericDeserialize(s_frame_2, { args = { new_sprite } })

    Test.assertEq(0, #new_sprite.frames, 2, "Incorrect frame count.")

    for i, frame in ipairs(new_sprite.frames) do
        Test.assertEqFields(0, fields, frame, sprite.frames[i])
    end
end

function TestSerializer:ImageSerialize()

    local ext_dir = app.fs.joinPath(app.fs.userConfigPath, "extensions/spritevc")

    local image = Image{ fromFile = app.fs.joinPath(ext_dir, "assets/3-color-image.png") }

    Test.assert(0, image ~= nil, "Failed to load test image.")

    local s_image = self._serialize(image, "Image")
    
    Test.assert(0, s_image.data ~= image, "Serialzied data was equal to original image.")
    
    local new_image = Serializer:genericDeserialize(s_image)
    
    Test.assert(0, new_image ~= image, "Deserialized image and original image were equal.")
    
    local loaded_image = self._storeToDisk({}, {}, s_image, image, "Image")

    for x=0, 2 do
        Test.assertEq(0, loaded_image:getPixel(x, 0), image:getPixel(x, 0), "Pixels did not match at (%s, 0)", x)
    end
end

function TestSerializer:PaletteSerialize()

    local ext_dir = app.fs.joinPath(app.fs.userConfigPath, "extensions/spritevc")

    local palette = Palette{ fromFile = app.fs.joinPath(ext_dir, "/assets/3-color-palette.gpl") }

    local s_palette = self._serialize(palette, "Palette")

    Test.assertEq(0, s_palette.data, palette, "Serialized palette was not the same object as the original palette.")

    local new_palette = self._storeToDisk({}, {}, s_palette, palette, "Palette")

    Test.assertEq(0, #new_palette, #palette, "palette color count did not match")

    for i=0, #new_palette - 1 do
        Test.assertEq(0, new_palette:getColor(i), palette:getColor(i), "Palette colors did not match at index %s", i)
    end
end

function TestSerializer:PropertiesSerialize()
    local sprite = self._testSprite()

    local store_key = "auth/ext_store"
    local ignore_key = "auth/ext_ignore"

    -- value requiring no serialization
    local no_ser_val = 99
    -- value requiring serialization
    local ser_val = Point(10, 20)

    sprite.properties.foo = no_ser_val
    sprite.properties.bar = ser_val

    sprite.properties(store_key).foo = no_ser_val
    sprite.properties(store_key).bar = ser_val
    
    sprite.properties(ignore_key).foo = no_ser_val
    sprite.properties(ignore_key).bar = ser_val

    PropertiesSerializer.keys[store_key] = true

    local s_properties = self._serialize(sprite.properties, "Properties")

    Test.assert(0, s_properties.data[""] ~= nil, "User properties was not serialized")
    Test.assert(0, s_properties.data[store_key] ~= nil, "Store key properties was not serialized")
    Test.assert(0, s_properties.data[ignore_key] == nil, "Ignore key properties was serialized")
 
    Test.assertEq(0, s_properties.data[""].foo, no_ser_val, "Value requiring no serialization did not match in user properties")
    Test.assertEq(0, s_properties.data[""].bar.data.x, ser_val.x, "X component requiring serialization did not match in user properties")
    Test.assertEq(0, s_properties.data[""].bar.data.y, ser_val.y, "Y component requiring serialization did not match in user properties")
    
    Test.assertEq(0, s_properties.data[store_key].foo, no_ser_val, "Value requiring no serialization did not match in extension properties")
    Test.assertEq(0, s_properties.data[store_key].bar.data.x, ser_val.x, "X component requiring serialization did not match in extension properties")
    Test.assertEq(0, s_properties.data[store_key].bar.data.y, ser_val.y, "Y component requiring serialization did not match in extension properties")

    local new_sprite = self._testSprite()

    local new_props = Serializer:genericDeserialize(s_properties, { args = { new_sprite.properties } })

    Test.assert(0, new_props("ignore_key").foo == nil, "Ignore key no serialization field was deserialized.")
    Test.assert(0, new_props("ignore_key").bar == nil, "Ignore key serialization field was deserialized.")

    Test.assertEq(0, new_props("").foo, no_ser_val, "Value requiring no serialization did not match in deserialized user properties")
    Test.assertEq(0, new_props("").bar.x, ser_val.x, "X component requiring serialization did not match in deserialized user properties")
    Test.assertEq(0, new_props("").bar.y, ser_val.y, "Y component requiring serialization did not match in deserialized user properties")

    Test.assertEq(0, new_props(store_key).foo, no_ser_val, "Value requiring no serialization did not match in deserialized extension properties")
    Test.assertEq(0, new_props(store_key).bar.x, ser_val.x, "X component requiring serialization did not match in deserialized extension properties")
    Test.assertEq(0, new_props(store_key).bar.y, ser_val.y, "Y component requiring serialization did not match in deserialized extension properties")

    local new_disk_sprite = self._testSprite()

    local disk_props = self._storeToDisk({}, {}, s_properties, nil, "Properties", { new_disk_sprite.properties })

    Test.assert(0, disk_props("ignore_key").foo == nil, "Ignore key no serialization field was deserialized.")
    Test.assert(0, disk_props("ignore_key").bar == nil, "Ignore key serialization field was deserialized.")

    Test.assertEq(0, disk_props("").foo, no_ser_val, "Value requiring no serialization did not match in deserialized user properties")
    Test.assertEq(0, disk_props("").bar.x, ser_val.x, "X component requiring serialization did not match in deserialized user properties")
    Test.assertEq(0, disk_props("").bar.y, ser_val.y, "Y component requiring serialization did not match in deserialized user properties")

    Test.assertEq(0, disk_props(store_key).foo, no_ser_val, "Value requiring no serialization did not match in deserialized extension properties")
    Test.assertEq(0, disk_props(store_key).bar.x, ser_val.x, "X component requiring serialization did not match in deserialized extension properties")
    Test.assertEq(0, disk_props(store_key).bar.y, ser_val.y, "Y component requiring serialization did not match in deserialized extension properties")
end

function TestSerializer:LayerSerialize()

    local image_table = { }

    local sprite = self._testSprite()
    
    local layer = sprite.layers[1]
    
    local serialized_layer = self._serialize(layer, "Layer", image_table)
    
    local fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous" }
    
    Test.assertEqFields(0, fields, serialized_layer.data, layer, "Is serialized")
    
    local new_sprite = Sprite{ ui = false, width = 1, height = 1 }
    
    Serializer:genericDeserialize(serialized_layer, { args = { new_sprite, image_table } })

    local new_layer = new_sprite.layers[1]

    Test.assertEqFields(0, fields, new_layer, layer, "Is deserialized")

    local sprite_2 = self._testSprite()
    sprite_2:deleteLayer(sprite_2.layers[1])

    self._storeToDisk(fields, fields, serialized_layer, layer, "Layer", { sprite_2, image_table })
end

function TestSerializer:LayerGroupSerialize()

    local image_table = { }

    local sprite = self._testSprite()
    sprite:deleteLayer(sprite.layers[1])

    local group = sprite:newGroup()
    local layer_1 = sprite:newLayer()
    local layer_2 = sprite:newLayer()

    layer_1.opacity = 0
    layer_1.isVisible = false
    layer_1.isContinuous = true

    layer_1.parent = group
    layer_2.parent = group

    local serialized_group = self._serialize(group, "LayerGroup", image_table)

    Test.assertEqFields(0, { "name", "isEditable", "isVisible" }, serialized_group.data, group, "Is serialized")

    Test.assertEq(0, #serialized_group.data.children, 2, "Serialized group contains incorrect number of children.")

    local serialized_layers = { Serializer:genericSerialize(layer_1), Serializer:genericSerialize(layer_2) }

    -- check child layers were serialized correctly

    local fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous", "color" }
    local serialized_fields = { "name", "opacity", "blendMode", "isEditable", "isVisible", "isContinuous" }

    for _, serialized_layer in ipairs(serialized_layers) do
        Test.assertEqFields(0, fields, serialized_group.data.children, serialized_layer, "Is deserialized")
    end

    local new_sprite = self._testSprite()
    local top_level = new_sprite.layers[1]
    new_sprite:deleteLayer(top_level)

    local new_group = Serializer:genericDeserialize(serialized_group, { args = { new_sprite, image_table } })


    Test.assertEq(0, #new_sprite.layers, 1, "Incorrect sprite layer count.")
    Test.assertEq(0, #new_sprite.layers[1].layers, 2, "Incorrect group layer count.")

    Test.assertEqFields(0, fields, new_group, group)

    -- check child layers were deserialized correctly
    Test.assertEqFields(0, fields, group.layers[1], new_group.layers[1], "Layer 1 did not match.")
    Test.assertEqFields(0, fields, group.layers[2], new_group.layers[2], "Layer 2 did not match.")

    local sprite_2 = self._testSprite()
    sprite_2:deleteLayer(sprite_2.layers[1])

    local loaded_group = self._storeToDisk(fields, serialized_fields, serialized_group, group, "Group", { sprite_2 })

    Test.assertEq(0, #sprite_2.layers, 1, "Incorrect loaded sprite layer count.")
    Test.assertEq(0, #loaded_group.layers, 2, "Incorrect oaded sprite group layer count.")

    Test.assertEqFields(0, fields, loaded_group.layers[1], group.layers[1], "Loaded layer 1 did not match.")
    Test.assertEqFields(0, fields, loaded_group.layers[2], group.layers[2], "Loaded layer 2 did not match.")

end


function TestSerializer:CelAndLayerSerialize()

    local ext_dir = app.fs.joinPath(app.fs.userConfigPath, "extensions/spritevc")

    local sprite = Sprite{ fromFile = app.fs.joinPath(ext_dir, "assets/cels-and-layers.ase") }

    local image_table = { }

    -- test first layer in no group

    local top_layer = sprite.layers[2]

    Test.assertEq(0, top_layer.name, "Top", "Incorrect layer")

    local s_top_layer = Serializer:genericSerialize(top_layer, { args = { image_table } })
    local image_count = 0

    for _, _ in pairs(image_table) do
        image_count = image_count + 1
    end

    Test.assertEq(0, image_count, 2, "Incorrect number of images were serialized.")
    Test.assertEq(0, #s_top_layer.data.cels, 3, "Incorrect number of cels were serialized.")

    -- test second layer (a group)

    local bottom_group = sprite.layers[1]

    Test.assertEq(0, bottom_group.name, "Bottom", "Incorrect layer")

    local s_group = Serializer:genericSerialize(bottom_group, { args = { image_table } })

    image_count = 0
    
    for _, _ in pairs(image_table) do
        image_count = image_count + 1
    end

    Test.assertEq(0, image_count, 7, "Incorrect number of images were serialized with group")
    Test.assertEq(0, #s_group.data.children[1].data.cels, 4, "Incorrect number of cels were serialized in the bottom group layer")
    Test.assertEq(0, #s_group.data.children[2].data.cels, 2, "Incorrect number of cels were serialized in the top group layer")

    -- TODO: add deserialize test
end

function TestSerializer:SpriteSerialize()

    local ext_dir = app.fs.joinPath(app.fs.userConfigPath, "extensions/spritevc")

    local sprite = Sprite{ fromFile = app.fs.joinPath(ext_dir, "assets/sprite-test.ase") }

    local s_sprite = self._serialize(sprite, "Sprite")

    Test.assertEq(0, #s_sprite.data.frames, 3, "Incorrect frame count in serialized sprite.")
    Test.assertEq(0, #s_sprite.data.layers, 3, "Incorrect layer count in serialized sprite.")
    Test.assertEq(0, self._keyCount(s_sprite.data.images), 4, "Incorrect image count in serialized sprite.")
    Test.assertEq(0, #s_sprite.data.slices, 1, "Incorrect slice count in serialized sprite")
    Test.assertEq(0, #s_sprite.data.tags, 1, "Incorrect tag count in serialized sprite")
    
    Test.assertEq(0, s_sprite.data.layers[3].uid, "Layer")
    Test.assertEq(0, s_sprite.data.layers[2].uid, "LayerGroup")
    Test.assertEq(0, s_sprite.data.layers[1].uid, "Tilemap")
    
    Test.assertEq(0, #s_sprite.data.layers[2].data.children, 1, "Incorrect group layer count")
    Test.assertEq(0, s_sprite.data.layers[2].data.children[1].uid, "Layer")
    
    local fields = { "gridBounds", "pixelRatio", "color", "data", "tileManagementPlugin" }
    local serialize_fields = { "data", "tileManagementPlugin" }
    

    local new_sprite = self._storeToDisk(fields, serialize_fields, s_sprite, sprite, "Sprite")

    Test.assertEq(0, #new_sprite.frames, 3, "Incorrect frame count in deserialized sprite.")
    Test.assertEq(0, #new_sprite.layers, 3, "Incorrect layer count in deserialized sprite.")
    Test.assertEq(0, #new_sprite.cels, 6, "Incorrect cel count in deserialized sprite.")
    Test.assertEq(0, #new_sprite.slices, 1, "Incorrect slice count in deserialized sprite")
    Test.assertEq(0, #new_sprite.tags, 1, "Incorrect tag count in deserialized sprite")

    Test.assert(0, new_sprite.layers[3].isImage, "Top layer was not an image layer.")
    Test.assert(0, new_sprite.layers[2].isGroup, "Middle layer was not an group")
    Test.assert(0, new_sprite.layers[1].isTilemap, "Bottom layer was not a tilemap.")

    Test.assertEq(0, #new_sprite.layers[2].layers, 1, "Incorrect group layer count")
    Test.assert(0, new_sprite.layers[2].layers[1].isImage, "Layer in group was not an image layer.")
    
    for i, _ in ipairs(new_sprite.cels) do
        self._compareImages(new_sprite.cels[i].image, sprite.cels[i].image, "Cel %s has incorrect image data.", i)
    end
end

--- construct a simple sprite of width and height 1.
---@return Sprite
function TestSerializer._testSprite()
    return Sprite{ ui = false, width = 1, height = 1 }
end

function TestSerializer._keyCount(table)
    local count = 0
    
    for _, _ in pairs(table) do
        count = count + 1
    end

    return count
end

--- Attempt to serialize passed object, asserts with error message if serialization fails.
---
---@param obj any
---@param expected_uid string uid of serializer, that should serialize obj.
---@param ... any additional arguments to pass to genericSerialize.
---@return table
function TestSerializer._serialize(obj, expected_uid, ...)
    local serialized = Serializer:genericSerialize(obj, { args = {...}})
 
    Test.assert(1, obj ~= serialized, string.format("%s was not serialized", expected_uid))
    Test.assert(1, serialized.uid == expected_uid, string.format("Incorrect serialized id.\nExpected: %s\nGot: %s", serialized.uid, expected_uid))

    for field, _ in pairs(serialized) do
        Test.assert(0, field == "uid" or field == "data", "Redundant field in serialized result %s", field)
    end

    return serialized
end

--- Store the passed serialized object to disk, load it again and deserialize it and compare the passsed fields with the passed original object
---
---@param fields string[] fields to compare between original_obj and loaded + deserialized object from disk.
---@param serialized_fields string[] fields to compare between serialized_obj and serialized object loaded from disk.
---@param serialized_obj table
---@param original_obj any
---@param location string
---@param deserialize_args any[] | nil arguments to pass to genericDeserialize.
---@return any
function TestSerializer._storeToDisk(fields, serialized_fields, serialized_obj, original_obj, location, deserialize_args)
    deserialize_args = deserialize_args or { }
    
    local full_location = app.fs.joinPath(app.fs.joinPath(app.fs.tempPath, "spritevc-test"), location)
    
    Serializer:store(serialized_obj, full_location)

    Test.assert(1, app.fs.isDirectory(full_location), "Did not create directory at location \"%s\"", full_location)
    Test.assert(1, app.fs.isFile(app.fs.joinPath(full_location, Serializer.json_file_name)), "Did not create json file at \"%s\"", app.fs.joinPath(full_location, Serializer.json_file_name))

    local new_serialized_obj = Serializer:load(full_location)

    
    Test.assert(1, new_serialized_obj ~= nil, "Failed loading object.")
    Test.assert(1, new_serialized_obj.data ~= nil, "Object data field was not loaded.")
    
    Test.assertEqFields(1, serialized_fields, new_serialized_obj.data, serialized_obj.data, "Loaded serialized object, did not match original serialized object.")

    local new_obj = Serializer:genericDeserialize(new_serialized_obj, { args = deserialize_args })

    Test.assertEqFields(1, fields, new_obj, original_obj, "Loaded deserialized object, did not match original object.")

    return new_obj
end

function TestSerializer._compareImages(image, image_target, msg, ...)
    Test.assertEq(1, image.width, image_target.width, "Image width did not match.")
    Test.assertEq(1, image.height, image_target.height, "Image height did not match.")

    for y = 0, image.height - 1 do
        for x = 0, image.width - 1 do
            Test.assertEq(1, image:getPixel(x, y), image_target:getPixel(x, y), "%s\nPixel did not match at (%s, %s)", msg, ..., x, y)
        end
    end
end

