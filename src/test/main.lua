require 'TestTmp'

--- 
--- Entry point for test version of the SpriteVC extension.
--- 

function init(plugin)
    -- io.open needs all of the folders to exist before the file can be opened, so these are made here
    local result_path = app.fs.joinPath(app.fs.tempPath, "spritevc/test_result.txt")
    app.fs.makeAllDirectories(app.fs.filePath(result_path))
    
    local result_file = io.open(result_path, "w")

    if not result_file then
        print("COULD NOT OPEN RESULT FILE!")
    end

    local tests = { TestTmp:new(), TestTmp:new() }

    local all_passed = true
    
    for _, test in ipairs(tests) do
        print()
        
        local passed, new_msg = test:performTest()

        all_passed = all_passed and passed

        print()
        
        result_file:write(string.format("\n%s\n", new_msg))
    end

    result_file:write(string.format("ALL_PASSED:\n%s", all_passed))
    result_file:close()
end

function exit(plugin)
end