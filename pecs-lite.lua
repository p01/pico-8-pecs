-- a pico-8 entity component system (ecs) library
-- license: mit copyright (c) 2021 jess telford
-- from: https://github.com/jesstelford/pico-8-pecs

-- this "lite" version contains no "system" portion, and reduces token use where
-- possible.
-- use this if you want to save tokens, or are not using the system or query
-- aspects of pecs
local createecsworld do
  local _highestid = 0

  function cuid()
    _highestid += 1
    return _highestid
  end

  function assign(...)
    local result, args = {}, { n = select("#", ...), ... }
    for i = 1, args.n do
      if (type(args[i]) == "table") then
        for key, value in pairs(args[i]) do result[key] = value end
      end
    end
    return result
  end

  createecsworld = function()
    local entities, onnextupdatestack = {}, {}

    function addcomponenttoentity(entity, component)
      -- only components created by createcomponent() can be added
      assert(component and component._componentfactory)
      -- and only once
      assert(not entity[component._componentfactory])

      -- store the component keyed by its factory
      entity[component._componentfactory] = component
    end

    function createentity(attributes, ...)
      local entity = assign({}, attributes or {})

      entity._id = cuid()

      setmetatable(entity,{
        __add=function(self, component)
          addcomponenttoentity(self, component)
          return self
        end,

        __sub=function(self, componentfactory)
          self[componentfactory] = nil
          return self
        end
      })

      for component in all(pack(...)) do
        addcomponenttoentity(entity, component)
      end

      entities[entity._id] = entity
      return entity
    end

    return {
      createentity=createentity,
      createcomponent=function(defaults)
        local function componentfactory(attributes)
          local component = assign({}, defaults, attributes)
          component._componentfactory = componentfactory
          component._id = cuid()
          return component
        end
        return componentfactory
      end,
      removeentity=function(entity)
        entities[entity._id] = nil
      end,
      -- useful for delaying actions until the next turn of the update loop.
      -- particularly when the action would modify a list that's currently being
      -- iterated on such as removing an item due to collision, or spawning new items.
      queue = function queue(callback)
        add(onnextupdatestack, callback)
      end,
      -- must be called at the start of each update() before anything else
      update=function()
        for callback in all(onnextupdatestack) do
          callback()
          del(onnextupdatestack, callback)
        end
      end
    }
  end
end
