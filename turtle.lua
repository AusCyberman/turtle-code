local SLOTS_COUNT = 16
local RETURN_HOME = 69


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
        return vec:new(vec.z, vec.y, vec.x)
    elseif lr == LR.RIGHT then
        return vec:new(vec.z, vec.y, -1 * vec.x)
    end
end

local function vec_muts(avec, bvec)
    if avec.x == bvec.x and avec.z == bvec.z then
        return {}
    else
        local turns = {}
        if avec.x == bvec.z then
            if avec.x == 1 then
                table.insert(turns, LR.LEFT)
            else
                table.insert(turns, LR.RIGHT)
            end
        elseif bvec.x == -1 then
            table.insert(turns, LR.LEFT)
            table.insert(turns, LR.LEFT)
        else
            if avec.x == 1 then
                table.insert(turns, LR.RIGHT)
            else
                table.insert(turns, LR.LEFT)
            end

        end
        return turns
    end
end

local function set_direction(vec)
    for _, dir in ipairs(vec_muts(directionVector, vec)) do
        turtle["turn" .. dir]()
    end
    directionVector = vec
end

local bypassFuelCheck = false

local function refuel()
    if bypassFuelCheck then return end
    local distance = start_loc:sub(directionVector)
    if turtle.getFuelLevel() > distance:length() then
        return
    end
    for i = 1, SLOTS_COUNT do
        turtle.select(i)
        turtle.refuel()
    end
    if turtle.getFuelLevel() > start_loc:sub(directionVector) then
        error({ code = RETURN_HOME })
    end

end

local function alt(n, f, g, mut)
    local sig = math.sign(n)
    return (sig == 1 and f) or g, sig * n, mut:mul(-1)
end

local function moveForward(n, mut)
    for i = 0, math.abs(n) do
        if turtle.detect() then
            if not turtle.dig() then
                error({ code = RETURN_HOME })
            end
        end
        turtle.forward()
        refuel()
        current_loc = current_loc:add(mut)
    end
end

local function move(...)
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
        local angleVec = vector.new(x/math.abs(x), 0, 0)
        set_direction(angleVec)
        moveForward(x, angleVec)
    end
    if z ~= 0 then
        local angleVec = vector.new(0, 0, z/math.abs(z))
        set_direction(angleVec)
        moveForward(y, angleVec)
    end
    if y ~= 0 then
        local dir = (y > 0 and DIR.UP) or DIR.DOWN
        for i = 0, math.abs(y) do
            refuel()
            if turtle["detect" .. dir]() then
                if not turtle["dig" .. dir] then
                    error({code = RETURN_HOME, "COULD NOT DIG " .. DIR.DOWN})
                end
            end
            turtle[string.lower(dir)]()
            current_loc.y = current_loc.y + ((y > 0 and 1) or 0)
        end
    end
end

local function moveTo(vec3)
    local diffVec = vec3:sub(current_loc)
    move(diffVec)
end

WIDTH = 10
LENGTH = 10
HEIGHT = 10

for x = 0, WIDTH do
    for y = 0, HEIGHT do
        for z = 0, LENGTH do
            local _, err = pcall(moveTo, vector.new(x, y, z))
            if err then
                if err.code == RETURN_HOME then
                    bypassFuelCheck = true
                    moveTo(start_loc)
                    print(err)
                else
                    error(err)
                end
            end
        end
    end
end
