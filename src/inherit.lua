--- Makes the derived table inherit from the base table, as in if a field exists in the base table,
--- it will be returned for field lookups, unless the derived table overrides the field.
---@param base table
---@param derived table
---@return table
function inherit(base, derived)

    setmetatable(derived, base)
    base.__index = base

    return derived
end

--- Simple class providing a constructor function (new).
--- When an class inheriting from NewObj is constructed,
--- the @ref _new method will be called, with the newly created instance as the self argument.
---@see NewObj.new
---@see NewObj._new
---@class NewObj
NewObj = {}

--- Construct a new object and call its initialization function with the passed arguments.
---
--- To provide documentation, derived classes can override this method,
--- provided the following code snippet is the only content of the method, (... can be changed to named parameters):
--- 
--- function Derived:new(...):
---     return NewObj.new(self, ...)
--- end
--- 
--- where Derived is the class that requries documentation of its new function.
--- Any other required logic must be performed inside the _new method.
---@param self NewObj | any (where any inherits from NewObj)
---@param ... any
---@return NewObj | any (where any inherits from NewObj)
---@see NewObj._new
function NewObj.new(self, ...)
    local obj = {}

    self.__index = self
    setmetatable(obj, self)

    obj:_new(...)

    return obj
end

--- Initialization method for all objects inheriting from NewObj.
--- To chain _new calls to base classes, use the following expression,
--- 
--- base._new(self, ...)
---
--- where base is the name of the class the current instance is being based on at some point in its inheritance tree.
---@param ... unknown
function NewObj:_new(...)
end
