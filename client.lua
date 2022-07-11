WS_URL = "ws://mc.auscyber.me"
local client, err =  http.webSocket(WS_URL)
if not client then
    error(err)
end
local stop = false 



local savedPrintfunction = _G.print
while not stop do 
    client.send("Hello World!")
    local receiv, b = client.receive(1)
        if receiv then
        _G.print = function(...) return client.send(table.concat(table.pack(...), " ")) end
        _G.read = function(...) 
            local res = client.receive(1)
            if not res then
                error("no data")
            end 
        end
        local res,err = pcall(function() loadstring(receiv)() end)
        if not res then
           print("Err:")
           print(err) 
        else 
            print("Completed successfully")
        end
    end
end