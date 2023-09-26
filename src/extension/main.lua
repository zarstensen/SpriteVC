--- 
--- Aseprite extension for automatic version control of sprites.
--- 

require 'Serializer'


function init(plugin)
    plugin:newCommand{
        id="store_command",
        title="Store Sprite",
        group="sprite_crop",
        onclick = function()
            local s_sprite = Serializer:genericSerialize(app.sprite)
            print(s_sprite)
            Serializer:store(s_sprite, "Sprite")
        end
    }

    plugin:newCommand{
        id="load_command",
        title="Load Sprite",
        group="sprite_crop",
        onclick = function()
            local s_sprite = Serializer:load("Sprite")
            local sprite = Serializer:genericDeserialize(s_sprite)
            print(sprite)
        end
    }
end

function exit(plugin)
end
