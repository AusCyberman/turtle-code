Turtle = {}
local SLOTS_COUNT = 16
local ERRORS = {
    OUT_OF_FUEL = 1,
    INVENTORY_FULL = 2,
    COULD_NOT_BREAK_BLOCK = 3,
    COULD_NOT_MOVE = 4
}

local ERRMSGS = {
    [ERRORS.OUT_OF_FUEL] = "Out of Fuel",
    [ERRORS.INVENTORY_FULL] = "Inventory Full",
    [ERRORS.COULD_NOT_BREAK_BLOCK] = "Could not break block",
    [ERRORS.COULD_NOT_MOVE] = "Could not move"
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

function Turtle.rotate(lr)
    directionVector = rot_vec(directionVector:normalize(), lr)
    turtle["turn" .. lr]()
    print("turning " .. lr)
end

local function moveRaw()
    local i = 0
    while not turtle.forward() and i < 20 do
        i = i + 1
        Turtle.dig()
    end
    if i > 20 then
        coroutine.yield { code = ERRORS.COULD_NOT_MOVE }
    end
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

Turtle.digUp = function() Turtle.dig(DIR.UP) end
Turtle.digDown = function() Turtle.dig(DIR.DOWN) end
function Turtle.dig(dir)
    dir = dir or ""
    if turtle["detect" .. dir]() then
        turtle.select(1)
        if not turtle["dig" .. dir]() then
            coroutine.yield { code = ERRORS.COULD_NOT_BREAK_BLOCK }
        end
    end
end

function Turtle.refuel()
    if bypassFuelCheck then return end
    local distanceV = start_loc:sub(current_loc)
    local distance = math.abs(distanceV.x) + math.abs(distanceV.y) + math.abs(distanceV.z)
    if turtle.getFuelLevel() > distance then
        return
    end
    print("NO FUEL!!!")
    for i = 1, SLOTS_COUNT do
        turtle.select(i)
        turtle.refuel()
    end
    if turtle.getFuelLevel() <= distance then
        coroutine.yield { code = ERRORS.OUT_OF_FUEL }
    end

end

function Turtle.moveForward(n)
    for i = 1, math.abs(n) do
        Turtle.refuel()
        moveRaw()
        print("at iteration:" .. i)
        current_loc = current_loc:add(directionVector)
    end
end

function Turtle.move(...)
    local args = { ... }
    return coroutine.create(function()
        local x, y, z
        if #args == 3 then
            x, y, z = table.unpack(args)
        else
            x, y, z = args[1].x, args[1].y, args[1].z
        end
        if x ~= 0 then
            print("moving on x")
            local angleVec = vector.new(x / math.abs(x), 0, 0)
            set_direction(angleVec)
            Turtle.moveForward(x)
        end
        if z ~= 0 then
            print("moving on z")
            local angleVec = vector.new(0, 0, z / math.abs(z))
            set_direction(angleVec)
            Turtle.moveForward(z)
        end
        if y ~= 0 then
            local dir = (y > 0 and DIR.UP) or DIR.DOWN
            for i = 1, math.abs(y) do
                Turtle.refuel()
                while not turtle[string.lower(dir)]() do
                    Turtle.dig(dir)
                end
                current_loc.y = current_loc.y + ((y > 0 and 1) or -1)
            end
        end
    end)
end

function Turtle.moveTo(vec3)
    local diffVec = vec3:sub(current_loc)
    return Turtle.move(diffVec)
end

function Turtle.checkInventory()
    local full = true
    for i = 1, SLOTS_COUNT do
        turtle.select(i)
        if turtle.getItemCount() > 0 then
            local det = turtle.getItemDetail().name
            if det == "minecraft:cobblestone" or det == "minecraft:dirt" or det == "minecraft.stone" then
                turtle.drop()
            end
        end
        full = full and (turtle.getItemCount() > 0)
    end
    if not full then return end
    if full then
        coroutine.yield { code = ERRORS.INVENTORY_FULL }
    end
    turtle.select(1)
end

local function moveClean(posvec)
    posvec = posvec or directionVector
    print("dirvec " .. posvec:tostring())
    print("moving to " .. current_loc:add(posvec):tostring())
    local co = Turtle.move(posvec)
    local function iterate(co)
        return function() local code, res = coroutine.resume(co)
            return res
        end
    end

    for res in iterate(co) do
        if res.code == ERRORS.OUT_OF_FUEL then
            print("OUT OF FUEL!!!")
            local co = Turtle.moveTo(start_loc)
            for res in iterate(co) do
                if res.code ~= ERRORS.OUT_OF_FUEL then
                    error("Could not return home" .. ERRMSGS[res.code])
                end
            end
            error("Returned home, out of fuel!!")
        elseif res.code == ERRORS.INVENTORY_FULL then
            print("inventory full")
            local oldPosVec = current_loc
            local oldDirVec = directionVector
            for b in iterate(Turtle.moveTo(start_loc)) do
                error("Could not return home: " .. ERRMSGS[b.code])
            end
            for i = 1, SLOTS_COUNT do
                turtle.select(i)
                turtle.dropDown()
            end
            Turtle.checkInventory()
            local distance = oldPosVec:sub(start_loc)
            if turtle.getFuelLevel() < math.abs(distance.x) + math.abs(distance.y) + math.abs(distance.z) then
                error("Not enough fuel to return to original location")
            end
            Turtle.moveTo(oldPosVec)
            Turtle.setDirection(oldDirVec)
            moveClean(posvec)
        elseif ERRORS.COULD_NOT_MOVE then
            Turtle.move()
            local function b(lr)
                return coroutine.yield(function()
                    Turtle.rotate(lr)
                    Turtle.moveForward(2)
                end)
            end

            if b(LR.LEFT).resume() and
                b(LR.RIGHT).resume() and
                Turtle.move(0, 1, 0).resume() and Turtle.move(0, -1, 0).resume() then
                error("Could not move")
            end
        else
            error("ERROR:" .. ERRMSGS[res.code])
        end
    end
    Turtle.digUp()
    Turtle.digDown()
end

WIDTH = 100
LENGTH = 100
HEIGHT = 3


local function doLine()
    for x = 2, LENGTH do
        moveClean()
        if x % 5 == 0 then
            Turtle.checkInventory()
        end
    end
    Turtle.checkInventory()
end

local a, b = LR.LEFT, LR.RIGHT
for i = 1, HEIGHT / 3 do
    for n = 1, WIDTH / 2 do
        --[[
        This does a full line, rotates around, then
        --]]
        doLine()
        Turtle.rotate(a)
        moveClean()
        Turtle.rotate(a)
        doLine()
        Turtle.rotate(b)
        moveClean()
        Turtle.rotate(b)
    end
    a, b = b, a
    moveClean(vector.new(0, 3, 0))
end
