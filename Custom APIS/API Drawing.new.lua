local DrawingAPI = {
    Version = "3.0.0",
    Objects = {},
    Active = true,
    FPS = 60,
    Debug = false,
    ZIndexSystem = true
}

local DrawingObject = {}
DrawingObject.__index = DrawingObject

function DrawingObject:Remove()
    if self._Destroyed then return end
    self.Visible = false
    self._Destroyed = true
    if self.OnRemove then task.spawn(self.OnRemove, self) end
    table.remove(DrawingAPI.Objects, table.find(DrawingAPI.Objects, self))
    return self
end

function DrawingObject:Set(prop, value)
    if self[prop] == nil then 
        if DrawingAPI.Debug then warn("Invalid property "..prop.." for "..self.Type) end
        return self 
    end
    self[prop] = value
    if self.OnChange then task.spawn(self.OnChange, self, prop, value) end
    return self
end

function DrawingObject:Update(props)
    for prop, value in pairs(props) do self:Set(prop, value) end
    return self
end

local function NewDrawing(type, defaults)
    local obj = setmetatable({
        Visible = true,
        Color = Color3.new(1,1,1),
        Transparency = 0,
        ZIndex = 1,
        Type = type,
        _CreatedAt = os.clock()
    }, DrawingObject)

    for prop, value in pairs(defaults) do obj[prop] = value end
    
    table.insert(DrawingAPI.Objects, obj)
    if DrawingAPI.ZIndexSystem then table.sort(DrawingAPI.Objects, function(a,b) return a.ZIndex < b.ZIndex end) end
    return obj
end

function DrawingAPI.New(type)
    local templates = {
        Line = {From = Vector2.new(0,0), To = Vector2.new(0,0), Thickness = 1},
        Text = {Text = "", Font = 2, Size = 16, Center = false, Outline = false, OutlineColor = Color3.new(0,0,0), Position = Vector2.new(0,0)},
        Circle = {Position = Vector2.new(0,0), Radius = 10, Filled = false, Sides = 32},
        Square = {Position = Vector2.new(0,0), Size = Vector2.new(10,10), Filled = false},
        Rectangle = {Position = Vector2.new(0,0), Size = Vector2.new(10,10), Filled = false},
        Triangle = {PointA = Vector2.new(0,0), PointB = Vector2.new(0,0), PointC = Vector2.new(0,0), Filled = false},
        Quad = {PointA = Vector2.new(0,0), PointB = Vector2.new(0,0), PointC = Vector2.new(0,0), PointD = Vector2.new(0,0), Filled = false},
        Image = {Position = Vector2.new(0,0), Size = Vector2.new(10,10), Data = ""}
    }
    
    if templates[type] then return NewDrawing(type, templates[type]) end
    error("Invalid drawing type: "..tostring(type))
end

function DrawingAPI.GetAll()
    return DrawingAPI.Objects
end

function DrawingAPI.Clear()
    for i = #DrawingAPI.Objects, 1, -1 do DrawingAPI.Objects[i]:Remove() end
end

function DrawingAPI.Render()
    if not DrawingAPI.Active then return end
    
    for _, obj in ipairs(DrawingAPI.Objects) do
        if obj.Visible and not obj._Destroyed then
            if DrawingAPI.Debug then print("Rendering", obj.Type) end
        end
    end
end

task.spawn(function()
    while task.wait(1/DrawingAPI.FPS) do
        if DrawingAPI.Active then DrawingAPI.Render() end
    end
end)

for _, type in ipairs({"Line","Text","Circle","Square","Rectangle","Triangle","Quad","Image"}) do
    DrawingAPI[type] = function() return DrawingAPI.New(type) end
end

getgenv().Drawing = DrawingAPI
return DrawingAPI
