require 'tests.test'

UnitTest = inherit(Test, 
{
    Global = "GLOBAL VALUE"
})

function UnitTest:_new()
    Test._new(self, "Unit Test")
end

function UnitTest:setup()
    self.environ_val = "ENVIRON VALUE"
end

function UnitTest:teardown()
    self.environ_val = nil
    
    print(self.environ_val)
end

function UnitTest:getTests()
    return { self.goodTest, self.badTest, self.environTest, self.globalTest }
end

function UnitTest:goodTest()
    print("Performing test which does not fail")
end

function UnitTest:badTest()
    assert(true, "Performed test which failed, this should now show this error message.")
end

function UnitTest:environTest()
    print("Performing test which depends on environment setup")
    assert(self.environ_val == "ENVIRON VALUE", "Something went wrong with environment setup.")
end

function UnitTest:globalTest()
    print("Performing test which depends on global value")
    assert(self.Global == "GLOBAL VALUE", "Something went wrong with the self stuff.")
end