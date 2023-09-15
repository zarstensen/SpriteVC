require '..inherit'
require 'io'

---@class Test
Test = inherit(NewObj, {})

--- Create a test case named the passed string
---@param test_case string
---@return Test
function Test:new(test_case)
    return NewObj.new(self, test_case)
end

---@see Test.new
function Test:_new(test_case)
    self.test_case = test_case
    self.test_methods = self:getTests()
end

--- Return a list of methods which will be called when performTest is called.
--- A method / test fails if it at any points asserts.
---
--- This method should be overridden by an inheriting object.
---@return table<fun(self: Test)>
function Test:getTests()
    return {}
end

--- This method is called before all the test methods are called.
--- Use this to setup the testing environment.
function Test:setup()
end

--- This method is called after all the test methods have finished running.
--- Use this to tear down the testing environment.
function Test:teardown()
end

--- Runs all test methods and prints info about the test case to the console.
---@return boolean result whether all test ran without issue
function Test:performTest()

    local case_succeded = true

    print(string.format("======== CASE: [%s] ========", self.test_case))

    self:setup()

    for test_num, test in ipairs(self.test_methods) do

        -- test name is equal to the method name,
        -- so here we extract the method name directly form the source file,
        -- since getinfo does not provide a name for variables that references funcitons.
        local test_info = debug.getinfo(test, "S")

        local source_file = test_info.source:gsub("@", "")
        local test_line_num = test_info.linedefined
        local test_line = nil

        local current_line = 1

        for line in io.lines(source_file) do
            if current_line == test_line_num then
                test_line = line
                break
            end

            current_line = current_line + 1
        end 

        local test_name = test_line:match("function %g+:(%g+)%(%g*%)")


        print(string.format("running: [%s] (%s/%s)", test_name, test_num, #self.test_methods))
        local status, err_msg = pcall(test, self)

        if not status then
            print(err_msg)
            print("TEST FAILED!")
            
            case_succeded = false
        else
            print("OK!")
        end
        print()
    end

    local status_string = "SUCCESS"

    if not case_succeded then
        status_string = "FAILURE"
    end
    
    print(string.format("======== %s: [%s] ========", status_string, self.test_case))
    if not case_succeded then
        
    end

    self:teardown()

    return case_succeded
end
