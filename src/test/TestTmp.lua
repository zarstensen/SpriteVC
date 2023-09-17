require 'Test'

TestTmp = inherit(Test, 
{
    Global = "GLOBAL VALUE"
})

function TestTmp:_new()
    Test._new(self, "Unit Test")
end

function TestTmp:setup()
    self.environ_val = "ENVIRON VALUE"
end

function TestTmp:teardown()
    self.environ_val = nil
end

function TestTmp:getTests()
    return { self.goodTest, self.badTest, self.environTest, self.globalTest }
end

function TestTmp:goodTest()
    print("Performing test which does not fail")
end

function TestTmp:badTest()
    assert(false, "Performed test which failed, this should now show this error message.")
end

function TestTmp:environTest()
    print("Performing test which depends on environment setup")
    assert(self.environ_val == "ENVIRON VALUE", "Something went wrong with environment setup.")
end

function TestTmp:globalTest()
    print("Performing test which depends on global value")
    assert(self.Global == "GLOBAL VALUE", "Something went wrong with the self stuff.")
end