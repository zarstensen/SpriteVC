require 'Inherit'

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
end

--- Return a list of methods which will be called when performTest is called.
--- A method / test fails if it at any points asserts.
--- 
--- All methods of the current class are returned, except for methods with a '_' prefix.
--- Methods are sorted first by hirearchy, meaning current instance methods come first, and top base class methods come last, define line number second, and alphabetically last.
---@return table<fun(self: Test)>
function Test:_getTests(test_list)

    -- We store the methods temporarily in a separate list so we can sort them alphabetically and by line defined, without mixing them with the base methods.

    local method_list = {}

    for field, value in pairs(self) do
        if type(value) == "function" and field:sub(1, 1) ~= '_' and Test[field] == nil then
            table.insert(method_list, { line = debug.getinfo(value, "S").linedefined, name = field, method = value })
        end
    end

    table.sort(method_list,
        function(a, b)
            if a.line == b.line then
                return a.name < b.name
            else
                return a.line < b.line
            end
        end)

    for _, method_info in ipairs(method_list) do
        table.insert(test_list, method_info.method)
    end

    if self.__index and self.__index ~= self and self.__index._getTests then
        test_list = self.__index:_getTests(test_list)
    end

    return test_list
end

--- Asserts if the given value is false, with the passed message formatted with the passed variadic arguments.
--- 
---@param depth number function stack depth to go up when reporting line number. 0 == line where Test.assert is called.
---@param value boolean
---@param msg string
---@param ... any
function Test.assert(depth, value, msg, ...)
    assert(value, string.format("\nLine: %s\n%s", debug.getinfo(depth + 2, "l").currentline, string.format(msg, ...)))
end

--- Asserts if the two given values are not equal, and report the two different values in the assert message.
---
---@param depth number
---@param value any
---@param exptected_value any
---@param msg string | nil
---@param ... any
function Test.assertEq(depth, value, exptected_value, msg, ...)
    msg = msg or "Assertion failed."
    Test.assert(depth + 1, value == exptected_value, "%s\nExpected:\t%s\nCurrent:\t%s\n", string.format(msg, ...), exptected_value, value)
end

--- Compare all the passed fields in the first and second object.
--- Asserts with failure message and field info if fields are not all equal.
---
---@param depth number
---@param fields any
---@param first any
---@param second any
---@param failure_message any
function Test.assertEqFields(depth, fields, first, second, failure_message)

    failure_message = failure_message or ""

    for _, field in ipairs(fields) do
        Test.assertEq(depth + 1, first[field], second[field], string.format("%s did not match.\n%s", field, failure_message))
    end
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
---@return string msg the result string printed to console
function Test:performTest()

    local case_succeded = true

    local result_str = self._log(string.format("========= CASE: [%s] =========", self.test_case), "")


    self:setup()

    -- recursively go through self and find all methods not prefixed with '_' or defined in Test.
    local test_methods = self:_getTests({})

    for test_num, test in ipairs(test_methods) do
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

        result_str = self._log(string.format("running (%s/%s): [%s] ", test_num, #test_methods, test_name), result_str)
        local status, err_msg = xpcall(test, debug.traceback, self)

        if not status then
            self._log(err_msg, result_str)
            self._log("TEST FAILED!", result_str)

            case_succeded = false
        else
            result_str = self._log("PASSED!", result_str)
        end

        result_str = self._log("", result_str)
    end

    local status_string = "SUCCESS"

    if not case_succeded then
        status_string = "FAILURE"
    end
    
    self:teardown()

    result_str = self._log(string.format("======== %s: [%s] ========", status_string, self.test_case), result_str)

    return case_succeded, result_str
end


--- prints new line to console, and returns the msg string appended with new_line.
---@param new_line string
---@param msg string
---@return string
function Test._log(new_line, msg)
    msg = msg .. new_line .. '\n'
    print(new_line)

    return msg
end
