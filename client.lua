WS_URL = "ws://mc.auscyber.me"
local client, err =  http.webSocket(WS_URL)
if not client then
    error(err)
end
local stop = false 



    local savedPrint = _G.print(...)
while not stop do 
    client.send("Hello World!")
    local receiv, b = client.receive(1)
        if receiv then
        _G.print = function(...) client.send(table.concat(table.pack(...), " ")) end
        local res,err = pcall(function() loadstring(receiv)() end)
        if not res then
           print("Err:")
           print(err) 
        else 
            print("Completed successfully")
        end
    end
end