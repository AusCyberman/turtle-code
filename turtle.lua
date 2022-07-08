local SLOTS_COUNT = 16

local ERRORS = {
    OUT_OF_FUEL = 69,
    INVENTORY_FULL = 71,
    COULD_NOT_BREAK_BLOCK = 72
}


function math.sign(n)
    return (n > 0 and 1) or (n == 0 and 0) or -1
end

local start_loc = vector.new(0, 0, 0)

local current_loc = start_loc

local directionVector = vector.new(1, 0, 0)

local LR = { LEFT = "Left", RIGHT = "Right" }

local DIR = { FORWARD = "", UP = "Up", DOWN = "Down" }


local function rot_vec(vec, lr)
    if lr == LR.LEFT then
        return vector.new(vec.z, vec.y, vec.x)
    elseif lr == LR.RIGHT then
        return vector.new(vec.z, vec.y, -1 * vec.x)
    end
end

local function rotate(lr)
    directionVector = rot_vec(directionVector:normalize(), lr)
    turtle["turn" .. lr]()
    print("turning " .. lr)
end

local function getTurnsToVec(avec, bvec)
    local dot = avec:dot(bvec)
    if dot == 1 then
        return {}
    elseif dot == -1 then
        return { LR.LEFT, LR.LEFT }
    else
        local cross = avec:cross(bvec)
        if cross.y < 0 then
            return { LR.RIGHT }
        else
            return { LR.LEFT }
        end
    end

end

local function set_direction(vec)
    for _, dir in ipairs(getTurnsToVec(directionVector, vec)) do
        turtle["turn" .. dir]()
    end
    directionVector = vec
end

local bypassFuelCheck = false

Turtle = {}

function Turtle.mt.__index(key) 
    local b,start = key:find("dig",1)
    if b ~= nil then
        Turtle.dig(key:sub(start)) 
    else 
        return Turtle[key]
    end
end

function Turtle.dig(dir)
   if turtle["detect"..dir] then
        Turtle.checkInventory()
        if not turtle["dig"..dir]()  then
           error({code = ERRORS.COULD_NOT_BREAK_BLOCK}) 
        end
   end
end

function Turtle.refuel()
    if bypassFuelCheck then return end
    local distance = start_loc:sub(directionVector)
    if turtle.getFuelLevel() > (distance.x + distance.y + distance.z) then
        return
    end
    for i = 1, SLOTS_COUNT do
        turtle.select(i)
        turtle.refuel()
    end
    if turtle.getFuelLevel() > start_loc:sub(directionVector) then
        error({ code = ERRORS.COULD_NOT_BREAK_BLOCK })
    end

end

function Turtle.moveForward(n, mut)
    for i = 1, math.abs(n) do
        Turtle.dig()
        turtle.forward()
        Turtle.refuel()
        print("at iteration:" .. i)
        current_loc = current_loc:add(mut)
    end
end

function Turtle.move(...)
    local args = { ... }
    local x, y, z
    if #args == 3 then
        x, y, z = table.unpack(args)
        current_loc = current_loc:add(vector.new(x, y, z))
    else
        x, y, z = args[1].x, args[1].y, args[1].z
        current_loc = current_loc:add(args[1])
    end
    if x ~= 0 then
        print("moving on x")
        local angleVec = vector.new(x / math.abs(x), 0, 0)
        set_direction(angleVec)
        Turtle.moveForward(x, angleVec)
    end
    if z ~= 0 then
        print("moving on z")
        local angleVec = vector.new(0, 0, z / math.abs(z))
        set_direction(angleVec)
        Turtle.moveForward(z, angleVec)
    end
    if y ~= 0 then
        local dir = (y > 0 and DIR.UP) or DIR.DOWN
        for i = 1, math.abs(y) do
            Turtle.refuel()
            Turtle.dig(dir)
            turtle[string.lower(dir)]()
            current_loc.y = current_loc.y + ((y > 0 and 1) or -1)
        end
    end
end

function Turtle.moveTo(vec3)
    local diffVec = vec3:sub(current_loc)
    Turtle.move(diffVec)
end




function Turtle.checkInventory()
    local full = true
    local i = 1
    while SLOTS_COUNT >= i and full do
        turtle.select(i)
        full = full and turtle.getItemSpace() == 0
        i = i + 1
    end
    if not full then return end
    local cleaned = false
    for i = 1, SLOTS_COUNT do
        turtle.select(i)
        local det = turtle.getItemDetail().name
        if det == "minecraft:stone" or det == "minecraft:dirt" then
            turtle.drop()
            cleaned = true
        end
    end
    if not cleaned then
        error { code = ERRORS.INVENTORY_FULL }
    end
end

local function moveClean(posvec)
    posvec = posvec or directionVector
    print("dirvec " .. posvec:tostring())
    print("moving to " .. current_loc:add(posvec):tostring())
    local _, err = pcall(Turtle.move, posvec)
    if err then
        if err.code == ERRORS.OUT_OF_FUEL then
            bypassFuelCheck = true
            Turtle.moveTo(start_loc)
            print(err)
            error("Returned home!")
        elseif err.code == ERRORS.INVENTORY_FULL then
            local oldPosVec = current_loc
            local oldDirVec = directionVector
            Turtle.moveTo(start_loc)
            for i =1, SLOTS_COUNT do
                turtle.select(i)
                turtle.dropDown()
            end
            Turtle.checkInventory()
            local distance = start_loc:sub(oldPosVec)
            if turtle.getFuelLevel() > distance.x + distance.y + distance.z then 
                error("Out Of Fuel!")
            end
            Turtle.moveTo(oldPosVec)
            Turtle.setDirection(oldDirVec)
        else
            error(err)
        end
    end

end

WIDTH = 10
LENGTH = 10
HEIGHT = 5


local function doStuff()
    for x = 2, LENGTH do
        moveClean()
        Turtle.digUp()
        Turtle.digDown()
    end
end

local a, b = LR.LEFT, LR.RIGHT
for i = 1, HEIGHT / 2 do
    for n = 1, WIDTH / 2 do
        doStuff()
        rotate(a)
        moveClean()
        rotate(a)
        doStuff()
        rotate(b)
        moveClean()
        rotate(b)
    end
    a, b = b, a
    moveClean(vector.new(0, 2, 0))
end
