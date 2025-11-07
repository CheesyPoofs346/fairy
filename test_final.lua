do
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local DEBUG_ADMIN = true
local function b64url_to_bin(s)
    s = s:gsub("-", "+"):gsub("_", "/")
    local pad = #s % 4
    if pad == 2 then s = s .. "==" elseif pad == 3 then s = s .. "=" end
    local t = {}
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i+3)
        if not a then break end
        local n = (a and (a <= 90 and a-65 or a <= 122 and a-71 or a <= 57 and a+4 or a == 43 and 62 or a == 47 and 63) or 0)
        n = bit32.lshift(n, 6) + (b and (b <= 90 and b-65 or b <= 122 and b-71 or b <= 57 and b+4 or b == 43 and 62 or b == 47 and 63) or 0)
        n = bit32.lshift(n, 6) + (c and (c <= 90 and c-65 or c <= 122 and c-71 or c <= 57 and c+4 or c == 43 and 62 or c == 47 and 63) or 0)
        n = bit32.lshift(n, 6) + (d and (d <= 90 and d-65 or d <= 122 and d-71 or d <= 57 and d+4 or d == 43 and 62 or d == 47 and 63) or 0)
        t[#t+1] = string.char(bit32.rshift(n,16)%256)
        if c and c ~= 61 then t[#t+1] = string.char(bit32.rshift(n,8)%256) end
        if d and d ~= 61 then t[#t+1] = string.char(n%256) end
    end
    return table.concat(t)
end
local function rrotate(x, n)
    return ((bit32.rshift(x, n) + bit32.lshift(x, 32 - n)) % 2^32)
end
local function band(a,b) return bit32.band(a,b) end
local function bxor(a,b) return bit32.bxor(a,b) end
local function bor(a,b) return bit32.bor(a,b) end
local K = { 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2 }
local function sha256(msg)
    local bytes = {msg:byte(1, #msg)}
    local bitlen_hi, bitlen_lo = 0, (#bytes * 8) % 2^32
    bitlen_hi = math.floor((#bytes * 8) / 2^32)
    table.insert(bytes, 0x80)
    while (#bytes % 64) ~= 56 do table.insert(bytes, 0x00) end
    for i=7,0,-1 do table.insert(bytes, bit32.rshift(bitlen_hi, i*8) % 256) end
    for i=7,0,-1 do table.insert(bytes, bit32.rshift(bitlen_lo, i*8) % 256) end
    local H = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    for i=1,#bytes,64 do
        local w = {}
        for j = 0, 15 do
            local a = bytes[i + 4*j]     or 0
            local b = bytes[i + 4*j + 1] or 0
            local c = bytes[i + 4*j + 2] or 0
            local d = bytes[i + 4*j + 3] or 0
            w[j] = (((a*256 + b)*256 + c)*256 + d) % 2^32
        end
        for j=16,63 do
            local s0 = bxor(rrotate(w[j-15],7), rrotate(w[j-15],18), bit32.rshift(w[j-15],3))
            local s1 = bxor(rrotate(w[j-2],17), rrotate(w[j-2],19), bit32.rshift(w[j-2],10))
            w[j] = (w[j-16] + s0 + w[j-7] + s1) % 2^32
        end
        local a,b,c,d,e,f,g,h = H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]
        for j=0,63 do
            local S1 = bxor(rrotate(e,6), rrotate(e,11), rrotate(e,25))
            local ch = bxor(band(e,f), band(bxor(e,0xffffffff), g))
            local t1 = (h + S1 + ch + K[j+1] + w[j]) % 2^32
            local S0 = bxor(rrotate(a,2), rrotate(a,13), rrotate(a,22))
            local maj = bxor(band(a,b), band(a,c), band(b,c))
            local t2 = (S0 + maj) % 2^32
            h = g; g = f; f = e; e = (d + t1) % 2^32
            d = c; c = b; b = a; a = (t1 + t2) % 2^32
        end
        H[1] = (H[1]+a)%2^32; H[2]=(H[2]+b)%2^32; H[3]=(H[3]+c)%2^32; H[4]=(H[4]+d)%2^32
        H[5] = (H[5]+e)%2^32; H[6]=(H[6]+f)%2^32; H[7]=(H[7]+g)%2^32; H[8]=(H[8]+h)%2^32
    end
    local out = {}
    for i=1,8 do
        out[#out+1] = string.char(bit32.rshift(H[i],24)%256, bit32.rshift(H[i],16)%256, bit32.rshift(H[i],8)%256, H[i]%256)
    end
    return table.concat(out)
end
local function hmac_sha256(key, msg)
    if #key > 64 then key = sha256(key) end
    if #key < 64 then key = key .. string.rep("\0", 64 - #key) end
    local o_key_pad, i_key_pad = {}, {}
    for i=1,64 do
        local kb = key:byte(i)
        o_key_pad[i] = string.char(bit32.bxor(kb, 0x5c))
        i_key_pad[i] = string.char(bit32.bxor(kb, 0x36))
    end
    return sha256(table.concat(o_key_pad) .. sha256(table.concat(i_key_pad) .. msg))
end
local function b64url_from_bin(bin)
    local alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local out = {}
    for i=1,#bin,3 do
        local a,b1,c = bin:byte(i,i+2)
        local n = (a or 0)*65536 + (b1 or 0)*256 + (c or 0)
        out[#out+1] = string.char(
            string.byte(alpha, bit32.rshift(n,18)+1),
            string.byte(alpha, bit32.band(bit32.rshift(n,12),63)+1),
            (b1 and string.byte(alpha, bit32.band(bit32.rshift(n,6),63)+1) or 61),
            (c  and string.byte(alpha, bit32.band(n,63)+1) or 61)
        )
    end
    return table.concat(out):gsub("%+","-"):gsub("/","_"):gsub("=+$","")
end
local function consteq(a,b)
    if #a ~= #b then return false end
    local r=0
    for i=1,#a do r = bit32.bxor(r, a:byte(i), b:byte(i)) end
    return r == 0
end
local SECRET_PARTS = {
    "817340e3551ca5a4b32cd9d8188966583ebaf0e59286bbbf29c865c4348c49bf"
}
local function get_secret()
    return SECRET_PARTS[1]
end
_G.IS_ADMIN = _G.IS_ADMIN or false
local ADMIN_VERIFY_URL = "https://key-system-test-psi.vercel.app/api/verify"
local USE_REMOTE_VERIFY = true
local USE_LOCAL_FALLBACK = true
local httpRequest = (syn and syn.request) or http_request or request or (http and http.request)
if DEBUG_ADMIN then
    print("=== ADMIN KEY SYSTEM LOADED ===")
    print("DEBUG_ADMIN: enabled")
    print("Verify URL:", ADMIN_VERIFY_URL)
    print("Executor HTTP:", httpRequest and "✓ Available" or "✗ Not found")
    print("Client Secret (first 16 chars):", string.sub(get_secret(), 1, 16) .. "...")
    print("Local UID:", LocalPlayer.UserId)
    print("================================")
end
local function localVerify(token)
    if type(token) ~= "string" then return false, "malformed" end
    local pfx, p64, s64 = token:match("^(%w+)%.([A-Za-z0-9_%-%=]+)%.([A-Za-z0-9_%-%=]+)$")
    if pfx ~= "GK" or not p64 or not s64 then return false, "malformed" end
    local clientSecret = get_secret()
    if type(clientSecret) ~= "string" or #clientSecret < 16 then
        return false, "client_secret_invalid"
    end
    local expected = b64url_from_bin(hmac_sha256(clientSecret, p64))
    if not consteq(expected, s64) then return false, "sig_mismatch" end
    local payloadJson = b64url_to_bin(p64)
    local ok, payload = pcall(function() return HttpService:JSONDecode(payloadJson) end)
    if not ok or type(payload) ~= "table" then return false, "payload_decode_error" end
    if tostring(payload.uid) ~= tostring(LocalPlayer.UserId) then
        return false, ("uid_mismatch (got %s, need %s)"):format(tostring(payload.uid), tostring(LocalPlayer.UserId))
    end
    if type(payload.exp) ~= "number" or payload.exp < os.time() then return false, "expired" end
    return true, (payload.typ == "lifetime")
end
local function verifyTokenForLocalUser(token)
    if DEBUG_ADMIN then
        print("═══════════════════════════════════════════")
        print("[AdminKey] Starting verification")
        print("  UID:", LocalPlayer.UserId)
        print("  Token (first 30 chars):", string.sub(token, 1, 30) .. "...")
        print("═══════════════════════════════════════════")
    end
    if USE_REMOTE_VERIFY and httpRequest then
        if DEBUG_ADMIN then print("[AdminKey] Using executor HTTP request...") end
        local body = HttpService:JSONEncode({
            uid = tostring(LocalPlayer.UserId),
            token = token
        })
        local success, response = pcall(function()
            return httpRequest({
                Url = ADMIN_VERIFY_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        end)
        if DEBUG_ADMIN then
            print("[AdminKey] HTTP request success:", success)
            if success and response then
                print("[AdminKey] Status Code:", response.StatusCode)
                print("[AdminKey] Response Body:", response.Body)
            elseif not success then
                warn("[AdminKey] HTTP error:", response)
            end
        end
        if success and response and response.StatusCode == 200 then
            local parseOk, parsed = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)
            if parseOk and parsed then
                if DEBUG_ADMIN then
                    print("[AdminKey] Parsed response:", HttpService:JSONEncode(parsed))
                end
                if parsed.ok == true then
                    if DEBUG_ADMIN then
                        print("✓✓✓ Remote verification SUCCESS ✓✓✓")
                        print("═══════════════════════════════════════════")
                    end
                    return true, false
                else
                    if DEBUG_ADMIN then
                        warn("✗✗✗ Remote verification REJECTED ✗✗✗")
                        warn("  Server error:", parsed.error or "unknown")
                    end
                    if not USE_LOCAL_FALLBACK then
                        if DEBUG_ADMIN then print("═══════════════════════════════════════════") end
                        return false, parsed.error or "invalid"
                    end
                end
            end
        end
        if DEBUG_ADMIN then
            warn("[AdminKey] Remote verification failed, using local fallback...")
        end
    elseif USE_REMOTE_VERIFY and not httpRequest then
        if DEBUG_ADMIN then
            warn("[AdminKey] Executor HTTP not available, using local verification")
        end
    end
    if DEBUG_ADMIN then print("[AdminKey] Using local HMAC verification...") end
    local success, result = localVerify(token)
    if DEBUG_ADMIN then
        if success then
            print("✓✓✓ Local verification SUCCESS ✓✓✓")
            print("  Lifetime token:", tostring(result == true))
        else
            warn("✗✗✗ Local verification FAILED ✗✗✗")
            warn("  Reason:", result)
        end
        print("═══════════════════════════════════════════")
    end
    return success, result
end
local function showKeyPrompt(onResult)
    if DEBUG_ADMIN then print("[AdminKey] showKeyPrompt(): creating prompt UI") end
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "AdminUnlockPrompt"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.Parent = pg
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(420, 190)
    frame.Position = UDim2.new(0.5,-210,0.5,-95)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,26)
    frame.Parent = sg
    local corner = Instance.new("UICorner", frame) corner.CornerRadius = UDim.new(0, 10)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-24,0,36); lbl.Position = UDim2.fromOffset(12,10)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 20; lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Text = "Enter Admin Key"; lbl.Parent = frame
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1,-24,0,40); tb.Position = UDim2.fromOffset(12,56)
    tb.PlaceholderText = "Paste token: GK.xxx.yyy"
    tb.ClearTextOnFocus = false
    tb.Font = Enum.Font.Gotham; tb.TextWrapped = true; tb.MultiLine = true
    tb.TextXAlignment = Enum.TextXAlignment.Left; tb.TextScaled = false; tb.TextSize = 12
    tb.TextColor3 = Color3.new(1,1,1)
    tb.BackgroundColor3 = Color3.fromRGB(35,35,40)
    tb.Parent = frame
    local c2 = Instance.new("UICorner", tb) c2.CornerRadius = UDim.new(0, 8)
    if DEBUG_ADMIN then
        tb:GetPropertyChangedSignal("Text"):Connect(function()
            print("[AdminKey] typing; len=", #tb.Text)
        end)
        tb.FocusLost:Connect(function()
            print("[AdminKey] textbox focus lost; len=", #tb.Text)
        end)
    end
    local who = Instance.new("TextLabel")
    who.Size = UDim2.new(1,-24,0,18)
    who.Position = UDim2.fromOffset(12, 140)
    who.BackgroundTransparency = 1
    who.Font = Enum.Font.Gotham
    who.TextSize = 12
    who.TextColor3 = Color3.fromRGB(180,180,180)
    who.Text = "Expecting UID: " .. tostring(LocalPlayer.UserId)
    who.Parent = frame
    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1,-24,0,20); msg.Position = UDim2.fromOffset(12,100)
    msg.BackgroundTransparency = 1; msg.Font = Enum.Font.Gotham; msg.TextSize = 14
    msg.TextColor3 = Color3.fromRGB(255,120,120); msg.Text = ""; msg.Parent = frame
    local okBtn = Instance.new("TextButton")
    okBtn.Size = UDim2.fromOffset(120, 36); okBtn.Position = UDim2.new(1,-132,1,-46)
    okBtn.Text = "Unlock"; okBtn.Font = Enum.Font.GothamBold; okBtn.TextSize = 18
    okBtn.TextColor3 = Color3.new(1,1,1); okBtn.BackgroundColor3 = Color3.fromRGB(0,120,255)
    okBtn.Parent = frame
    local c3 = Instance.new("UICorner", okBtn) c3.CornerRadius = UDim.new(0,8)
    okBtn.MouseButton1Click:Connect(function()
        if DEBUG_ADMIN then print("[AdminKey] Unlock clicked") end
        local tok = (tb.Text or "")
        tok = tok:gsub("%s+", ""):gsub("[`“”\"']", "")
        if DEBUG_ADMIN then print("[AdminKey] token.len after sanitize:", #tok) end
        if #tok < 12 then
            msg.TextColor3 = Color3.fromRGB(255,200,120)
            msg.Text = "Please paste the full token"
            return
        end
        msg.TextColor3 = Color3.fromRGB(255,235,120)
        msg.Text = "Verifying..."
        local okCall, result, lifetime = pcall(verifyTokenForLocalUser, tok)
        if not okCall then
            msg.TextColor3 = Color3.fromRGB(255,120,120)
            msg.Text = "verify error: " .. tostring(result)
            warn("[AdminKey] exception during verify:", result)
            return
        end
        if result == true then
            _G.IS_ADMIN = true
            msg.TextColor3 = Color3.fromRGB(120,255,120)
            msg.Text = "Access granted!"
            if DEBUG_ADMIN then print("[AdminKey] ✓ UNLOCKED; lifetime=", tostring(lifetime == true)) end
            task.delay(0.1, function()
                sg:Destroy()
                if onResult then pcall(onResult, true, lifetime == true) end
            end)
        else
            msg.TextColor3 = Color3.fromRGB(255,120,120)
            local errorMsg = tostring(result or "Invalid/expired key")
            if errorMsg:find("sig_mismatch") then
                msg.Text = "Key rejected: Secret mismatch (check SHARED_SECRET)"
            elseif errorMsg:find("expired") then
                msg.Text = "Key expired (generate a new 24h key)"
            elseif errorMsg:find("uid_mismatch") then
                msg.Text = "Key is for a different user"
            elseif errorMsg:find("http_error") then
                msg.Text = "Connection failed (trying local verify...)"
            else
                msg.Text = "Invalid: " .. errorMsg
            end
            warn("[AdminKey] ✗ verify failed:", result)
        end
    end)
    return function() sg:Destroy() end
end
_G.UnlockAdmin = function(callback)
    if DEBUG_ADMIN then print("[AdminKey] _G.UnlockAdmin called; IS_ADMIN=", tostring(_G.IS_ADMIN)) end
    if _G.IS_ADMIN then if callback then callback(true, true) end return end
    showKeyPrompt(callback)
end
end
local Players            = game:GetService("Players")
local CoreGui            = game:GetService("CoreGui")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local CollectionService  = game:GetService("CollectionService")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")
local LocalPlayer        = Players.LocalPlayer
local CACHE = {
    playerName = LocalPlayer.Name,
    playerFarm = nil,
    plantsFolder = nil,
    lastFarmScan = 0,
    farmScanInterval = 5,
}
local FARM_MON = { running = true, thread = nil }
local DEBUG_MODE = false
FARM_MON.thread = task.spawn(function()
    local function findPlayerFarm()
        print("DEBUG: Searching for farm belonging to:", CACHE.playerName)
        local farm = Workspace:FindFirstChild("Farm")
        if not farm then
            print("DEBUG: No Farm container found in Workspace")
            return nil
        end
        local playerFarm = farm:FindFirstChild(CACHE.playerName)
        if playerFarm then
            local important = playerFarm:FindFirstChild("Important")
            if important and important:FindFirstChild("Plants_Physical") then
                print("DEBUG: Found player farm by direct name match:", playerFarm.Name)
                return playerFarm
            end
        end
        print("DEBUG: No direct name match, checking all farms for ownership...")
        for _, child in ipairs(farm:GetChildren()) do
            if child:IsA("Model") or child:IsA("Folder") then
                local important = child:FindFirstChild("Important")
                if important then
                    local plantsPhysical = important:FindFirstChild("Plants_Physical")
                    local data = important:FindFirstChild("Data")
                    if plantsPhysical and data then
                        local owner = data:FindFirstChild("Owner")
                        if owner and owner.Value == CACHE.playerName then
                            print("DEBUG: Found owned farm with correct structure:", child.Name)
                            return child
                        elseif owner then
                            print("DEBUG: Farm", child.Name, "belongs to:", owner.Value)
                        end
                    end
                end
            end
        end
        print("DEBUG: No valid player farm found")
        return nil
    end
    task.wait(2)
    if not FARM_MON.running then return end
    CACHE.playerFarm = findPlayerFarm()
    if CACHE.playerFarm then
        local important = CACHE.playerFarm:FindFirstChild("Important")
        if important then
            CACHE.plantsFolder = important:FindFirstChild("Plants_Physical")
            if CACHE.plantsFolder then
                print("DEBUG: Successfully cached player farm:", CACHE.playerFarm.Name)
                print("DEBUG: Plants folder found with", #CACHE.plantsFolder:GetChildren(), "children")
            else
                print("DEBUG: No Plants_Physical folder found in", CACHE.playerFarm.Name)
            end
        end
    else
        print("DEBUG: Failed to find player farm")
    end
    while FARM_MON.running do
        task.wait(CACHE.farmScanInterval)
        if not FARM_MON.running then break end
        if not CACHE.playerFarm or not CACHE.playerFarm.Parent then
            print("DEBUG: Re-scanning for player farm...")
            CACHE.playerFarm = findPlayerFarm()
            if CACHE.playerFarm then
                local important = CACHE.playerFarm:FindFirstChild("Important")
                if important then
                    CACHE.plantsFolder = important:FindFirstChild("Plants_Physical")
                end
            end
        end
    end
end)
local HARVEST = {
    PLANT_TAGS = {"Plant","Crop","Harvestable","CollectPrompt","HarvestPrompt","Seed","Tree","Fruit","Berry","Vegetable","Flower","Carrot","Pineapple","Tomato","Potato","Corn","Wheat"},
    PLANTS_FOLDERS = {"Plants","Crops","Garden","Farm","Seeds","Trees","Fruits","Berries","Vegetables","Flowers","Plot","Plots","Plants_Physical","Carrots","Pineapples","Tomatoes","Potatoes"},
    OWNER_ATTRS={"OwnerUserId","OwnerId","PlotOwner","UserId"},
    OWNER_OBJECTVALS={"Owner","PlotOwner","Player"},
    READY_ATTRS_BOOL={"Ready","IsRipe","HarvestReady","Mature","Grown"},
    READY_ATTRS_TEXT={"Stage","State","Growth","Status"},
    READY_TEXT_SET={ripe=true,mature=true,harvest=true,ready=true,grown=true,fullygrown=true,harvestable=true},
    REMOTE_NAMES={"Harvest","Collect","Pickup","Gather","HarvestPlant","CollectPlant"},
    ARG_VARIANTS=function(plant, player)
        return {
            {plant},
            {plant, player},
            {plant, true},
            {plant, player, true},
            {player, plant},
            {plant.Name},
            {plant:GetAttribute("Id")},
            {plant:GetAttribute("ID")},
            {true, plant},
            {},
        }
    end,
    MAX_PER_TICK=3,
    COLLECTION_DELAY=0.05,
}
local MUTATION = {
    enabled = false,
    set = {},
    lastText = ""
}
local function getPlantVariantName(model)
    local v = model:GetAttribute("Variant") or model:GetAttribute("Mutation")
           or model:GetAttribute("Type")    or model:GetAttribute("Rarity")
    if type(v) == "string" and #v > 0 then
        return string.lower(v)
    end
    local sv = model:FindFirstChild("Variant") or model:FindFirstChild("Mutation")
            or model:FindFirstChild("Type")    or model:FindFirstChild("Rarity")
    if sv and sv:IsA("StringValue") and sv.Value then
        return string.lower(sv.Value)
    end
    for k, val in pairs(model:GetAttributes()) do
        if val == true then
            return string.lower(k)
        end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local texts = {d.ObjectText or "", d.ActionText or "", d.Name or ""}
            local combined = table.concat(texts, " ")
            if #combined:gsub("%s","") > 0 then
                return string.lower(combined)
            end
        end
    end
    return string.lower(model.Name or "")
end
local function hasWantedMutation(model)
    if not MUTATION.enabled then
        print("DEBUG: Mutation filter disabled, accepting", model.Name)
        return true
    end
    if not next(MUTATION.set) then
        print("DEBUG: No mutations in filter set, rejecting", model.Name)
        return false
    end
    local blob = {}
    local function add(s) if typeof(s)=="string" and #s>0 then blob[#blob+1] = string.lower(s) end end
    add(getPlantVariantName(model))
    add(model.Name)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            add(d.ObjectText); add(d.ActionText); add(d.Name)
        end
    end
    for k, val in pairs(model:GetAttributes()) do
        if val == true then add(k) end
        if typeof(val)=="string" and #val>0 then add(k); add(val) end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if CollectionService:HasTag(d, "Cleanup_Glimmering") then
            add("glimmering")
            break
        end
    end
    local text = table.concat(blob, " ")
    print('DEBUG: Checking mutations for', model.Name, '- text blob: "' .. text .. '"')
    if #text == 0 then
        print("DEBUG: No text found for mutation check, rejecting", model.Name)
        return false
    end
    for token,_ in pairs(MUTATION.set) do
        if string.find(text, token, 1, true) then
            print("DEBUG: Found mutation", token, "in", model.Name, "- ACCEPTING")
            return true
        end
    end
    print("DEBUG: No wanted mutations found in", model.Name, "- REJECTING")
    local mutationList = {}
    for token,_ in pairs(MUTATION.set) do table.insert(mutationList, token) end
    print("DEBUG: Looking for mutations:", table.concat(mutationList, ", "))
    return false
end
local THEME = {
    BG1=Color3.fromRGB(24,26,32), BG2=Color3.fromRGB(32,35,43), BG3=Color3.fromRGB(38,41,50),
    CARD=Color3.fromRGB(30,33,40), ACCENT=Color3.fromRGB(230,72,72),
    TEXT=Color3.fromRGB(220,221,222), MUTED=Color3.fromRGB(171,178,191), BORDER=Color3.fromRGB(64,70,85),
}
local FONTS={H=Enum.Font.GothamSemibold,B=Enum.Font.Gotham,HB=Enum.Font.GothamBold}
local FADE_DUR=0.6
local OPACITY = {
    BG1 = 0.02,
    BG2 = 0.04,
    BG3 = 0.06,
    CARD = 0.05,
}
local function sameColor(a,b)
    if not a or not b then return false end
    local ax,ay,az = a.R, a.G, a.B
    local bx,by,bz = b.R, b.G, b.B
    local eps = 1/255
    return math.abs(ax-bx) < eps and math.abs(ay-by) < eps and math.abs(az-bz) < eps
end
local function applyGlassLook(root)
    local function baseOpacityFor(c)
        if sameColor(c, THEME.BG1) then return OPACITY.BG1 end
        if sameColor(c, THEME.BG2) then return OPACITY.BG2 end
        if sameColor(c, THEME.BG3) then return OPACITY.BG3 end
        if sameColor(c, THEME.CARD) then return OPACITY.CARD end
        return nil
    end
    for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("Frame") or d:IsA("ScrollingFrame") or d:IsA("TextBox") or d:IsA("TextButton") then
            local base = baseOpacityFor(d.BackgroundColor3)
            if base then
                d.BackgroundTransparency = base
            end
        end
    end
end
local function mk(class, props, parent) local o=Instance.new(class); for k,v in pairs(props or {}) do o[k]=v end; if parent then o.Parent=parent end; return o end
local function corner(p,r) mk("UICorner",{CornerRadius=UDim.new(0,r or 8)},p) end
local function stroke(p,t,c) mk("UIStroke",{Thickness=t or 1,Color=c or THEME.BORDER,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p) end
local function pad(p,t,r,b,l) mk("UIPadding",{PaddingTop=UDim.new(0,t or 0),PaddingRight=UDim.new(0,r or 0),PaddingBottom=UDim.new(0,b or 0),PaddingLeft=UDim.new(0,l or 0)},p) end
local function vlist(p,px) return mk("UIListLayout",{Padding=UDim.new(0,px or 8),SortOrder=Enum.SortOrder.LayoutOrder},p) end
local function hover(btn,on,off)
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),on):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),off):Play() end)
end
local GLOBAL_CONNS = {}
local function trackConn(conn)
    table.insert(GLOBAL_CONNS, conn)
    return conn
end
local OrigT = setmetatable({}, {__mode="k"})
local function snapshotTransparency(inst)
    OrigT = {}
    local function scan(node)
        local rec={}
        if node:IsA("Frame") or node:IsA("ScrollingFrame") then rec.bt=node.BackgroundTransparency end
        if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
            rec.bt=node.BackgroundTransparency; rec.tt=node.TextTransparency
        end
        if node:IsA("ImageLabel") or node:IsA("ImageButton") then
            rec.bt=node.BackgroundTransparency; rec.it=node.ImageTransparency
        end
        if node:IsA("UIStroke") then rec.st=node.Transparency end
        if next(rec) then OrigT[node]=rec end
        for _,c in ipairs(node:GetChildren()) do scan(c) end
    end
    scan(inst)
end
local function tweenTo(inst, dur, to1)
    for obj,rec in pairs(OrigT) do
        local props={}
        if rec.bt~=nil then props.BackgroundTransparency = (to1 and 1 or rec.bt) end
        if rec.tt~=nil then props.TextTransparency       = (to1 and 1 or rec.tt) end
        if rec.it~=nil then props.ImageTransparency      = (to1 and 1 or rec.it) end
        if rec.st~=nil then props.Transparency           = (to1 and 1 or rec.st) end
        if next(props) then TweenService:Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end
    end
end
local function tolower(s) return typeof(s)=="string" and string.lower(s) or s end
local function textLooksHarvesty(s)
    s = tolower(s or "")
    return s:find("harvest") or s:find("collect") or s:find("gather") or s:find("pick")
end
local function nearestModel(inst)
    if not inst then return nil end
    if inst:IsA("Model") then return inst end
    return inst:FindFirstAncestorOfClass("Model")
end
local remoteCache={}
local remoteCacheConn=nil
local function cacheReplicatedRemotes()
    remoteCache={}
    local function add(r) remoteCache[r.Name]=remoteCache[r.Name] or {}; table.insert(remoteCache[r.Name],r) end
    for _,d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            for _,nm in ipairs(HARVEST.REMOTE_NAMES) do if d.Name==nm then add(d) break end end
        end
    end
end
cacheReplicatedRemotes()
remoteCacheConn = ReplicatedStorage.DescendantAdded:Connect(function(d)
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        for _,nm in ipairs(HARVEST.REMOTE_NAMES) do if d.Name==nm then remoteCache[nm]=remoteCache[nm] or {}; table.insert(remoteCache[nm], d) break end end
    end
end)
local function ownsPlant(player, plant)
    if not plant or not plant.Parent then return false end
    if CACHE.playerFarm and plant:IsDescendantOf(CACHE.playerFarm) then
        return true
    end
    if CACHE.plantsFolder and plant:IsDescendantOf(CACHE.plantsFolder) then
        return true
    end
    local uid = plant:GetAttribute("OwnerUserId") or plant:GetAttribute("OwnerId") or plant:GetAttribute("UserId")
    if typeof(uid) == "number" and uid == player.UserId then return true end
    if typeof(uid) == "string" and tonumber(uid) == player.UserId then return true end
    local sv = plant:FindFirstChild("Owner") or plant:FindFirstChild("PlotOwner") or plant:FindFirstChild("Player")
    if sv and sv:IsA("ObjectValue") and sv.Value == player then return true end
    if sv and sv:IsA("StringValue") and sv.Value == player.Name then return true end
    local important = plant:FindFirstAncestor("Important")
    if important then
        local data = important:FindFirstChild("Data")
        if data then
            local owner = data:FindFirstChild("Owner")
            if owner then
                if owner:IsA("ObjectValue") and owner.Value == player then return true end
                if owner:IsA("StringValue") and owner.Value == player.Name then return true end
            end
            local ownerIdV = data:FindFirstChild("OwnerUserId") or data:FindFirstChild("OwnerId")
            if ownerIdV and tonumber(ownerIdV.Value) == player.UserId then return true end
        end
    end
    if DEBUG_MODE then
        print("[OWNERSHIP] REJECT:", plant:GetFullName(), "- not owned by", player.Name)
    end
    return false
end
local function isPlantReady(plant)
    local foundAnyPrompt = false
    for _,pp in ipairs(plant:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            foundAnyPrompt = true
            if pp.Enabled then
                return true
            end
        end
    end
    if foundAnyPrompt then
        return false
    end
    for _,a in ipairs(HARVEST.READY_ATTRS_BOOL) do
        if plant:GetAttribute(a) == true then
            return true
        end
    end
    for _,a in ipairs(HARVEST.READY_ATTRS_TEXT) do
        local v = plant:GetAttribute(a)
        if typeof(v)=="string" then
            local key = (v:gsub("%s","")):lower()
            if HARVEST.READY_TEXT_SET[key] then
                return true
            end
        end
    end
    return false
end
local function getAllPlants()
    local out = {}
    if not CACHE.plantsFolder or not CACHE.plantsFolder.Parent then
        print("DEBUG: No valid plants folder cached for player:", CACHE.playerName)
        return out
    end
    if not CACHE.playerFarm or not CACHE.playerFarm.Parent then
        print("DEBUG: Cached player farm is invalid")
        CACHE.plantsFolder = nil
        return out
    end
    print("DEBUG: Collecting plants from verified player farm:", CACHE.playerFarm.Name)
    for _, child in ipairs(CACHE.plantsFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(out, child)
            print("DEBUG: Added plant from player farm:", child.Name)
        end
    end
    print("DEBUG: Total plants collected from player farm:", #out)
    if #out == 0 then
        print("DEBUG: WARNING - No plants found in player's Plants_Physical folder")
        print("DEBUG: Plants folder children count:", #CACHE.plantsFolder:GetChildren())
        print("DEBUG: Farm name:", CACHE.playerFarm.Name)
    end
    return out
end
local function tryRemotesForPlant(plant,player)
    if not ownsPlant(player, plant) then return false end
    local list={}
    for _,d in ipairs(plant:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            for _,nm in ipairs(HARVEST.REMOTE_NAMES) do if d.Name==nm then table.insert(list,d) break end end
        end
    end
    for _,nm in ipairs(HARVEST.REMOTE_NAMES) do if remoteCache[nm] then for _,r in ipairs(remoteCache[nm]) do table.insert(list,r) end end end
    for _,remote in ipairs(list) do
        for _,args in ipairs(HARVEST.ARG_VARIANTS(plant,player)) do
            if remote:IsA("RemoteEvent") then if pcall(function() remote:FireServer(unpack(args)) end) then return true end
            else if pcall(function() remote:InvokeServer(unpack(args)) end) then return true end end
        end
    end
    return false
end
local function tryExploitHelpers(plant)
    if not ownsPlant(LocalPlayer, plant) then return false end
    for _,pp in ipairs(plant:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            print("DEBUG: Found ProximityPrompt in", plant.Name, "- firing")
            local fpp = rawget(getfenv() or _G, "fireproximityprompt") or _G.fireproximityprompt
            if typeof(fpp)=="function" and pcall(fpp, pp) then
                print("DEBUG: Successfully fired ProximityPrompt for", plant.Name)
                return true
            end
        end
    end
    for _,cd in ipairs(plant:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            print("DEBUG: Found ClickDetector in", plant.Name, "- firing")
            local fcd = rawget(getfenv() or _G, "fireclickdetector") or _G.fireclickdetector
            if typeof(fcd)=="function" and pcall(fcd, cd) then
                print("DEBUG: Successfully fired ClickDetector for", plant.Name)
                return true
            end
        end
    end
    return false
end
local collecting=false
local function CollectAllPlants(toast)
    if collecting then if toast then toast("Collect already running…") end; return {ok=false,msg="busy"} end
    collecting=true
    local total,ready,collected,processed=0,0,0,0
    local allPlants = getAllPlants()
    for _,plant in ipairs(allPlants) do
        total = total + 1
        if isPlantReady(plant) and hasWantedMutation(plant) then
            ready = ready + 1
            if tryRemotesForPlant(plant,LocalPlayer) or tryExploitHelpers(plant) then
                collected = collected + 1
            end
            task.wait(HARVEST.COLLECTION_DELAY)
        end
        processed = processed + 1
        if processed % HARVEST.MAX_PER_TICK == 0 then
            task.wait(0.1)
        end
    end
    collecting=false
    if toast then toast(("Collected %d / %d ready (of %d total)."):format(collected,ready,total)) end
    return {ok=true,total=total,ready=ready,collected=collected}
end
local function harvestViaCropsRemote(toast)
    local ge      = ReplicatedStorage:FindFirstChild("GameEvents")
    local crops   = ge and ge:FindFirstChild("Crops")
    local collect = crops and crops:FindFirstChild("Collect")
    if not (collect and collect:IsA("RemoteEvent")) then
        return false, 0
    end
    local uniq, targets = {}, {}
    local function addModel(m)
        if not m or uniq[m] then return end
        if not ownsPlant(LocalPlayer, m) then return end
        if MUTATION.enabled and not hasWantedMutation(m) then return end
        if not isPlantReady(m) then return end
        uniq[m] = true
        table.insert(targets, m)
    end
    for _, pp in ipairs(CollectionService:GetTagged("CollectPrompt")) do
        if pp:IsA("ProximityPrompt") then addModel(nearestModel(pp)) end
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local txt = d.ActionText or d.ObjectText or d.Name
            if textLooksHarvesty(txt) then addModel(nearestModel(d)) end
        end
    end
    for _, m in ipairs(getAllPlants()) do
        if isPlantReady(m) then addModel(m) end
    end
    if #targets == 0 then
        if toast then toast("No ready crops found (owned).") end
        return true, 0
    end
    local sent = 0
    for i = 1, #targets, HARVEST.MAX_PER_TICK do
        local slice = {}
        for j = i, math.min(i + HARVEST.MAX_PER_TICK - 1, #targets) do
            slice[#slice+1] = targets[j]
        end
        local ok = pcall(function() collect:FireServer(slice) end)
        if ok then sent = sent + #slice else warn("[Harvest] Crops.Collect batch failed") end
        task.wait()
    end
    if toast then toast(("Harvested %d crops (yours) via Crops.Collect"):format(sent)) end
    return true, sent
end
local AUTO = {
    enabled    = false,
    method     = "Wireless",
    interval   = 5.0,
    fireDelay  = 0.25,
    tweenSpeed = 1.0,
    _task      = nil,
    _busy      = false,
}
AUTO.debugMode = DEBUG_MODE
local AUTO_SELL = {
    enabled = false,
    _task = nil,
    _busy = false,
    sellLocation = nil,
    messageConnection = nil,
    playerGuiConn = nil,
    playerGuiDescendantConns = {},
    starterGuiSetCoreOriginal = nil,
}
local performAutoSell
local function setupInventoryMessageListener()
    if AUTO_SELL.messageConnection then return end
    local function checkMessage(message)
        if not AUTO_SELL.enabled then return end
        local lowerMsg = string.lower(tostring(message))
        if string.find(lowerMsg, "max") and string.find(lowerMsg, "backpack") and string.find(lowerMsg, "space") then
            print("DEBUG: Detected max backpack message:", message)
            print("DEBUG: AUTO_SELL._busy status:", AUTO_SELL._busy)
            if not AUTO_SELL._busy then
                print("DEBUG: Starting auto-sell process...")
                task.defer(function()
                    local ok, err = pcall(performAutoSell)
                    if not ok then
                        warn("[AutoSell] performAutoSell error:", err)
                        AUTO_SELL._busy = false
                    end
                end)
            else
                print("DEBUG: Auto-sell already busy, skipping...")
            end
            return
        end
        if string.find(lowerMsg, "inventory") and (
           string.find(lowerMsg, "full") or
           string.find(lowerMsg, "max") or
           string.find(lowerMsg, "limit") or
           string.find(lowerMsg, "space")
        ) then
            print("DEBUG: Detected inventory full message:", message)
            print("DEBUG: AUTO_SELL._busy status:", AUTO_SELL._busy)
            if not AUTO_SELL._busy then
                print("DEBUG: Starting auto-sell process...")
                task.defer(function()
                    local ok, err = pcall(performAutoSell)
                    if not ok then
                        warn("[AutoSell] performAutoSell error:", err)
                        AUTO_SELL._busy = false
                    end
                end)
            else
                print("DEBUG: Auto-sell already busy, skipping...")
            end
        end
    end
    local starterGui = game:GetService("StarterGui")
    AUTO_SELL.messageConnection = starterGui.CoreGuiChangedSignal:Connect(function(coreGuiType)
        if coreGuiType == Enum.CoreGuiType.Chat then
            local success, lastMessage = pcall(function()
                local chat = starterGui:FindFirstChild("Chat")
                if chat then
                    return chat
                end
            end)
        end
    end)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local function monitorGui(gui)
        if gui:IsA("ScreenGui") then
            local function onDescendantAdded(descendant)
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                    task.spawn(function()
                        for i = 1, 5 do
                            task.wait(0.1)
                            if descendant.Parent and descendant.Text then
                                checkMessage(descendant.Text)
                            end
                        end
                    end)
                end
            end
            local c = gui.DescendantAdded:Connect(onDescendantAdded)
            table.insert(AUTO_SELL.playerGuiDescendantConns, c)
            for _, descendant in ipairs(gui:GetDescendants()) do
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                    checkMessage(descendant.Text)
                end
            end
            for _, descendant in ipairs(gui:GetDescendants()) do
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                    local pc = descendant:GetPropertyChangedSignal("Text"):Connect(function()
                        checkMessage(descendant.Text)
                    end)
                    table.insert(AUTO_SELL.playerGuiDescendantConns, pc)
                end
            end
        end
    end
    for _, gui in ipairs(playerGui:GetChildren()) do
        monitorGui(gui)
    end
    AUTO_SELL.playerGuiConn = playerGui.ChildAdded:Connect(monitorGui)
    local starterGui = game:GetService("StarterGui")
    if not AUTO_SELL.starterGuiSetCoreOriginal then AUTO_SELL.starterGuiSetCoreOriginal = starterGui.SetCore end
    local originalSetCore = AUTO_SELL.starterGuiSetCoreOriginal
    starterGui.SetCore = function(self, setting, data)
        if setting == "ChatMakeSystemMessage" or setting == "SendNotification" then
            if type(data) == "table" and data.Text then
                checkMessage(data.Text)
            elseif type(data) == "string" then
                checkMessage(data)
            end
        end
        return originalSetCore(self, setting, data)
    end
    print("DEBUG: Auto-sell message listener setup complete - monitoring for 'Max backpack space! Go sell' messages")
end
local function findSellLocation()
    local npcs = Workspace:FindFirstChild("NPCS")
    if npcs then
        local steven = npcs:FindFirstChild("Steven")
        if steven then
            local hrp = steven:FindFirstChild("HumanoidRootPart")
            if hrp then
                AUTO_SELL.sellLocation = hrp.CFrame
                return hrp.CFrame
            end
        end
    end
    return nil
end
performAutoSell = function()
    print("DEBUG: performAutoSell() called")
    if AUTO_SELL._busy then
        print("DEBUG: performAutoSell() - already busy, returning")
        return false
    end
    print("DEBUG: Setting busy state and starting sell process")
    AUTO_SELL._busy = true
    local character = LocalPlayer.Character
    if not character then
        print("DEBUG: No character found")
        AUTO_SELL._busy = false
        return false
    end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        print("DEBUG: No HumanoidRootPart found")
        AUTO_SELL._busy = false
        return false
    end
    local originalPosition = humanoidRootPart.CFrame
    print("DEBUG: Stored original position:", originalPosition)
    if not AUTO_SELL.sellLocation then
        print("DEBUG: Sell location not cached, finding it...")
        findSellLocation()
    end
    if not AUTO_SELL.sellLocation then
        print("DEBUG: Could not find sell NPC location")
        AUTO_SELL._busy = false
        return false
    end
    print("DEBUG: Auto-selling triggered by inventory full message - teleporting to sell NPC...")
    print("DEBUG: Sell location:", AUTO_SELL.sellLocation)
    local sellPosition = AUTO_SELL.sellLocation * CFrame.new(0, 0, -5)
    humanoidRootPart.CFrame = sellPosition
    print("DEBUG: Teleported to sell position:", sellPosition)
    task.wait(0.5)
    print("DEBUG: Attempting to fire sell remote...")
    local success = pcall(function()
        local sellRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Sell_Inventory")
        sellRemote:FireServer()
        print("DEBUG: Sell inventory remote fired successfully")
    end)
    if not success then
        print("DEBUG: Failed to fire sell remote")
    end
    task.wait(1.0)
    humanoidRootPart.CFrame = originalPosition
    print("DEBUG: Auto-sell complete - returned to original position")
    AUTO_SELL._busy = false
    print("DEBUG: Reset busy state")
    return success
end
local function startAutoSell(toast)
    if AUTO_SELL.enabled then return end
    AUTO_SELL.enabled = true
    if toast then toast("Auto-sell ON (message-triggered)") end
    findSellLocation()
    setupInventoryMessageListener()
end
local function stopAutoSell(toast)
    AUTO_SELL.enabled = false
    if toast then toast("Auto-sell OFF") end
    if AUTO_SELL.messageConnection then
        AUTO_SELL.messageConnection:Disconnect()
        AUTO_SELL.messageConnection = nil
    end
    AUTO_SELL._busy = false
end
local AUTO_FAIRY = {
    enabled = false,
    _task = nil,
    _busy = false,
    checkInterval = 5,
}
local AUTO_SHOP = {
    enabled = false,
    _task = nil,
    _busy = false,
    checkInterval = 10,
    availableSeeds = {},
    selectedSeeds = {},
    buyAll = false,
    modeSelected = false,
    modeAll = false,
    stockFetcher = nil,
    currentStock = {},
    buyDelay = 0.05,
    maxSpamPerSeed = 250,
    maxConcurrent = 12,
    maxConcurrentGlobal = 32,
    logBuys = false,
    _inFlightGlobal = 0
}
local AUTO_GEAR = {
    enabled = false,
    _task = nil,
    _busy = false,
    checkInterval = 10,
    availableGear = {},
    selectedGear = {},
    buyAll = false,
    modeSelected = false,
    modeAll = false,
    stockFetcher = nil,
    currentStock = {},
    buyDelay = 0.05,
    maxSpamPerItem = 100,
    maxConcurrent = 8,
    maxConcurrentGlobal = 24,
    logBuys = false,
    _inFlightGlobal = 0
}
local function getGlimmeringPlantNames()
    local glimmeringPlants = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return glimmeringPlants end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local itemName = string.lower(item.Name)
            local isPlant = false
            if item:GetAttribute("PlantType") or item:GetAttribute("CropType") or item:GetAttribute("SeedType") then
                isPlant = true
            end
            local plantKeywords = {"tomato", "carrot", "potato", "corn", "wheat", "apple", "orange", "grape", "strawberry", "berry", "seed", "flower", "fruit", "vegetable", "crop"}
            for _, keyword in ipairs(plantKeywords) do
                if string.find(itemName, keyword) then
                    isPlant = true
                    break
                end
            end
            if string.match(itemName, "%[.+%]%s*%w") then
                local afterBrackets = string.match(itemName, "%[.+%]%s*(.+)")
                if afterBrackets then
                    local toolWords = {"sword", "axe", "pickaxe", "shovel", "hammer", "tool", "weapon", "gear", "equipment", "staff", "wand", "bow", "gun"}
                    local isToolName = false
                    for _, toolWord in ipairs(toolWords) do
                        if string.find(afterBrackets, toolWord) then
                            isToolName = true
                            break
                        end
                    end
                    if not isToolName then
                        isPlant = true
                    end
                end
            end
            if isPlant then
                local hasGlimmering = false
                if item:GetAttribute("Glimmering") == true then
                    hasGlimmering = true
                elseif string.find(itemName, "glimmering") then
                    hasGlimmering = true
                else
                    local allAttrs = item:GetAttributes()
                    for attrName, attrValue in pairs(allAttrs) do
                        if type(attrValue) == "string" then
                            local lowerAttr = string.lower(attrValue)
                            if string.find(lowerAttr, "glimmering") then
                                hasGlimmering = true
                                break
                            end
                        end
                    end
                end
                if hasGlimmering then
                    table.insert(glimmeringPlants, item.Name)
                end
            end
        end
    end
    return glimmeringPlants
end
local function hasGlimmeringInBackpack()
    local glimmeringPlants = getGlimmeringPlantNames()
    if #glimmeringPlants > 0 then
        return true
    else
        print("� NO GLIMMERING PLANTS FOUND")
    end
    print("=== BACKPACK CHECK END ===")
    return false
end
local function submitToFairyFountain()
    if AUTO_FAIRY._busy then
        return false
    end
    AUTO_FAIRY._busy = true
    local success = pcall(function()
        local fairyRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("FairyService"):WaitForChild("SubmitFairyFountainAllPlants")
        fairyRemote:FireServer()
    end)
    if success then
        writefile("FairyDebug.txt", "\n[" .. os.date("%X") .. "] Submitted to fairy")
    end
    AUTO_FAIRY._busy = false
    return success
end
local function startAutoFairy(toast)
    if AUTO_FAIRY.enabled then
        return
    end
    AUTO_FAIRY.enabled = true
    AUTO_FAIRY.lastSubmitted = false
    if toast then toast("Auto-Fairy ON - will submit when glimmering plant detected in backpack") end
    AUTO_FAIRY._task = task.spawn(function()
        local loopCount = 0
        while AUTO_FAIRY.enabled do
            local hasGlimmering = hasGlimmeringInBackpack()
            if hasGlimmering then
                if not AUTO_FAIRY.lastSubmitted then
                    local currentGlimmeringPlants = getGlimmeringPlantNames()
                    local hasNewPlants = false
                    local newPlants = {}
                    for _, plantName in ipairs(currentGlimmeringPlants) do
                        local alreadySubmitted = false
                        for _, submittedPlant in ipairs(AUTO_FAIRY.submittedPlants or {}) do
                            if submittedPlant == plantName then
                                alreadySubmitted = true
                                break
                            end
                        end
                        if not alreadySubmitted then
                            hasNewPlants = true
                            table.insert(newPlants, plantName)
                        end
                    end
                    if hasNewPlants then
                        local submissionSuccess = submitToFairyFountain()
                        if submissionSuccess then
                            if toast then toast("Submitted to fairy fountain!") end
                            if not AUTO_FAIRY.submittedPlants then AUTO_FAIRY.submittedPlants = {} end
                            for _, plantName in ipairs(currentGlimmeringPlants) do
                                table.insert(AUTO_FAIRY.submittedPlants, plantName)
                            end
                        end
                    end
                else
                    print("� GLIMMERING STILL PRESENT - already submitted, waiting for backpack to clear")
                end
            else
                print("� NO GLIMMERING PLANTS - clearing submitted plant list")
                AUTO_FAIRY.submittedPlants = {}
            end
            task.wait(AUTO_FAIRY.checkInterval)
        end
    end)
end
local function stopAutoFairy(toast)
    AUTO_FAIRY.enabled = false
    AUTO_FAIRY.submittedPlants = {}
    AUTO_FAIRY.lastSubmitted = false
    AUTO_FAIRY._busy = false
    if AUTO_FAIRY._task then
        task.cancel(AUTO_FAIRY._task)
        AUTO_FAIRY._task = nil
    end
    if toast then toast("Auto-Fairy OFF") end
end
local function buySeed(seedKey)
    while AUTO_SHOP._inFlightGlobal >= (AUTO_SHOP.maxConcurrentGlobal or 32) and AUTO_SHOP.enabled do
        task.wait(AUTO_SHOP.buyDelay or 0.05)
    end
    AUTO_SHOP._inFlightGlobal = _inFlightGlobal + 1
    local ok = pcall(function()
        local ge = ReplicatedStorage:WaitForChild("GameEvents")
        ge:WaitForChild("BuySeedStock"):FireServer("Tier 1", seedKey)
    end)
    AUTO_SHOP._inFlightGlobal = math.max(0, AUTO_SHOP._inFlightGlobal - 1)
    if AUTO_SHOP.logBuys then
        local line = (ok and "Bought" or "Failed") .. " (Tier 1) " .. tostring(seedKey)
        pcall(writefile, "ShopDebug.txt", "\n[" .. os.date("%X") .. "] " .. line)
    end
    return ok
end
local function _findSeedStockFetcher()
    local ge = ReplicatedStorage:FindFirstChild("GameEvents")
    if not ge then return nil end
    local best
    for _, d in ipairs(ge:GetDescendants()) do
        if d:IsA("RemoteFunction") then
            local nm = string.lower(d.Name)
            if (nm:find("stock") and (nm:find("seed") or nm:find("shop"))) or nm:find("getseedstock") or nm:find("getshopstock") then
                best = d; break
            end
        end
    end
    return best
end
local function _parseStockTable(res)
    local out = {}
    if type(res) ~= "table" then return out end
    local isArray = (#res > 0)
    if isArray then
        for _, item in ipairs(res) do
            if type(item) == "table" then
                local name = item.key or item.Key or item.name or item.Name or item.seed or item.Seed
                local count = item.stock or item.Stock or item.left or item.Left or item.amount or item.Amount or item.count or item.Count
                if typeof(name) == "string" and typeof(count) == "number" then
                    out[name] = count
                end
            end
        end
    else
        for k, v in pairs(res) do
            if typeof(k) == "string" then
                if typeof(v) == "number" then
                    out[k] = v
                elseif type(v) == "table" then
                    local count = v.stock or v.Stock or v.left or v.Left or v.amount or v.Amount or v.count or v.Count
                    if typeof(count) == "number" then out[k] = count end
                end
            end
        end
    end
    return out
end
local function buyGear(gearKey)
    while AUTO_GEAR._inFlightGlobal >= (AUTO_GEAR.maxConcurrentGlobal or 24) and AUTO_GEAR.enabled do
        task.wait(AUTO_GEAR.buyDelay or 0.05)
    end
    AUTO_GEAR._inFlightGlobal = _inFlightGlobal + 1
    local ok = pcall(function()
    local ge = ReplicatedStorage:WaitForChild("GameEvents")
    ge:WaitForChild("BuyGearStock"):FireServer(gearKey)
    end)
    AUTO_GEAR._inFlightGlobal = math.max(0, AUTO_GEAR._inFlightGlobal - 1)
    if AUTO_GEAR.logBuys then
        local line = (ok and "Bought" or "Failed") .. " Gear " .. tostring(gearKey)
        pcall(writefile, "GearShopDebug.txt", "\n[" .. os.date("%X") .. "] " .. line)
    end
    return ok
end
local function _findGearStockFetcher()
    local ge = ReplicatedStorage:FindFirstChild("GameEvents")
    if not ge then return nil end
    for _, d in ipairs(ge:GetDescendants()) do
        if d:IsA("RemoteFunction") then
            local nm = string.lower(d.Name)
            if (nm:find("stock") and (nm:find("gear") or nm:find("shop"))) or nm:find("getgearstock") or nm:find("getshopstock") then
                return d
            end
        end
    end
    return nil
end
local function _parseGearStock(res)
    local out = {}
    if type(res) ~= "table" then return out end
    if #res > 0 then
        for _, it in ipairs(res) do
            if type(it) == "table" then
                local name = it.key or it.Key or it.name or it.Name or it.item or it.Item or it.GearName
                local count = it.stock or it.Stock or it.left or it.Left or it.amount or it.Amount or it.count or it.Count
                if typeof(name) == "string" and typeof(count) == "number" then out[name] = count end
            end
        end
    else
        for k, v in pairs(res) do
            if typeof(k) == "string" then
                if typeof(v) == "number" then out[k] = v
                elseif type(v) == "table" then
                    local count = v.stock or v.Stock or v.left or v.Left or v.amount or v.Amount or v.count or v.Count
                    if typeof(count) == "number" then out[k] = count end
                end
            end
        end
    end
    return out
end
local function _loadGearData()
    AUTO_GEAR.availableGear = {}
    local success, gearData = pcall(function()
        return require(ReplicatedStorage.Data.GearData)
    end)
    if success and type(gearData) == "table" then
        for key, info in pairs(gearData) do
            if info.DisplayInShop then
                table.insert(AUTO_GEAR.availableGear, {
                    key = key,
                    name = info.GearName or key,
                    price = info.Price or info.FallbackPrice or 0,
                    layoutOrder = info.LayoutOrder or 999,
                    displayName = info.GearName or key,
                    selected = false
                })
            end
        end
        table.sort(AUTO_GEAR.availableGear, function(a,b)
            if a.layoutOrder == b.layoutOrder then return a.name < b.name else return a.layoutOrder < b.layoutOrder end
        end)
    else
        AUTO_GEAR.availableGear = {
            {key="Watering Can", name="Watering Can", price=50000, layoutOrder=10, displayName="Watering Can"},
            {key="Trowel", name="Trowel", price=100000, layoutOrder=20, displayName="Trowel"},
            {key="Basic Sprinkler", name="Basic Sprinkler", price=25000, layoutOrder=40, displayName="Basic Sprinkler"},
        }
    end
    return AUTO_GEAR.availableGear
end
local function _buyGearUntilSoldOut(gearKey, price)
    local moneyVal = _getCurrencyValueInstance and _getCurrencyValueInstance() or nil
    local getMoney = function() return (moneyVal and moneyVal.Value) or 0 end
    local start = getMoney()
    local attempts, spent, bought = 0, 0, 0
    local delay = AUTO_GEAR.buyDelay or 0.05
    local cap = AUTO_GEAR.maxSpamPerItem or 100
    local failsInRow = 0
    while AUTO_GEAR.enabled and attempts < cap do
        attempts = attempts + 1
        local before = getMoney()
        buyGear(gearKey)
        task.wait(delay)
        local after = getMoney()
        local delta = before - after
        if price and price > 0 and delta >= price * 0.9 then
            spent = spent + delta; bought = bought + 1; failsInRow = 0
        else
            failsInRow = failsInRow + 1
            if failsInRow >= 4 then break end
            task.wait(math.min(0.25 * failsInRow, 1.0))
        end
    end
    return bought
end
local function _burstBuyGear(gearKey, count)
    local inFlight = 0
    local maxC = math.max(1, AUTO_GEAR.maxConcurrent or 6)
    local delay = AUTO_GEAR.buyDelay or 0.05
    local i = 0
    while AUTO_GEAR.enabled and i < count do
        while inFlight < maxC and i < count do
            i = i + 1
            inFlight = inFlight + 1
            task.spawn(function()
                buyGear(gearKey)
                task.wait(delay)
                inFlight = inFlight - 1
            end)
        end
        task.wait(delay)
    end
    while inFlight > 0 do task.wait(delay) end
end
local function _runForGearParallel(items, fn)
    local pending = 0
    local delay = AUTO_GEAR.buyDelay or 0.05
    for _, it in ipairs(items) do
        if not AUTO_GEAR.enabled then break end
        while AUTO_GEAR._inFlightGlobal >= (AUTO_GEAR.maxConcurrentGlobal or 24) and AUTO_GEAR.enabled do
            task.wait(delay)
        end
        pending = pending + 1
        task.spawn(function()
            pcall(fn, it)
            pending = pending - 1
        end)
        task.wait(delay * 0.2)
    end
    while pending > 0 do task.wait(delay) end
end
local function _detectGearStock()
    if not AUTO_GEAR.stockFetcher then AUTO_GEAR.stockFetcher = _findGearStockFetcher() end
    local fetcher = AUTO_GEAR.stockFetcher
    if fetcher then
        local ok, res = pcall(function() return fetcher:InvokeServer() end)
        if ok and type(res) == "table" then
            local map = _parseGearStock(res)
            if next(map) ~= nil then AUTO_GEAR.currentStock = map; return true end
        end
        local ok2, res2 = pcall(function() return fetcher:InvokeServer("Shop") end)
        if ok2 and type(res2) == "table" then
            local map2 = _parseGearStock(res2); if next(map2) ~= nil then AUTO_GEAR.currentStock = map2; return true end
        end
    end
    return false
end
local function _waitForGearRefresh(targetKeys)
    local fetcher = AUTO_GEAR.stockFetcher or _findGearStockFetcher()
    if fetcher then
        while AUTO_GEAR.enabled do
            local ok, res = pcall(function() return fetcher:InvokeServer() end)
            if ok and type(res) == "table" then
                local map = _parseGearStock(res)
                if next(map) ~= nil then
                    if targetKeys and #targetKeys > 0 then
                        for _, k in ipairs(targetKeys) do
                            if k and (map[k] or map[string.gsub(k, " Gear", "")]) and (map[k] or 0) > 0 then
                                AUTO_GEAR.currentStock = map; return
                            end
                        end
                    else
                        AUTO_GEAR.currentStock = map; return
                    end
                end
            end
            task.wait(5)
        end
    else
        task.wait(30)
    end
end
local function startAutoGear(toast)
    if AUTO_GEAR.enabled then return end
    AUTO_GEAR.enabled = true
    if toast then toast("Auto-Gear ON - tracking stock and buying out selections") end
    if #AUTO_GEAR.availableGear == 0 then _loadGearData() end
    AUTO_GEAR._task = task.spawn(function()
        while AUTO_GEAR.enabled do
            if not AUTO_GEAR._busy then
                AUTO_GEAR._busy = true
                local haveStock = _detectGearStock()
                local itemsToBuy = AUTO_GEAR.buyAll and AUTO_GEAR.availableGear or AUTO_GEAR.selectedGear
                if #itemsToBuy > 0 then
                    _runForGearParallel(itemsToBuy, function(it)
                        if not AUTO_GEAR.enabled then return end
                        local key = it.key or it.name or it.displayName; if not key then return end
                        local wanted = 0
                        if haveStock and AUTO_GEAR.currentStock then
                            local variants = { key, it.displayName, it.name }
                            for _, v in ipairs(variants) do if v and AUTO_GEAR.currentStock[v] then wanted = AUTO_GEAR.currentStock[v]; break end end
                        end
                        if wanted and wanted > 0 then
                            _burstBuyGear(key, wanted)
                        else
                            if it.price and it.price > 0 then
                                _burstBuyGear(key, (AUTO_GEAR.maxConcurrent or 8) * 6)
                                _buyGearUntilSoldOut(key, it.price)
                            else
                                _burstBuyGear(key, math.min(AUTO_GEAR.maxSpamPerItem or 100, 60))
                            end
                        end
                    end)
                end
                AUTO_GEAR._busy = false
            end
            local targetKeys = {}
            local itemsToBuy = AUTO_GEAR.buyAll and AUTO_GEAR.availableGear or AUTO_GEAR.selectedGear
            for _, it in ipairs(itemsToBuy) do table.insert(targetKeys, it.key or it.name or it.displayName) end
            _waitForGearRefresh(targetKeys)
        end
    end)
end
local function stopAutoGear(toast)
    AUTO_GEAR.enabled = false; AUTO_GEAR._busy = false
    if AUTO_GEAR._task then task.cancel(AUTO_GEAR._task); AUTO_GEAR._task=nil end
    if toast then toast("Auto-Gear OFF") end
end
local function _normalizeSeedName(n)
    n = tostring(n or ""):gsub("%s+Seeds$", "")
    return (n:lower())
end
local function _findShopRoot()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local shop = pg:FindFirstChild("Seed_Shop")
    if not shop then return nil end
    local frame = shop:FindFirstChild("Frame")
    local sc = frame and frame:FindFirstChild("ScrollingFrame")
    return sc
end
local function _findItemRow(seedName)
    local sc = _findShopRoot()
    if not sc then return nil end
    local want = _normalizeSeedName(seedName)
    for _, fr in ipairs(sc:GetChildren()) do
        if fr:IsA("Frame") then
            local foundName
            for _, d in ipairs(fr:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Text ~= "" then
                    local txt = tostring(d.Text)
                    if (txt:find("%a")) and not txt:find("%d+/%d+") and not txt:find("%d+¢") and not txt:lower():find("stock:") then
                        local norm = _normalizeSeedName(txt)
                        if norm == want then foundName = true; break end
                    end
                end
            end
            if foundName then return fr end
        end
    end
    return nil
end
local function _readRowStock(row)
    if not row then return nil end
    local best
    for _, d in ipairs(row:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Text ~= "" then
            local t = tostring(d.Text)
            local tl = t:lower()
            if not tl:find("¢") and not tl:find("$") then
                local n = tonumber(tl:match("x%s*(%d+)") or tl:match("(%d+)%s*left") or tl:match("stock%s*:%s*(%d+)") or tl:match("^%s*(%d+)%s*$"))
                if n then best = n; break end
            end
        end
    end
    return best
end
function AUTO_SHOP._detectStock()
    if not AUTO_SHOP.stockFetcher then AUTO_SHOP.stockFetcher = _findSeedStockFetcher() end
    local fetcher = AUTO_SHOP.stockFetcher
    if fetcher then
        local ok, res = pcall(function() return fetcher:InvokeServer() end)
        if ok and type(res) == "table" then
            local map = _parseStockTable(res)
            if next(map) ~= nil then
                AUTO_SHOP.currentStock = map
                return true
            end
        end
        local ok2, res2 = pcall(function() return fetcher:InvokeServer("Tier 1") end)
        if ok2 and type(res2) == "table" then
            local map2 = _parseStockTable(res2)
            if next(map2) ~= nil then
                AUTO_SHOP.currentStock = map2
                return true
            end
        end
    end
    local sc = _findShopRoot()
    if sc then
        local uiMap = {}
        for _, fr in ipairs(sc:GetChildren()) do
            if fr:IsA("Frame") then
                local nameText
                for _, d in ipairs(fr:GetDescendants()) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Text ~= "" then
                        local txt = tostring(d.Text)
                        if (txt:find("%a")) and not txt:find("%d+/%d+") and not txt:find("%d+¢") and not txt:lower():find("stock:") then
                            nameText = txt
                            break
                        end
                    end
                end
                local stock = _readRowStock(fr)
                if nameText and stock then
                    uiMap[nameText] = stock
                    uiMap[string.gsub(nameText, " Seeds", "")] = stock
                end
            end
        end
        if next(uiMap) ~= nil then
            AUTO_SHOP.currentStock = uiMap
            return true
        end
    end
    return false
end
local function _getCurrencyValueInstance()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    local candidates = {"coins","coin","money","cash","tokens","gold"}
    local best
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("DoubleConstrainedValue") or v:IsA("NumberSequence") then
            local name = string.lower(v.Name)
            for _, c in ipairs(candidates) do if name:find(c) then best = v; break end end
            if best then break end
        end
    end
    if not best then
        for _, v in ipairs(ls:GetChildren()) do
            if v.Value ~= nil then best = v; break end
        end
    end
    return best
end
local function _buyUntilSoldOut(seedKey, price)
    local attempts, bought = 0, 0
    local moneyVal = _getCurrencyValueInstance()
    local lastMoney = moneyVal and moneyVal.Value or nil
    local failsInRow = 0
    local delay = AUTO_SHOP.buyDelay or 0.4
    local cap = AUTO_SHOP.maxSpamPerSeed or 250
    while AUTO_SHOP.enabled and attempts < cap do
        attempts = attempts + 1
        buySeed(seedKey)
        task.wait(delay)
        if moneyVal and typeof(price) == "number" and price > 0 then
            local now = moneyVal.Value
            local spent = lastMoney and (lastMoney - now) or 0
            if spent >= price * 0.9 then
                bought = bought + 1
                lastMoney = now
                failsInRow = 0
                task.wait(delay)
            else
                failsInRow = failsInRow + 1
                if failsInRow >= 4 then break end
                task.wait(math.min(0.25 * failsInRow, 1.0))
            end
        else
            if attempts % 10 == 0 then task.wait(0.5) end
        end
    end
    return bought
end
local function _burstBuy(seedKey, count)
    local inFlight = 0
    local maxC = math.max(1, AUTO_SHOP.maxConcurrent or 6)
    local delay = AUTO_SHOP.buyDelay or 0.05
    local i = 0
    while AUTO_SHOP.enabled and i < count do
        while inFlight < maxC and i < count do
            i = i + 1
            inFlight = inFlight + 1
            task.spawn(function()
                buySeed(seedKey)
                task.wait(delay)
                inFlight = inFlight - 1
            end)
        end
        task.wait(delay)
    end
    while inFlight > 0 do task.wait(delay) end
end
local function _runForSeedsParallel(seeds, fn)
    local pending = 0
    local delay = AUTO_SHOP.buyDelay or 0.05
    for _, sd in ipairs(seeds) do
        if not AUTO_SHOP.enabled then break end
        while AUTO_SHOP._inFlightGlobal >= (AUTO_SHOP.maxConcurrentGlobal or 32) and AUTO_SHOP.enabled do
            task.wait(delay)
        end
        pending = pending + 1
        task.spawn(function()
            pcall(fn, sd)
            pending = pending - 1
        end)
        task.wait(delay * 0.2)
    end
    while pending > 0 do task.wait(delay) end
end
local function _waitForRefresh(targetKeys)
    local fetcher = AUTO_SHOP.stockFetcher or _findSeedStockFetcher()
    if fetcher then
        while AUTO_SHOP.enabled do
            local ok, res = pcall(function() return fetcher:InvokeServer() end)
            if ok and type(res) == "table" then
                local map = _parseStockTable(res)
                if next(map) ~= nil then
                    if targetKeys and #targetKeys > 0 then
                        for _, k in ipairs(targetKeys) do
                            local key = k
                            if type(k) == "table" then key = k.key or k.name or k.displayName end
                            if key and (map[key] or map[string.gsub(key, " Seeds", "")]) and (map[key] or 0) > 0 then
                                AUTO_SHOP.currentStock = map
                                return
                            end
                        end
                    else
                        AUTO_SHOP.currentStock = map
                        return
                    end
                end
            end
            task.wait(5)
        end
    else
        local deadline = os.clock() + 300
        while AUTO_SHOP.enabled and os.clock() < deadline do
            if targetKeys and #targetKeys > 0 then
                for _, k in ipairs(targetKeys) do
                    local key = type(k) == "table" and (k.key or k.name or k.displayName) or k
                    if key then
                        local row = _findItemRow(key)
                        local st = row and _readRowStock(row)
                        if st and st > 0 then return end
                    end
                end
            end
            task.wait(5)
        end
    end
end
local function startAutoShop(toast)
    if AUTO_SHOP.enabled then
        return
    end
    AUTO_SHOP.enabled = true
    if toast then toast("Auto-Shop ON - tracking stock and buying out selections") end
    AUTO_SHOP._task = task.spawn(function()
        while AUTO_SHOP.enabled do
            if not AUTO_SHOP._busy then
                AUTO_SHOP._busy = true
                local haveStock = AUTO_SHOP._detectStock()
                local seedsToBuy = AUTO_SHOP.buyAll and AUTO_SHOP.availableSeeds or AUTO_SHOP.selectedSeeds
                if #seedsToBuy > 0 then
                    _runForSeedsParallel(seedsToBuy, function(seedData)
                        if not AUTO_SHOP.enabled then return end
                        local key = seedData.key or seedData.name or seedData.displayName
                        if not key then return end
                        local wanted = 0
                        if haveStock and AUTO_SHOP.currentStock then
                            local variants = { key, string.gsub(key, " Seeds", ""), seedData.displayName, seedData.name }
                            for _, v in ipairs(variants) do
                                if v and AUTO_SHOP.currentStock[v] then wanted = AUTO_SHOP.currentStock[v]; break end
                            end
                        end
                        if wanted and wanted > 0 then
                            _burstBuy(key, wanted)
                        else
                            if seedData.price and seedData.price > 0 then
                                _burstBuy(key, AUTO_SHOP.maxConcurrent * 8)
                                _buyUntilSoldOut(key, seedData.price)
                            else
                                local cap = math.min(AUTO_SHOP.maxSpamPerSeed, 100)
                                _burstBuy(key, cap)
                            end
                        end
                    end)
                end
                AUTO_SHOP._busy = false
            end
            local targetKeys = {}
            local seedsToBuy = AUTO_SHOP.buyAll and AUTO_SHOP.availableSeeds or AUTO_SHOP.selectedSeeds
            for _, sd in ipairs(seedsToBuy) do table.insert(targetKeys, sd.key or sd.name or sd.displayName) end
            _waitForRefresh(targetKeys)
        end
    end)
end
local function stopAutoShop(toast)
    AUTO_SHOP.enabled = false
    AUTO_SHOP._busy = false
    if AUTO_SHOP._task then
        task.cancel(AUTO_SHOP._task)
        AUTO_SHOP._task = nil
    end
    if toast then toast("Auto-Shop OFF") end
end
local function getOwnedReadyPlants()
    local out = {}
    for _, m in ipairs(getAllPlants()) do
        if ownsPlant(LocalPlayer, m) and isPlantReady(m) and hasWantedMutation(m) then
            table.insert(out, m)
        end
    end
    return out
end
local function collectWirelessOnce()
    if not AUTO.enabled then return 0 end
    local used, sent = harvestViaCropsRemote()
    if used and sent > 0 then return sent end
    local n = 0
    for _, plant in ipairs(getOwnedReadyPlants()) do
        if not AUTO.enabled then break end
        if tryRemotesForPlant(plant, LocalPlayer) or tryExploitHelpers(plant) then
            n = n + 1
        end
        task.wait(AUTO.fireDelay)
    end
    return n
end
local function moveNear(plant)
    local hrp = (Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
    local pivot = (plant.GetPivot and plant:GetPivot()) or plant.PrimaryPart and plant.PrimaryPart.CFrame or plant.CFrame or CFrame.new()
    local dest  = pivot * CFrame.new(0, 3, -3)
    local dist  = (hrp.Position - dest.Position).Magnitude
    local dur   = math.clamp((dist / 100) * math.max(0.05, AUTO.tweenSpeed), 0.05, 2.5)
    local tw = TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = dest})
    tw:Play(); task.wait(dur + 0.02)
end
local function collectCFramingOnce()
    if not AUTO.enabled then return 0 end
    local n = 0
    for _, plant in ipairs(getOwnedReadyPlants()) do
        if not AUTO.enabled then break end
        moveNear(plant)
        if not AUTO.enabled then break end
        if tryExploitHelpers(plant) or tryRemotesForPlant(plant, LocalPlayer) then
            n = n + 1
        end
        task.wait(AUTO.fireDelay)
    end
    return n
end
local function runHarvestOnce()
    if not AUTO.enabled then return 0 end
    if AUTO.method == "CFraming" then
        return collectCFramingOnce()
    elseif AUTO.method == "Wireless" then
        return collectWirelessOnce()
    else
        return 0
    end
end
local function AutoStart(toast)
    if AUTO._task then return end
    AUTO.enabled = true
    if toast then toast(("Auto-collect ON (%s)"):format(AUTO.method)) end
    AUTO._task = task.spawn(function()
        while AUTO.enabled do
            if not AUTO._busy and AUTO.enabled then
                AUTO._busy = true
                local success, result = pcall(runHarvestOnce)
                if not success then
                    warn("Harvest error:", result)
                end
                AUTO._busy = false
                if AUTO.enabled then
                    task.wait()
                end
            end
            local totalWait = math.max(1.0, AUTO.interval)
            local chunks = math.ceil(totalWait / 0.25)
            for i = 1, chunks do
                if not AUTO.enabled then break end
                task.wait(totalWait / chunks)
            end
        end
        AUTO._task = nil
    end)
end
local function AutoStop(toast)
    AUTO.enabled = false
    if toast then toast("Auto-collect OFF") end
    if AUTO._task then
        AUTO._task = nil
    end
    AUTO._busy = false
end
_G.HarvestControl = {
    SetEnabled = function(on, toast) if on then AutoStart(toast) else AutoStop(toast) end end,
    SetMethod  = function(m) AUTO.method  = (m == "CFraming" and "CFraming") or (m == "Wireless" and "Wireless") or "None" end,
    SetInterval= function(s) AUTO.interval = tonumber(s) or AUTO.interval end,
    SetFireDelay=function(s) AUTO.fireDelay = tonumber(s) or AUTO.fireDelay end,
    SetTweenSpeed=function(s) AUTO.tweenSpeed = tonumber(s) or AUTO.tweenSpeed end,
    SetDebugMode=function(on)
        DEBUG_MODE = on and true or false
        AUTO.debugMode = DEBUG_MODE
    end,
    RunOnce    = function() return runHarvestOnce() end,
}
local SPEED={MIN=8,MAX=200,Chosen=16,Enabled=false,Default=16}
local InfiniteJump={Enabled=false}
local NoClip={Enabled=false,Conn=nil}
local Fly={Enabled=false,Speed=80,BV=nil,BG=nil,Conn=nil}
local Teleport={Enabled=false,Modifier=Enum.KeyCode.LeftControl}
local JumpConn=nil
local TeleportConn=nil
local CharAddedConn=nil
local function getHumanoid()
    local ch=Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local hum=ch:FindFirstChildOfClass("Humanoid"); if hum then return hum end
    local c; c=ch.ChildAdded:Connect(function(n) if n:IsA("Humanoid") then hum=n; c:Disconnect() end end)
    repeat task.wait() until hum; return hum
end
local function getHRP() local ch=Players.LocalPlayer.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end
local function applySpeedValue(v)
    local hum=(Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")) or getHumanoid()
    if hum then hum.WalkSpeed=v end
end
local function setCustomSpeed(on)
    SPEED.Enabled = on and true or false
    if SPEED.Enabled then
        applySpeedValue(SPEED.Chosen)
    else
        applySpeedValue(SPEED.Default)
    end
end
JumpConn = UserInputService.JumpRequest:Connect(function()
    if InfiniteJump.Enabled then
        local hum=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping); hum.Jump=true end
    end
end)
local function setNoClip(on)
    if on then
        if NoClip.Conn then NoClip.Conn:Disconnect() end
        NoClip.Conn = RunService.Stepped:Connect(function()
            local ch=Players.LocalPlayer.Character; if not ch then return end
            for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
        end)
    else
        if NoClip.Conn then NoClip.Conn:Disconnect(); NoClip.Conn=nil end
    end
    NoClip.Enabled=on
end
local function stopFly()
    Fly.Enabled=false
    if Fly.Conn then Fly.Conn:Disconnect(); Fly.Conn=nil end
    local hrp=getHRP(); if hrp then if Fly.BV then Fly.BV:Destroy() Fly.BV=nil end; if Fly.BG then Fly.BG:Destroy() Fly.BG=nil end end
    local hum=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.PlatformStand=false end
end
local function startFly()
    local hrp=getHRP(); local hum=getHumanoid(); if not hrp or not hum then return end
    stopFly(); Fly.Enabled=true; hum.PlatformStand=true
    local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(1e9,1e9,1e9); bv.Velocity=Vector3.zero; bv.Parent=hrp; Fly.BV=bv
    local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(1e9,1e9,1e9); bg.P=9e4; bg.CFrame=workspace.CurrentCamera.CFrame; bg.Parent=hrp; Fly.BG=bg
    Fly.Conn = RunService.RenderStepped:Connect(function()
        if not Fly.Enabled then return end
        local cam=workspace.CurrentCamera; if not cam then return end
        bg.CFrame=cam.CFrame
        local dir=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0,1,0) end
        if dir.Magnitude>0 then dir=dir.Unit*Fly.Speed end
        bv.Velocity=dir
    end)
end
local function setFly(on) if on then startFly() else stopFly() end end
local mouse=Players.LocalPlayer:GetMouse()
local function pointInside(frame)
    local m=UserInputService:GetMouseLocation(); local p=frame.AbsolutePosition; local s=frame.AbsoluteSize
    return m.X>=p.X and m.X<=p.X+s.X and m.Y>=p.Y and m.Y<=p.Y+s.Y
end
TeleportConn = mouse.Button1Down:Connect(function()
    if not Teleport.Enabled or not UserInputService:IsKeyDown(Teleport.Modifier) then return end
    local gui=CoreGui:FindFirstChild("SpeedStyleUI"); if gui and gui.Enabled then
        local win=gui:FindFirstChild("MainWindow", true); if win and pointInside(win) then return end
    end
    local ch=Players.LocalPlayer.Character; local pos=mouse.Hit and mouse.Hit.p
    if ch and pos then ch:PivotTo(CFrame.new(pos + Vector3.new(0,3,0))) end
end)
local GO = {
    Enabled=false,
    TAG="GrassOverlay_Client",
    COLOR=Color3.fromRGB(72,220,96),
    THICK=0.12,
    MIN_TILE=6,
    GREEN_H_MIN=0.23, GREEN_H_MAX=0.42,
    overlays=setmetatable({}, {__mode="k"}),
    conns=setmetatable({}, {__mode="k"}),
    scanConn=nil, refreshConn=nil
}
local function isCharacterDescendant(inst)
    local m = inst:FindFirstAncestorOfClass("Model")
    return m and m:FindFirstChildOfClass("Humanoid") ~= nil
end
local function isOverlayPart(inst)
    return inst:IsA("BasePart") and (inst.Name==GO.TAG or CollectionService:HasTag(inst, GO.TAG) or inst:GetAttribute("__IsOverlay")==true)
end
local function looksLikeGrass(part)
    if not part:IsA("BasePart") then return false end
    if isCharacterDescendant(part) or part:IsA("Terrain") or isOverlayPart(part) then return false end
    if part.CFrame.UpVector.Y < 0.9 then return false end
    if math.min(part.Size.X, part.Size.Z) < GO.MIN_TILE then return false end
    local name = string.lower(part.Name)
    local byName = string.find(name, "grass") or string.find(name, "lawn") or string.find(name, "turf")
    local byMat  = (part.Material==Enum.Material.Grass) or (part.Material==Enum.Material.Ground)
    local h,s,v = Color3.toHSV(part.Color)
    local greenish = (h>GO.GREEN_H_MIN and h<GO.GREEN_H_MAX and s>0.2 and v>0.2)
    return byName or byMat or greenish
end
local function ensureOverlay(base)
    if not base or not base:IsA("BasePart") or not base.Parent then return end
    if isOverlayPart(base) then return end
    if GO.overlays[base] and GO.overlays[base].Parent then return end
    if not looksLikeGrass(base) then return end
    local ov = Instance.new("Part")
    ov.Name = GO.TAG
    ov:SetAttribute("__IsOverlay", true)
    CollectionService:AddTag(ov, GO.TAG)
    ov.Anchored=true; ov.CanCollide=false; ov.CanQuery=false; ov.CanTouch=false
    ov.Material=Enum.Material.Grass; ov.Color=GO.COLOR; ov.Transparency=0
    ov.CastShadow=false; ov.Locked=true; ov.TopSurface=Enum.SurfaceType.Smooth; ov.BottomSurface=Enum.SurfaceType.Smooth
    local function apply()
        if not base.Parent then return end
        local offset = CFrame.new(0, base.Size.Y/2 + GO.THICK/2 + 0.01, 0)
        ov.CFrame = base.CFrame * offset
        ov.Size = Vector3.new(base.Size.X+0.02, GO.THICK, base.Size.Z+0.02)
    end
    apply()
    ov.Parent = base
    GO.overlays[base] = ov
    if not GO.conns[base] then
        local function sync()
            if ov.Parent==nil or base.Parent==nil then return end
            apply()
        end
        local c1 = base:GetPropertyChangedSignal("CFrame"):Connect(sync)
        local c2 = base:GetPropertyChangedSignal("Size"):Connect(sync)
        local c3 = base:GetPropertyChangedSignal("Parent"):Connect(function()
            if not base.Parent and ov then ov:Destroy() end
        end)
        GO.conns[base] = {c1,c2,c3}
    end
end
local function GO_Start()
    if GO.Enabled then return end
    GO.Enabled=true
    for _,d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and not isOverlayPart(d) then ensureOverlay(d) end
    end
    GO.scanConn = Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") and not isOverlayPart(d) then task.defer(function() ensureOverlay(d) end) end
    end)
    local acc=0
    GO.refreshConn = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc>2 then
            acc=0
            for _,d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("BasePart") and not isOverlayPart(d) then ensureOverlay(d) end
            end
        end
    end)
end
local function GO_Stop()
    if not GO.Enabled then return end
    GO.Enabled=false
    if GO.scanConn then GO.scanConn:Disconnect(); GO.scanConn=nil end
    if GO.refreshConn then GO.refreshConn:Disconnect(); GO.refreshConn=nil end
    for base,ov in pairs(GO.overlays) do pcall(function() ov:Destroy() end); GO.overlays[base]=nil end
    for base,b in pairs(GO.conns) do for _,c in ipairs(b) do pcall(function() c:Disconnect() end) end; GO.conns[base]=nil end
end
local BEACH = {
    USE_SAVED=true,
    SAVED_CF = CFrame.new(164.126, -16.000, -17.034) * CFrame.Angles(0, math.rad(-90.000), 0),
    HEIGHT_ADJUST = 117.0,
    SAND_SEA_SIDE = false,
    SAND_EXTRA_Z  = 0.0,
    WATER_UP      = 2.0,
    WATER_LEFT    = 6.0,
    WATER_EXTRA_Z = 0.0,
    CFG = {
        SandSize   = Vector3.new(220, 2, 130),
        SlopeSize  = Vector3.new(220,12, 38),
        WaterSize  = Vector3.new(260, 6, 240),
        SandColor  = Color3.fromRGB(242,216,158),
        WaterColor = Color3.fromRGB(60,190,255),
        WaterTransparency = 0.45,
        CollideSand = true, CollideSlope=true,
        WaveAmp=1.0, WaveSpeed=0.9, RippleAmp=0.7, RippleSpeed=0.35
    },
    SEAM = { sandIntoSlope=1.5, waterHeight=0.6 },
    folder=nil, parts={sand=nil,slope=nil,water=nil}, baseWaterCF=nil, waveConn=nil, anchorCF=nil
}
local function beachLogCF(cf, tag)
    local p = cf.Position
    local _,ry = cf:ToEulerAnglesYXZ()
    local yaw = math.deg(ry)
    warn(string.format("[Beach] %s at (%.3f, %.3f, %.3f), yaw=%.2f°", tag or "Anchor", p.X,p.Y,p.Z, yaw))
    print(string.format(
        "[Beach] Copy-paste:\nlocal HARDCODED_BEACH_CF = CFrame.new(%.3f, %.3f, %.3f) * CFrame.Angles(0, math.rad(%.3f), 0)",
        p.X, p.Y, p.Z, yaw
    ))
end
local function beachGroundYaw(cf)
    local origin = cf.Position + Vector3.new(0,1000,0)
    local hit = Workspace:Raycast(origin, Vector3.new(0,-3000,0), RaycastParams.new())
    local pos = hit and Vector3.new(cf.X, hit.Position.Y, cf.Z) or cf.Position
    local _,ry = cf:ToEulerAnglesYXZ()
    return CFrame.new(pos) * CFrame.Angles(0, ry, 0)
end
local function beachComputeAnchor()
    local cf = BEACH.USE_SAVED and BEACH.SAVED_CF
        or (LocalPlayer.Character and LocalPlayer.Character:WaitForChild("HumanoidRootPart").CFrame or CFrame.new())
    return beachGroundYaw(cf) * CFrame.new(0, BEACH.HEIGHT_ADJUST, 0)
end
local function beachCleanup()
    if BEACH.waveConn then BEACH.waveConn:Disconnect(); BEACH.waveConn=nil end
    if BEACH.folder then BEACH.folder:Destroy(); BEACH.folder=nil end
    BEACH.parts={sand=nil,slope=nil,water=nil}; BEACH.baseWaterCF=nil; BEACH.anchorCF=nil
end
local function mkPart(name, size, cf, color, material, transp, parent, collide)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored=true; p.CanCollide=collide or false; p.CanQuery=collide or false; p.CanTouch=false
    p.CastShadow=false; p.Material=material; p.Color=color; p.Transparency=transp or 0
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent
    return p
end
local function beachBuild()
    beachCleanup()
    local CFG, SEAM = BEACH.CFG, BEACH.SEAM
    local anchor = beachComputeAnchor(); BEACH.anchorCF = anchor; beachLogCF(anchor, "Anchor")
    local folder = Instance.new("Folder"); folder.Name="ClientBeach_LOCAL"; folder.Parent=Workspace; BEACH.folder=folder
    local slopeCF = anchor * CFrame.new(0, CFG.SlopeSize.Y*0.5, 0)
    local slope = Instance.new("WedgePart")
    slope.Name="Beach_Slope"; slope.Anchored=true; slope.CanCollide=CFG.CollideSlope; slope.CanQuery=CFG.CollideSlope; slope.CanTouch=false
    slope.CastShadow=false; slope.Color=CFG.SandColor; slope.Material=Enum.Material.Sand; slope.Size=CFG.SlopeSize
    slope.CFrame=slopeCF; slope.Parent=folder
    BEACH.parts.slope = slope
    local halfSlopeZ = CFG.SlopeSize.Z*0.5
    local sandZ do
        local halfSandZ = CFG.SandSize.Z*0.5
        local baseZ = halfSlopeZ + halfSandZ - SEAM.sandIntoSlope
        local sign = BEACH.SAND_SEA_SIDE and 1 or -1
        sandZ = sign*baseZ + BEACH.SAND_EXTRA_Z
        local sandCF = anchor * CFrame.new(0, CFG.SandSize.Y*0.5, sandZ)
        BEACH.parts.sand = mkPart("Beach_Sand", CFG.SandSize, sandCF, CFG.SandColor, Enum.Material.Sand, 0, folder, CFG.CollideSand)
    end
    local xLeft = -BEACH.WATER_LEFT
    local yUp   = SEAM.waterHeight + BEACH.WATER_UP
    local zFwd  = sandZ + BEACH.WATER_EXTRA_Z
    local waterCF = anchor * CFrame.new(xLeft, yUp, zFwd)
    BEACH.parts.water = mkPart("Beach_Water", CFG.WaterSize, waterCF, CFG.WaterColor, Enum.Material.Glass, CFG.WaterTransparency, folder, false)
    BEACH.parts.water.Reflectance = 0.03
    BEACH.baseWaterCF = BEACH.parts.water.CFrame
    local t=0
    BEACH.waveConn = RunService.RenderStepped:Connect(function(dt)
        if not BEACH.parts.water or not BEACH.parts.water.Parent then return end
        t = t + dt
        local bob  = math.sin(t * math.pi * 2 * CFG.WaveSpeed) * CFG.WaveAmp
        local tilt = math.sin(t * math.pi * 2 * CFG.RippleSpeed) * math.rad(CFG.RippleAmp)
        BEACH.parts.water.CFrame = BEACH.baseWaterCF * CFrame.new(0, bob, 0) * CFrame.Angles(tilt, 0, 0)
    end)
end
local function execInfiniteYield(toast)
    local url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
    local function try_game_httpget()
        return pcall(function() return game:HttpGet(url) end)
    end
    local function try_httpget_func()
        local httpget = rawget(getfenv() or _G, "httpget") or _G.httpget
        if not httpget then return false, nil end
        return pcall(function() return httpget(url) end)
    end
    local function try_syn_request()
        if not (syn and syn.request) then return false, nil end
        return pcall(function()
            local r = syn.request({Url=url, Method="GET"})
            return r and r.Body or ""
        end)
    end
    local ok, src = try_game_httpget()
    if not ok or not src or #src==0 then ok, src = try_httpget_func() end
    if not ok or not src or #src==0 then ok, src = try_syn_request() end
    if not ok or not src or #src==0 then
        if toast then toast("Infinite Yield: failed to download") end
        warn("[IY] Download failed.")
        return
    end
    local fn, ferr = loadstring(src)
    if not fn then
        if toast then toast("Infinite Yield: loadstring error") end
        warn("[IY] loadstring error: ".. tostring(ferr))
        return
    end
    local okrun, err2 = pcall(fn)
    if okrun then
        if toast then toast("Infinite Yield loaded") end
    else
        if toast then toast("Infinite Yield: runtime error") end
        warn("[IY] runtime error: ".. tostring(err2))
    end
end
local function createLoadingScreen(onComplete)
    local gui=mk("ScreenGui",{Name="PlaceholderUI_Loading",IgnoreGuiInset=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Global},CoreGui)
    local bg =mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=THEME.BG1,BackgroundTransparency=1},gui)
    local grid=mk("ImageLabel",{Image="rbxassetid://285329487",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.new(0,50,0,50),Size=UDim2.fromScale(2,2),Position=UDim2.fromScale(-0.5,-0.5),ImageTransparency=0.9,BackgroundTransparency=1},bg)
    TweenService:Create(grid,TweenInfo.new(24,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,-1),{Position=UDim2.fromScale(0.5,0.5)}):Play()
    local title=mk("TextLabel",{Size=UDim2.new(1,0,0,44),Position=UDim2.new(0.5,0,0.35,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Font=FONTS.HB,Text="GAG Hub",TextColor3=THEME.TEXT,TextSize=40,TextTransparency=1},bg)
    local barBG=mk("Frame",{Size=UDim2.new(0.3,0,0,8),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=THEME.BG3,BackgroundTransparency=1},bg) corner(barBG,100)
    local bar =mk("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=THEME.ACCENT},barBG) corner(bar,100)
    local status=mk("TextLabel",{Size=UDim2.new(1,0,0,24),Position=UDim2.new(0.5,0,0.5,24),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Font=FONTS.B,TextColor3=THEME.MUTED,TextSize=16,TextTransparency=1},bg)
    coroutine.wrap(function()
        TweenService:Create(bg,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
        TweenService:Create(title,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
        task.wait(.45); TweenService:Create(barBG,TweenInfo.new(.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
        TweenService:Create(status,TweenInfo.new(.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
        local steps={{"Initializing...",.5},{"Loading assets...",.55},{"Building layout...",.65},{"Finalizing...",.5}}
        for i,s in ipairs(steps) do status.Text=s[1]; TweenService:Create(bar,TweenInfo.new(.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(i/#steps,0,1,0)}):Play(); task.wait(s[2]) end
        task.wait(.25); TweenService:Create(bg,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play()
        task.wait(.35); gui:Destroy(); onComplete()
    end)()
end
local function makeToaster(rootGui)
    local overlay = mk("Frame", {Name="ToastOverlay", BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=1000}, rootGui)
    overlay.ClipsDescendants = false
    local stack = mk("Frame", {BackgroundTransparency=1, Size=UDim2.new(0, 420, 1, 0), Position=UDim2.new(0.5, -210, 0, 10), AnchorPoint=Vector2.new(0,0), ZIndex=1001}, overlay)
    local lay = Instance.new("UIListLayout", stack)
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    lay.VerticalAlignment   = Enum.VerticalAlignment.Top
    lay.Padding             = UDim.new(0, 6)
    local function toast(text)
        local f = mk("Frame", {Size=UDim2.new(1, 0, 0, 40), BackgroundColor3=THEME.BG2, ZIndex=1002}, stack)
        corner(f, 8); stroke(f,1,THEME.BORDER); pad(f,8,12,8,12)
        local t = mk("TextLabel", {BackgroundTransparency=1, Font=FONTS.H, Text=text, TextSize=14, TextColor3=THEME.TEXT, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,1,0), ZIndex=1003}, f)
        f.BackgroundTransparency = 1; t.TextTransparency = 1
        TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=0}):Play()
        TweenService:Create(t, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency=0}):Play()
        task.delay(2.0, function()
            TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1}):Play()
            TweenService:Create(t, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency=1}):Play()
            task.wait(0.4); f:Destroy()
        end)
    end
    return toast
end
local function makeToggle(parent,text,subtext,default,onChanged,toast)
    local row=mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,50)},parent)
    corner(row,8); stroke(row,1,THEME.BORDER); pad(row,8,12,8,12)
    local left=mk("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,-80,1,0)},row)
    local t=mk("TextLabel",{BackgroundTransparency=1,Font=FONTS.H,Text=text,TextSize=15,TextColor3=THEME.TEXT,TextXAlignment=Enum.TextXAlignment.Left},left)
    t.Size=UDim2.new(1,0,0,18)
    if subtext and #subtext>0 then
        mk("TextLabel",{BackgroundTransparency=1,Font=FONTS.B,Text=subtext,TextSize=12,TextColor3=THEME.MUTED,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,0,18)},left)
    end
    local sw=mk("TextButton",{AutoButtonColor=false,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.new(0,52,0,24),BackgroundColor3=THEME.BG2,Text=""},row)
    corner(sw,12); stroke(sw,1,THEME.BORDER)
    local knob=mk("Frame",{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0,3,0,3),BackgroundColor3=THEME.MUTED},sw); corner(knob,9)
    local state= default and true or false
    local function render()
        if state then
            TweenService:Create(sw,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=THEME.ACCENT}):Play()
            TweenService:Create(knob,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(1,-21,0,3),BackgroundColor3=Color3.new(1,1,1)}):Play()
        else
            TweenService:Create(sw,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=THEME.BG2}):Play()
            TweenService:Create(knob,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,3,0,3),BackgroundColor3=THEME.MUTED}):Play()
        end
    end
    sw.MouseButton1Click:Connect(function() state=not state; render(); if onChanged then task.spawn(onChanged,state) end; if toast then toast(text..": "..(state and "ON" or "OFF")) end end)
    render(); hover(row,{BackgroundColor3=THEME.BG2},{BackgroundColor3=THEME.CARD})
    return {Set=function(v) state=v; render() end, Get=function() return state end, Instance=row}
end
local function groupBox(parent, title)
    local box = mk("Frame", {BackgroundColor3=THEME.BG2, Size=UDim2.new(1,0,0,10)}, parent)
    corner(box,10); stroke(box,1,THEME.BORDER); pad(box,10,10,10,10)
    mk("TextLabel", {BackgroundTransparency=1, Font=FONTS.HB, Text=title, TextSize=16, TextColor3=THEME.TEXT, Size=UDim2.new(1,0,0,18)}, box)
    mk("Frame", {BackgroundColor3=THEME.BORDER, Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,24)}, box)
    local inner = mk("Frame", {BackgroundTransparency=1, Position=UDim2.new(0,0,0,30), Size=UDim2.new(1,0,0,0)}, box)
    local lay = vlist(inner, 8)
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        inner.Size = UDim2.new(1,0,0, lay.AbsoluteContentSize.Y)
        box.Size = UDim2.new(1,0,0, 30 + lay.AbsoluteContentSize.Y + 10)
    end)
    return inner
end
local function sliderRow(parent, label, minV, maxV, startV, onChange, lockDrag, unlockDrag)
    local row = mk("Frame", {BackgroundColor3=THEME.CARD, Size=UDim2.new(1,0,0,56)}, parent)
    corner(row,8); stroke(row,1,THEME.BORDER); pad(row,8,10,8,10)
    mk("TextLabel", {BackgroundTransparency=1, Font=FONTS.H, Text=label, TextSize=15, TextColor3=THEME.TEXT, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,18)}, row)
    local track = mk("Frame", {BackgroundColor3=THEME.BG2, Size=UDim2.new(1,-120,0,6), Position=UDim2.new(0,10,0,36)}, row)
    corner(track,3)
    local knob  = mk("Frame", {Parent=track, BackgroundColor3=THEME.ACCENT, Size=UDim2.new(0,14,0,14), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0)}, track)
    corner(knob,7)
    local box   = mk("TextBox", {
        Text=tostring(startV), Font=FONTS.H, TextSize=14, TextColor3=THEME.TEXT,
        BackgroundColor3=THEME.BG2, Size=UDim2.new(0,84,0,26),
        AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-10,0.5,0), ClearTextOnFocus=false
    }, row)
    corner(box,8); stroke(box,1,THEME.BORDER)
    local dragging=false
    local current = startV
    local KNOB_R = 7
    local function padFrac() return KNOB_R / math.max(1, track.AbsoluteSize.X) end
    local function v2a(v) local pf=padFrac(); return pf + ((v-minV)/(maxV-minV))*(1-2*pf) end
    local function a2v(a) local pf=padFrac(); local t=(a-pf)/math.max(1e-6,(1-2*pf)); return math.floor(minV + t*(maxV-minV) + .5) end
    local function setVisual(v)
        current = math.clamp(v, minV, maxV)
        box.Text = tostring(current)
        local a = math.clamp(v2a(current), padFrac(), 1-padFrac())
        knob.Position = UDim2.new(a, 0, 0.5, 0)
    end
    local function setFromMouse(x)
        local raw = (x - track.AbsolutePosition.X)/math.max(1, track.AbsoluteSize.X)
        local a = math.clamp(raw, padFrac(), 1-padFrac())
        local v = a2v(a)
        setVisual(v)
        return v
    end
    track:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() setVisual(current) end)
    task.defer(function() setVisual(startV) end)
    knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; if lockDrag then lockDrag() end end end)
    knob.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false; if unlockDrag then unlockDrag() end end end)
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; if lockDrag then lockDrag() end; onChange(setFromMouse(i.Position.X)) end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then onChange(setFromMouse(i.Position.X)) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false; if unlockDrag then unlockDrag() end end end)
    box.FocusLost:Connect(function() local n=tonumber(box.Text); if not n then box.Text=tostring(current) return end; n=math.clamp(math.floor(n+0.5),minV,maxV); setVisual(n); onChange(n) end)
    return {SetVisual=setVisual}
end
local function buildApp()
    if CoreGui:FindFirstChild("SpeedStyleUI") then CoreGui.SpeedStyleUI:Destroy() end
    local app=mk("ScreenGui",{Name="SpeedStyleUI",IgnoreGuiInset=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Global},CoreGui)
    app.Enabled = false
    _G.UnlockAdmin(function(ok)
        if ok then
            app.Enabled = true
        else
            warn("Admin unlock failed/cancelled")
        end
    end)
    local win=mk("Frame",{Name="MainWindow",Size=UDim2.new(0,720,0,420),Position=UDim2.new(0.5,-360,0.5,-210),BackgroundColor3=THEME.BG1,Active=true,Draggable=true},app)
    corner(win,14); stroke(win,1,THEME.BORDER)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,210)),
    })
    grad.Rotation = 90
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(1, 0.95),
    })
    grad.Parent = win
    local top=mk("Frame",{BackgroundColor3=THEME.BG2,Size=UDim2.new(1,0,0,36)},win); corner(top,10); stroke(top,1,THEME.BORDER); top.ClipsDescendants = true
    mk("TextLabel",{BackgroundTransparency=1,Font=FONTS.HB,Text="GAG HUB | v1.5.5",TextColor3=THEME.TEXT,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,44,0,0),Size=UDim2.new(1,-160,1,0)},top)
    local menuBtn=mk("ImageButton",{AutoButtonColor=false,BackgroundColor3=THEME.BG3,Size=UDim2.new(0,28,0,24),Position=UDim2.new(0,8,0.5,0),AnchorPoint=Vector2.new(0,0.5),ImageTransparency=1},top)
    do
        local function bar(y)
            local f = Instance.new("Frame")
            f.BackgroundColor3 = THEME.TEXT
            f.BorderSizePixel = 0
            f.Size = UDim2.new(0, 16, 0, 2)
            f.Position = UDim2.new(0, 6, 0, y)
            f.Parent = menuBtn
        end
        bar(5); bar(10); bar(15)
    end
    local btnMin=mk("TextButton",{AutoButtonColor=false,BackgroundColor3=THEME.BG3,Size=UDim2.new(0,28,0,24),Position=UDim2.new(1,-68,0.5,0),AnchorPoint=Vector2.new(0,0.5),Text="—",TextColor3=THEME.TEXT,Font=FONTS.H,TextSize=18},top)
    local btnClose=mk("TextButton",{AutoButtonColor=false,BackgroundColor3=THEME.BG3,Size=UDim2.new(0,28,0,24),Position=UDim2.new(1,-34,0.5,0),AnchorPoint=Vector2.new(0,0.5),Text="X",TextColor3=THEME.TEXT,Font=FONTS.H,TextSize=14},top)
    corner(btnMin,6); corner(btnClose,6); stroke(btnMin,1,THEME.BORDER); stroke(btnClose,1,THEME.BORDER)
    hover(btnMin,{BackgroundColor3=THEME.BG2},{BackgroundColor3=THEME.BG3})
    hover(btnClose,{BackgroundColor3=Color3.fromRGB(120,40,40)},{BackgroundColor3=THEME.BG3})
    local sideExpandedW,sideCompactW=176,64
    local sidebarCompact=false
    local sidebarVisible=true
    local side=mk("Frame",{BackgroundColor3=THEME.BG2,Position=UDim2.new(0,0,0,36),Size=UDim2.new(0,sideExpandedW,1,-36)},win); stroke(side,1,THEME.BORDER); pad(side,10,10,10,10); vlist(side,6)
    side.ClipsDescendants = true
    local host=mk("Frame",{BackgroundColor3=THEME.BG1,Position=UDim2.new(0,sideExpandedW,0,36),Size=UDim2.new(1,-sideExpandedW,1,-36)},win); stroke(host,1,THEME.BORDER); pad(host,12,12,12,12); corner(host,12)
    host.ClipsDescendants = true
    local toast = makeToaster(app)
    local sideButtons={}
    local function applySide() for _,b in ipairs(sideButtons) do b.TextXAlignment=sidebarCompact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left end end
    local function setSidebarCompact(on)
        sidebarCompact=on and true or false
        if not sidebarVisible then return end
        local target=sidebarCompact and sideCompactW or sideExpandedW
        TweenService:Create(side,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,target,1,-36)}):Play()
        TweenService:Create(host,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,target,0,36),Size=UDim2.new(1,-target,1,-36)}):Play()
        applySide()
    end
    local function setSidebarVisible(on)
        sidebarVisible = on and true or false
        local targetW = sidebarVisible and (sidebarCompact and sideCompactW or sideExpandedW) or 0
        TweenService:Create(side, TweenInfo.new(.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, targetW, 1, -36)}):Play()
        TweenService:Create(host, TweenInfo.new(.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, targetW, 0, 36), Size = UDim2.new(1, -targetW, 1, -36)}):Play()
        applySide()
    end
    local pages={}
    local function makePage(title)
        local page=mk("Frame",{BackgroundTransparency=1,Visible=false,Size=UDim2.new(1,0,1,0)},host)
        mk("TextLabel",{BackgroundTransparency=1,Font=FONTS.HB,Text=title,TextSize=20,TextColor3=THEME.TEXT,Size=UDim2.new(1,0,0,22)},page)
        mk("Frame",{BackgroundColor3=THEME.BORDER,Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0,26)},page)
    local scroll=mk("ScrollingFrame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,32),Size=UDim2.new(1,0,1,-38),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=6},page)
    scroll.ClipsDescendants = true
        local lay=vlist(scroll,10)
        lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroll.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+8) end)
        pages[title]={Root=page,Body=scroll}; return pages[title]
    end
    local function showPage(name) for k,v in pairs(pages) do v.Root.Visible=(k==name) end end
    local function addSide(label,pageName)
        local b=mk("TextButton",{AutoButtonColor=false,BackgroundColor3=THEME.BG3,Size=UDim2.new(1,0,0,32),Font=FONTS.H,Text=label,TextColor3=THEME.TEXT,TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd},side)
        corner(b,8); stroke(b,1,THEME.BORDER); hover(b,{BackgroundColor3=THEME.BG2},{BackgroundColor3=THEME.BG3})
        b.MouseButton1Click:Connect(function()
            for _,c in ipairs(side:GetChildren()) do if c:IsA("TextButton") then TweenService:Create(c,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=THEME.BG3}):Play() end end
            TweenService:Create(b,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=THEME.BG2}):Play()
            showPage(pageName)
        end)
        table.insert(sideButtons,b); return b
    end
    hover(menuBtn,{BackgroundColor3=THEME.BG2},{BackgroundColor3=THEME.BG3})
    menuBtn.MouseButton1Click:Connect(function()
        setSidebarVisible(not sidebarVisible)
    end)
    local function makeCollapsibleSection(parent, title, initiallyExpanded)
        local sectionFrame = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,0)},parent)
        corner(sectionFrame,8); stroke(sectionFrame,1,THEME.BORDER)
    local header = mk("Frame",{BackgroundColor3=THEME.BG2,Size=UDim2.new(1,0,0,36)},sectionFrame)
        corner(header,8); stroke(header,1,THEME.BORDER)
        local expandBtn = mk("TextButton",{
            Text = initiallyExpanded and "▼" or "►",
            Font = FONTS.H, TextSize = 14, TextColor3 = THEME.TEXT,
            BackgroundTransparency = 1,
            Size = UDim2.new(0,20,1,0),
            Position = UDim2.new(0,8,0,0)
        }, header)
        local titleLabel = mk("TextLabel",{
            Text = title,
            Font = FONTS.HB, TextSize = 16, TextColor3 = THEME.TEXT,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,-36,1,0),
            Position = UDim2.new(0,28,0,0),
            TextXAlignment = Enum.TextXAlignment.Left
        }, header)
    local content = mk("Frame",{
            BackgroundTransparency = 1,
            Position = UDim2.new(0,0,0,36),
            Size = UDim2.new(1,0,1,-36),
            Visible = initiallyExpanded
        }, sectionFrame)
    sectionFrame.ClipsDescendants = true
    content.ClipsDescendants = true
        pad(content,8,8,8,8); vlist(content,6)
        local isExpanded = initiallyExpanded
        local contentLayout = content:FindFirstChildOfClass("UIListLayout")
        local function updateHeight()
            if isExpanded and contentLayout then
                local contentHeight = contentLayout.AbsoluteContentSize.Y + 16
                sectionFrame.Size = UDim2.new(1,0,0,36 + contentHeight)
            else
                sectionFrame.Size = UDim2.new(1,0,0,36)
            end
        end
        if contentLayout then
            contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateHeight)
        end
        expandBtn.MouseButton1Click:Connect(function()
            isExpanded = not isExpanded
            expandBtn.Text = isExpanded and "▼" or "►"
            content.Visible = isExpanded
            updateHeight()
        end)
        updateHeight()
        return content
    end
    do
        local P = makePage("Main")
    local autoCollectSection = makeCollapsibleSection(P.Body, "Auto Collection", false)
        makeToggle(
            autoCollectSection,
            "Auto-Collect Plants",
            "Automatically collect all ready plants continuously",
            AUTO.enabled,
            function(on)
                if on then
                    AutoStart(toast)
                else
                    AutoStop(toast)
                end
            end,
            toast
        )
        local rowMF = mk("Frame", {BackgroundColor3=THEME.CARD, Size=UDim2.new(1,0,0,46)}, autoCollectSection)
        corner(rowMF,8); stroke(rowMF,1,THEME.BORDER); pad(rowMF,6,6,6,6)
        local tb = mk("TextBox", {
            Text = MUTATION.lastText or "",
            PlaceholderText = "Mutations to collect (e.g. Glimmering, Rainbow, Golden, etc)",
            Font = FONTS.H, TextSize = 14, TextColor3 = THEME.TEXT,
            BackgroundColor3 = THEME.BG2, Size = UDim2.new(1,0,1,0),
            ClearTextOnFocus = false
        }, rowMF)
        corner(tb,8); stroke(tb,1,THEME.BORDER)
        tb.FocusLost:Connect(function()
            setMutationFilterFromText(tb.Text)
            MUTATION.lastText = tb.Text
            if MUTATION.enabled and next(MUTATION.set) then
                toast("Mutation filter set: "..tb.Text)
            else
                toast("Mutation filter cleared")
            end
        end)
        local mutationToggle = makeToggle(
            autoCollectSection,
            "Require Mutation Match",
            "Only harvest plants whose Variant/Mutation matches the list above",
            MUTATION.enabled,
            function(on)
                MUTATION.enabled = on and true or false
                if on and tb.Text and #tb.Text > 0 then
                    setMutationFilterFromText(tb.Text)
                elseif not on then
                    MUTATION.enabled = false
                    print("DEBUG: Mutation filtering disabled but text preserved")
                end
                toast("Require Mutation: "..(MUTATION.enabled and "ON" or "OFF"))
            end,
            toast
        )
        local rowTest = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},autoCollectSection)
        corner(rowTest,8); stroke(rowTest,1,THEME.BORDER); pad(rowTest,6,6,6,6)
        local btnTest = mk("TextButton",{
            Text="Test Farm Detection",
            Font=FONTS.H, TextSize=16, TextColor3=THEME.TEXT,
            BackgroundColor3=THEME.BG2, Size=UDim2.new(1,0,1,0), AutoButtonColor=false
        }, rowTest)
        corner(btnTest,8); stroke(btnTest,1,THEME.BORDER); hover(btnTest,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        btnTest.MouseButton1Click:Connect(function()
            print("=== MANUAL FARM TEST ===")
            print("Player name:", CACHE.playerName)
            print("Cached farm:", CACHE.playerFarm and CACHE.playerFarm.Name or "NONE")
            print("Cached plants folder:", CACHE.plantsFolder and "EXISTS" or "NONE")
            local plants = getAllPlants()
            print("Plants found:", #plants)
            if #plants > 0 then
                print("First few plants:")
                for i = 1, math.min(5, #plants) do
                    print("  -", plants[i].Name)
                end
                toast("Found " .. #plants .. " plants in your farm")
            else
                toast("No plants found - check console for details")
            end
        end)
    local autoSellSection = makeCollapsibleSection(P.Body, "Auto Sell", false)
        makeToggle(
            autoSellSection,
            "Auto-Sell Inventory",
            "Automatically sell when game shows 'inventory full' message",
            AUTO_SELL.enabled,
            function(on)
                if on then
                    startAutoSell(toast)
                else
                    stopAutoSell(toast)
                end
            end,
            toast
        )
        local rowSell = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},autoSellSection)
        corner(rowSell,8); stroke(rowSell,1,THEME.BORDER); pad(rowSell,6,6,6,6)
        local btnSell = mk("TextButton",{
            Text="Test Sell Now",
            Font=FONTS.H, TextSize=16, TextColor3=THEME.TEXT,
            BackgroundColor3=THEME.BG2, Size=UDim2.new(1,0,1,0), AutoButtonColor=false
        }, rowSell)
        corner(btnSell,8); stroke(btnSell,1,THEME.BORDER); hover(btnSell,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        btnSell.MouseButton1Click:Connect(function()
            print("=== MANUAL SELL TEST ===")
            if performAutoSell() then
                toast("Inventory sold successfully!")
            else
                toast("Sell failed - check console for details")
            end
        end)
    end
    do
        local P=makePage("Player")
        local GM = groupBox(P.Body, "Movement")
        makeToggle(GM,"Enable Custom WalkSpeed","Apply your chosen speed",false,function(on) setCustomSpeed(on) end,toast)
        local dragging=false; local prevDrag=true
        local function lockDrag() if not dragging then dragging=true; prevDrag=win.Draggable; win.Draggable=false end end
        local function unlockDrag() if dragging then dragging=false; win.Draggable=(prevDrag==nil) and true or prevDrag end end
        sliderRow(GM, "WalkSpeed", SPEED.MIN, SPEED.MAX, SPEED.Chosen, function(v)
            SPEED.Chosen=v
            if SPEED.Enabled then applySpeedValue(v) end
        end, lockDrag, unlockDrag)
        makeToggle(GM,"Fly","WASD + E/Q for up/down",false,function(on) setFly(on) end,toast)
        sliderRow(GM, "Fly Speed", 20, 300, Fly.Speed, function(v) Fly.Speed=v end, lockDrag, unlockDrag)
        local GA = groupBox(P.Body, "Abilities / Utility")
        makeToggle(GA,"Infinite Jump","Allow jumping mid-air",false,function(on) InfiniteJump.Enabled=on end,toast)
        makeToggle(GA,"NoClip","Disable collisions on your character",false,function(on) setNoClip(on) end,toast)
        makeToggle(GA,"Ctrl + Click Teleport","Hold LeftCtrl and click to teleport",false,function(on) Teleport.Enabled=on end,toast)
    end
    do
        local P=makePage("Misc")
        local U = makeCollapsibleSection(P.Body, "UI Options", false)
        makeToggle(U, "Compact Sidebar", "Shrink sidebar width", false, function(on)
            setSidebarCompact(on)
        end, toast)
        local V = makeCollapsibleSection(P.Body, "Visuals", false)
        makeToggle(V, "Vibrant Grass Overlay", "Client-only overlay (no duplicates)", false, function(on)
            if on then GO_Start() else GO_Stop() end
        end, toast)
    local row1 = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},V)
        corner(row1,8); stroke(row1,1,THEME.BORDER); pad(row1,6,6,6,6)
        local bb = mk("TextButton",{Text="Build Beach",Font=FONTS.H,TextSize=16,TextColor3=THEME.TEXT,BackgroundColor3=THEME.BG2,Size=UDim2.new(.5,-4,1,0),AutoButtonColor=false},row1)
        local cb = mk("TextButton",{Text="Clear Beach",Font=FONTS.H,TextSize=16,TextColor3=THEME.TEXT,BackgroundColor3=THEME.BG2,Size=UDim2.new(.5,-4,1,0),Position=UDim2.new(.5,8,0,0),AutoButtonColor=false},row1)
        corner(bb,8); stroke(bb,1,THEME.BORDER); hover(bb,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        corner(cb,8); stroke(cb,1,THEME.BORDER); hover(cb,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        bb.MouseButton1Click:Connect(function() beachBuild(); toast("Beach built (client)") end)
        cb.MouseButton1Click:Connect(function() beachCleanup(); toast("Beach cleared") end)
    local row2 = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},V)
        corner(row2,8); stroke(row2,1,THEME.BORDER); pad(row2,6,6,6,6)
        local pb = mk("TextButton",{Text="Print Anchor CFrame",Font=FONTS.H,TextSize=16,TextColor3=THEME.TEXT,BackgroundColor3=THEME.BG2,Size=UDim2.new(1,0,1,0),AutoButtonColor=false},row2)
        corner(pb,8); stroke(pb,1,THEME.BORDER); hover(pb,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        pb.MouseButton1Click:Connect(function()
            if BEACH.anchorCF then beachLogCF(BEACH.anchorCF, "Current Anchor") else toast("Build beach first to set anchor") end
        end)
    end
    do
        local P=makePage("Scripts")
        local S = groupBox(P.Body, "Quick Executors")
        local row = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},S)
        corner(row,8); stroke(row,1,THEME.BORDER); pad(row,6,6,6,6)
        local iy = mk("TextButton",{Text="Load Infinite Yield",Font=FONTS.H,TextSize=16,TextColor3=THEME.TEXT,BackgroundColor3=THEME.BG2,Size=UDim2.new(1,0,1,0),AutoButtonColor=false},row)
        corner(iy,8); stroke(iy,1,THEME.BORDER); hover(iy,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        iy.MouseButton1Click:Connect(function()
            toast("Loading Infinite Yield…")
            execInfiniteYield(toast)
        end)
        local rowFairy = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},S)
        corner(rowFairy,8); stroke(rowFairy,1,THEME.BORDER); pad(rowFairy,6,6,6,6)
        local btnFairy = mk("TextButton",{
            Text="Load Fairy Watcher",
            Font=FONTS.H, TextSize=16, TextColor3=THEME.TEXT,
            BackgroundColor3=THEME.BG2, Size=UDim2.new(1,0,1,0), AutoButtonColor=false
        }, rowFairy)
        corner(btnFairy,8); stroke(btnFairy,1,THEME.BORDER); hover(btnFairy,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        btnFairy.MouseButton1Click:Connect(function()
            toast("Loading Fairy Watcher…")
            local ok, err = pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/CheesyPoofs346/fairy/refs/heads/main/Protected_7114364430847823.lua"))()
            end)
            if not ok then
                warn("[Fairy Watcher] ".. tostring(err))
                toast("Fairy Watcher: error (see Output)")
            end
        end)
    end
    do
    local P = makePage("Events")
    local autoFairySection = makeCollapsibleSection(P.Body, "Fairy Fountain Auto Submit", false)
        makeToggle(
            autoFairySection,
            "Auto Submit to Fairy",
            "Automatically submit to fairy fountain when glimmering plant is detected in backpack",
            AUTO_FAIRY.enabled,
            function(on)
                if on then
                    startAutoFairy(toast)
                else
                    stopAutoFairy(toast)
                end
            end,
            toast
        )
        local rowFairyTest = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},autoFairySection)
        corner(rowFairyTest,8); stroke(rowFairyTest,1,THEME.BORDER); pad(rowFairyTest,6,6,6,6)
        local btnFairyTest = mk("TextButton",{
            Text="Test Fairy Submit Now",
            Font=FONTS.H, TextSize=16, TextColor3=THEME.TEXT,
            BackgroundColor3=THEME.BG2, Size=UDim2.new(1,0,1,0), AutoButtonColor=false
        }, rowFairyTest)
        corner(btnFairyTest,8); stroke(btnFairyTest,1,THEME.BORDER); hover(btnFairyTest,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        btnFairyTest.MouseButton1Click:Connect(function()
            print("=== MANUAL FAIRY TEST ===")
            if submitToFairyFountain() then
                toast("Fairy submission successful!")
            else
                toast("Fairy submission failed - check console for details")
            end
        end)
        local rowBackpackCheck = mk("Frame",{BackgroundColor3=THEME.CARD,Size=UDim2.new(1,0,0,46)},autoFairySection)
        corner(rowBackpackCheck,8); stroke(rowBackpackCheck,1,THEME.BORDER); pad(rowBackpackCheck,6,6,6,6)
        local btnBackpackCheck = mk("TextButton",{
            Text="Check for Glimmering in Backpack",
            Font=FONTS.H, TextSize=16, TextColor3=THEME.TEXT,
            BackgroundColor3=THEME.BG2, Size=UDim2.new(1,0,1,0), AutoButtonColor=false
        }, rowBackpackCheck)
        corner(btnBackpackCheck,8); stroke(btnBackpackCheck,1,THEME.BORDER); hover(btnBackpackCheck,{BackgroundColor3=THEME.BG3},{BackgroundColor3=THEME.BG2})
        btnBackpackCheck.MouseButton1Click:Connect(function()
            print("=== BACKPACK GLIMMERING CHECK ===")
            if hasGlimmeringInBackpack() then
                toast("Glimmering plant found in backpack!")
                print("DEBUG: Glimmering plant detected")
            else
                toast("No glimmering plants in backpack")
            end
        end)
    end
    do
    local P = makePage("Shops")
    local seedShopSection = makeCollapsibleSection(P.Body, "Seed Shop Auto Buy", false)
    local gearShopSection = makeCollapsibleSection(P.Body, "Gear Shop Auto Buy", false)
        local function getAvailableSeeds()
            AUTO_SHOP.availableSeeds = {}
            print("DEBUG: Starting seed shop scan using SeedData module...")
            local success, seedData = pcall(function()
                return require(ReplicatedStorage.Data.SeedData)
            end)
            if success and seedData then
                print("DEBUG: Successfully loaded SeedData module")
                for seedKey, seedInfo in pairs(seedData) do
                    if seedInfo.DisplayInShop then
                        print("DEBUG: Found shop seed:", seedKey, "->", seedInfo.SeedName)
                        table.insert(AUTO_SHOP.availableSeeds, {
                            key = seedKey,
                            name = seedInfo.SeedName,
                            price = seedInfo.Price,
                            layoutOrder = seedInfo.LayoutOrder or 999,
                            displayName = seedInfo.SeedName,
                            selected = false
                        })
                    end
                end
                table.sort(AUTO_SHOP.availableSeeds, function(a, b)
                    if a.layoutOrder == b.layoutOrder then
                        return a.name < b.name
                    else
                        return a.layoutOrder < b.layoutOrder
                    end
                end)
                print("DEBUG: Loaded", #AUTO_SHOP.availableSeeds, "seeds from SeedData module")
            else
                print("DEBUG: Failed to load SeedData module, falling back to simple detection...")
                local commonSeeds = {"Carrot Seeds", "Tomato Seeds", "Potato Seeds", "Corn Seeds", "Wheat Seeds", "Apple Seeds", "Orange Seeds", "Pineapple Seeds"}
                for i, seedName in ipairs(commonSeeds) do
                    table.insert(AUTO_SHOP.availableSeeds, {
                        key = string.gsub(seedName, " Seeds", ""),
                        name = seedName,
                        price = 0,
                        layoutOrder = i,
                        displayName = seedName,
                        selected = false
                    })
                    print("DEBUG: Added fallback seed:", seedName)
                end
            end
            print("DEBUG: Seed shop scan complete. Found", #AUTO_SHOP.availableSeeds, "seed options")
            return AUTO_SHOP.availableSeeds
        end
        local function validateSeedAvailability()
            print("DEBUG: Validating seed availability...")
        end
        getAvailableSeeds()
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Parent = seedShopSection
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size = UDim2.new(1, -20, 0, 24)
    headerLabel.Position = UDim2.new(0, 10, 0, 50)
    headerLabel.Text = "Select Seeds"
    headerLabel.TextColor3 = THEME.TEXT
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 14
        local autoBuyTgl
        local autoBuyAllTgl
        autoBuyTgl = makeToggle(
            seedShopSection,
            "Auto Buy Selected Seeds",
            "Continuously buys the seeds you select below",
            AUTO_SHOP.enabled,
            function(on)
                AUTO_SHOP.modeSelected = on and true or false
                if on then
                    if AUTO_SHOP.buyAll then
                        AUTO_SHOP.buyAll = false
                        AUTO_SHOP.modeAll = false
                        if autoBuyAllTgl and autoBuyAllTgl.Set then autoBuyAllTgl.Set(false) end
                        if toast then toast("Auto Buy All Seeds turned OFF (using Selected mode)") end
                    end
                    if #AUTO_SHOP.selectedSeeds > 0 then
                        if not AUTO_SHOP.enabled then startAutoShop(toast) end
                    else
                        if toast then toast("Please select at least one seed first!") end
                        AUTO_SHOP.modeSelected = false
                        autoBuyTgl.Set(false)
                        if AUTO_SHOP.enabled and not AUTO_SHOP.modeAll then stopAutoShop(toast) end
                    end
                else
                    if AUTO_SHOP.enabled and not AUTO_SHOP.modeAll then
                        stopAutoShop(toast)
                    end
                end
            end,
            toast
        )
    autoBuyTgl.Instance.Position = UDim2.new(0, 10, 0, 82)
        autoBuyTgl.Instance.Size = UDim2.new(1, -20, 0, 46)
    autoBuyAllTgl = makeToggle(
            seedShopSection,
            "Auto Buy All Seeds",
            "Continuously buys every seed that appears in the shop",
            AUTO_SHOP.buyAll,
            function(on)
                AUTO_SHOP.buyAll = on and true or false
                AUTO_SHOP.modeAll = AUTO_SHOP.buyAll
        if AUTO_SHOP.buyAll and (AUTO_SHOP.modeSelected) then
                    if toast then toast("Auto Buy Selected turned OFF (using All Seeds mode)") end
                    AUTO_SHOP.modeSelected = false
                    autoBuyTgl.Set(false)
                end
                if on and not AUTO_SHOP.enabled then
                    if #AUTO_SHOP.availableSeeds == 0 then getAvailableSeeds() end
                    startAutoShop(toast)
        elseif (not on) and AUTO_SHOP.enabled and (not AUTO_SHOP.modeSelected) then
                    stopAutoShop(toast)
                end
            end,
            toast
        )
        autoBuyAllTgl.Instance.Position = UDim2.new(0, 10, 0, 132)
        autoBuyAllTgl.Instance.Size = UDim2.new(1, -20, 0, 46)
        local dropdownContainer = Instance.new("Frame")
        dropdownContainer.Parent = seedShopSection
        dropdownContainer.BackgroundTransparency = 1
        dropdownContainer.Size = UDim2.new(1, -20, 0, 40)
    dropdownContainer.Position = UDim2.new(0, 10, 0, 184)
        local dropdownButton = Instance.new("TextButton")
        dropdownButton.Parent = dropdownContainer
        dropdownButton.BackgroundColor3 = THEME.BG2
        dropdownButton.BorderSizePixel = 0
        dropdownButton.Size = UDim2.new(1, 0, 1, 0)
        dropdownButton.Text = "Select Seeds ▼"
        dropdownButton.TextColor3 = THEME.TEXT
        dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
        dropdownButton.Font = Enum.Font.Gotham
        dropdownButton.TextSize = 13
        corner(dropdownButton, 8)
        stroke(dropdownButton, 1, THEME.BORDER)
        pad(dropdownButton, 0, 0, 0, 15)
    local seedListFrame = Instance.new("ScrollingFrame")
        seedListFrame.Parent = seedShopSection
        seedListFrame.BackgroundColor3 = THEME.BG1
        seedListFrame.BorderSizePixel = 0
        seedListFrame.Size = UDim2.new(1, -20, 0, 200)
    seedListFrame.Position = UDim2.new(0, 10, 0, 229)
        seedListFrame.Visible = false
        seedListFrame.CanvasSize = UDim2.new(0, 0, 0, #AUTO_SHOP.availableSeeds * 35 + 10)
        seedListFrame.ScrollBarThickness = 8
    seedListFrame.ClipsDescendants = true
        corner(seedListFrame, 8)
        stroke(seedListFrame, 1, THEME.BORDER)
        local seedListLayout = Instance.new("UIListLayout")
        seedListLayout.Parent = seedListFrame
        seedListLayout.Padding = UDim.new(0, 3)
        seedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        local function updateDropdownText()
            local selectedCount = #AUTO_SHOP.selectedSeeds
            if selectedCount == 0 then
                dropdownButton.Text = "Select Seeds ▼"
            elseif selectedCount == 1 then
                dropdownButton.Text = AUTO_SHOP.selectedSeeds[1].displayName .. " ▼"
            else
                local names = {}
                for i = 1, math.min(selectedCount, 3) do
                    table.insert(names, AUTO_SHOP.selectedSeeds[i].displayName)
                end
                if selectedCount > 3 then
                    dropdownButton.Text = table.concat(names, ", ") .. " +" .. (selectedCount - 3) .. " more ▼"
                else
                    dropdownButton.Text = table.concat(names, ", ") .. " ▼"
                end
            end
        end
        local function createSeedList()
            for _, child in ipairs(seedListFrame:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end
            do
                local allRow = Instance.new("Frame")
                allRow.Parent = seedListFrame
                allRow.BackgroundColor3 = THEME.BG2
                allRow.BorderSizePixel = 0
                allRow.Size = UDim2.new(1, -16, 0, 32)
                allRow.LayoutOrder = 0
                corner(allRow, 6)
                local allBtn = Instance.new("TextButton")
                allBtn.Parent = allRow
                allBtn.BackgroundTransparency = 1
                allBtn.Size = UDim2.new(1, 0, 1, 0)
                allBtn.Text = "All"
                allBtn.TextColor3 = THEME.TEXT
                allBtn.Font = Enum.Font.Gotham
                allBtn.TextSize = 13
                allBtn.MouseButton1Click:Connect(function()
                    local allSelected = true
                    for _, sd in ipairs(AUTO_SHOP.availableSeeds) do
                        if not sd.selected then allSelected = false break end
                    end
                    AUTO_SHOP.selectedSeeds = {}
                    if allSelected then
                        for _, sd in ipairs(AUTO_SHOP.availableSeeds) do sd.selected = false end
                        if toast then toast("Cleared all selections") end
                    else
                        for _, sd in ipairs(AUTO_SHOP.availableSeeds) do sd.selected = true; table.insert(AUTO_SHOP.selectedSeeds, sd) end
                        if toast then toast("Selected all " .. #AUTO_SHOP.availableSeeds .. " seeds!") end
                    end
                    createSeedList()
                    updateDropdownText()
                end)
                allRow.MouseEnter:Connect(function() allRow.BackgroundColor3 = THEME.BG3 end)
                allRow.MouseLeave:Connect(function() allRow.BackgroundColor3 = THEME.BG2 end)
            end
            for i, seedData in ipairs(AUTO_SHOP.availableSeeds) do
                local seedRow = Instance.new("Frame")
                seedRow.Parent = seedListFrame
                seedRow.BackgroundColor3 = THEME.BG2
                seedRow.BorderSizePixel = 0
                seedRow.Size = UDim2.new(1, -16, 0, 32)
                seedRow.LayoutOrder = i + 1
                corner(seedRow, 6)
                local checkbox = Instance.new("TextButton")
                checkbox.Parent = seedRow
                checkbox.BackgroundColor3 = seedData.selected and Color3.fromRGB(0, 150, 0) or THEME.BG3
                checkbox.Size = UDim2.new(0, 24, 0, 24)
                checkbox.Position = UDim2.new(0, 8, 0.5, -12)
                checkbox.Text = ""
                checkbox.BorderSizePixel = 0
                corner(checkbox, 4)
                stroke(checkbox, 1, THEME.BORDER)
                local checkmark = Instance.new("TextLabel")
                checkmark.Parent = checkbox
                checkmark.BackgroundTransparency = 1
                checkmark.Size = UDim2.new(1, 0, 1, 0)
                checkmark.Text = "✓"
                checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
                checkmark.TextScaled = true
                checkmark.Font = Enum.Font.GothamBold
                checkmark.Visible = seedData.selected or false
                local seedLabel = Instance.new("TextLabel")
                seedLabel.Parent = seedRow
                seedLabel.BackgroundTransparency = 1
                seedLabel.Size = UDim2.new(1, -40, 1, 0)
                seedLabel.Position = UDim2.new(0, 40, 0, 0)
                seedLabel.Text = seedData.displayName .. (seedData.price > 0 and (" - " .. seedData.price .. "¢") or "")
                seedLabel.TextColor3 = THEME.TEXT
                seedLabel.TextXAlignment = Enum.TextXAlignment.Left
                seedLabel.Font = Enum.Font.Gotham
                seedLabel.TextSize = 13
                local function toggleSelection()
                    seedData.selected = not (seedData.selected or false)
                    checkbox.BackgroundColor3 = seedData.selected and Color3.fromRGB(0, 150, 0) or THEME.BG3
                    checkmark.Visible = seedData.selected
                    AUTO_SHOP.selectedSeeds = {}
                    for _, seed in ipairs(AUTO_SHOP.availableSeeds) do
                        if seed.selected then
                            table.insert(AUTO_SHOP.selectedSeeds, seed)
                        end
                    end
                    updateDropdownText()
                end
                checkbox.MouseButton1Click:Connect(toggleSelection)
                seedRow.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        toggleSelection()
                    end
                end)
                seedRow.MouseEnter:Connect(function()
                    if not seedData.selected then
                        seedRow.BackgroundColor3 = THEME.BG3
                    end
                end)
                seedRow.MouseLeave:Connect(function()
                    if not seedData.selected then
                        seedRow.BackgroundColor3 = THEME.BG2
                    end
                end)
            end
            seedListFrame.CanvasSize = UDim2.new(0, 0, 0, (#AUTO_SHOP.availableSeeds + 1) * 35 + 10)
            updateDropdownText()
        end
        dropdownButton.MouseButton1Click:Connect(function()
            seedListFrame.Visible = not seedListFrame.Visible
            local isOpen = seedListFrame.Visible
            dropdownButton.Text = dropdownButton.Text:gsub("▼", isOpen and "▲" or "▼")
            dropdownButton.Text = dropdownButton.Text:gsub("▲", isOpen and "▲" or "▼")
        end)
        local UserInputService = game:GetService("UserInputService")
        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if seedListFrame.Visible then
                    local mousePos = UserInputService:GetMouseLocation()
                    local dropdownPos = dropdownButton.AbsolutePosition
                    local dropdownSize = dropdownButton.AbsoluteSize
                    local listPos = seedListFrame.AbsolutePosition
                    local listSize = seedListFrame.AbsoluteSize
                    local outsideDropdown = mousePos.X < dropdownPos.X or mousePos.X > dropdownPos.X + dropdownSize.X or
                                          mousePos.Y < dropdownPos.Y or mousePos.Y > dropdownPos.Y + dropdownSize.Y
                    local outsideList = mousePos.X < listPos.X or mousePos.X > listPos.X + listSize.X or
                                       mousePos.Y < listPos.Y or mousePos.Y > listPos.Y + listSize.Y
                    if outsideDropdown and outsideList then
                        seedListFrame.Visible = false
                        updateDropdownText()
                    end
                end
            end
        end)
        createSeedList()
    local function getAvailableGear()
        _loadGearData()
        return AUTO_GEAR.availableGear
    end
    getAvailableGear()
    local gearHeader = Instance.new("TextLabel")
    gearHeader.Parent = gearShopSection
    gearHeader.BackgroundTransparency = 1
    gearHeader.Size = UDim2.new(1, -20, 0, 24)
    gearHeader.Position = UDim2.new(0, 10, 0, 50)
    gearHeader.Text = "Select Gear"
    gearHeader.TextColor3 = THEME.TEXT
    gearHeader.TextXAlignment = Enum.TextXAlignment.Left
    gearHeader.Font = Enum.Font.GothamBold
    gearHeader.TextSize = 14
    local gearAutoSelectedTgl, gearAutoAllTgl
    gearAutoSelectedTgl = makeToggle(
        gearShopSection,
        "Auto Buy Selected Gear",
        "Continuously buys the gear you select below",
        AUTO_GEAR.enabled,
        function(on)
            AUTO_GEAR.modeSelected = on and true or false
            if on then
                if AUTO_GEAR.buyAll then
                    AUTO_GEAR.buyAll = false; AUTO_GEAR.modeAll = false
                    if gearAutoAllTgl and gearAutoAllTgl.Set then gearAutoAllTgl.Set(false) end
                end
                if #AUTO_GEAR.selectedGear > 0 then
                    if not AUTO_GEAR.enabled then startAutoGear(toast) end
                else
                    toast("Please select at least one gear first!")
                    AUTO_GEAR.modeSelected = false
                    gearAutoSelectedTgl.Set(false)
                    if AUTO_GEAR.enabled and not AUTO_GEAR.modeAll then stopAutoGear(toast) end
                end
            else
                if AUTO_GEAR.enabled and not AUTO_GEAR.modeAll then stopAutoGear(toast) end
            end
        end,
        toast
    )
    gearAutoSelectedTgl.Instance.Position = UDim2.new(0, 10, 0, 82)
    gearAutoSelectedTgl.Instance.Size = UDim2.new(1, -20, 0, 46)
    gearAutoAllTgl = makeToggle(
        gearShopSection,
        "Auto Buy All Gear",
        "Continuously buys every gear item that appears in the shop",
        AUTO_GEAR.buyAll,
        function(on)
            AUTO_GEAR.buyAll = on and true or false
            AUTO_GEAR.modeAll = AUTO_GEAR.buyAll
            if AUTO_GEAR.buyAll and AUTO_GEAR.modeSelected then
                toast("Auto Buy Selected (Gear) turned OFF (using All mode)")
                AUTO_GEAR.modeSelected = false
                gearAutoSelectedTgl.Set(false)
            end
            if on and not AUTO_GEAR.enabled then
                if #AUTO_GEAR.availableGear == 0 then getAvailableGear() end
                startAutoGear(toast)
            elseif (not on) and AUTO_GEAR.enabled and (not AUTO_GEAR.modeSelected) then
                stopAutoGear(toast)
            end
        end,
        toast
    )
    gearAutoAllTgl.Instance.Position = UDim2.new(0, 10, 0, 132)
    gearAutoAllTgl.Instance.Size = UDim2.new(1, -20, 0, 46)
    local gearDropdownContainer = Instance.new("Frame")
    gearDropdownContainer.Parent = gearShopSection
    gearDropdownContainer.BackgroundTransparency = 1
    gearDropdownContainer.Size = UDim2.new(1, -20, 0, 40)
    gearDropdownContainer.Position = UDim2.new(0, 10, 0, 184)
    local gearDropdownButton = Instance.new("TextButton")
    gearDropdownButton.Parent = gearDropdownContainer
    gearDropdownButton.BackgroundColor3 = THEME.BG2
    gearDropdownButton.BorderSizePixel = 0
    gearDropdownButton.Size = UDim2.new(1, 0, 1, 0)
    gearDropdownButton.Text = "Select Gear ▼"
    gearDropdownButton.TextColor3 = THEME.TEXT
    gearDropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    gearDropdownButton.Font = Enum.Font.Gotham
    gearDropdownButton.TextSize = 13
    corner(gearDropdownButton, 8)
    stroke(gearDropdownButton, 1, THEME.BORDER)
    pad(gearDropdownButton, 0, 0, 0, 15)
    local gearListFrame = Instance.new("ScrollingFrame")
    gearListFrame.Parent = gearShopSection
    gearListFrame.BackgroundColor3 = THEME.BG1
    gearListFrame.BorderSizePixel = 0
    gearListFrame.Size = UDim2.new(1, -20, 0, 200)
    gearListFrame.Position = UDim2.new(0, 10, 0, 229)
    gearListFrame.Visible = false
    gearListFrame.CanvasSize = UDim2.new(0, 0, 0, #AUTO_GEAR.availableGear * 35 + 10)
    gearListFrame.ScrollBarThickness = 8
    gearListFrame.ClipsDescendants = true
    corner(gearListFrame, 8); stroke(gearListFrame, 1, THEME.BORDER)
    local gearListLayout = Instance.new("UIListLayout"); gearListLayout.Parent = gearListFrame; gearListLayout.Padding = UDim.new(0, 3); gearListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local function updateGearDropdownText()
        local n = #AUTO_GEAR.selectedGear
        if n == 0 then gearDropdownButton.Text = "Select Gear ▼"
        elseif n == 1 then gearDropdownButton.Text = (AUTO_GEAR.selectedGear[1].displayName or AUTO_GEAR.selectedGear[1].name) .. " ▼"
        else
            local names = {}
            for i=1, math.min(n,3) do table.insert(names, AUTO_GEAR.selectedGear[i].displayName or AUTO_GEAR.selectedGear[i].name) end
            gearDropdownButton.Text = table.concat(names, ", ") .. (n>3 and (" +"..(n-3).." more ▼") or " ▼")
        end
    end
    local function createGearList()
        for _, ch in ipairs(gearListFrame:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        do
            local allRow = Instance.new("Frame"); allRow.Parent = gearListFrame; allRow.BackgroundColor3 = THEME.BG2; allRow.BorderSizePixel = 0; allRow.Size = UDim2.new(1, -16, 0, 32); allRow.LayoutOrder = 0; corner(allRow, 6)
            local btn = Instance.new("TextButton"); btn.Parent = allRow; btn.BackgroundTransparency = 1; btn.Size = UDim2.new(1,0,1,0); btn.Text = "All"; btn.TextColor3 = THEME.TEXT; btn.Font = Enum.Font.Gotham; btn.TextSize = 13
            btn.MouseButton1Click:Connect(function()
                local allSelected = true; for _, it in ipairs(AUTO_GEAR.availableGear) do if not it.selected then allSelected=false break end end
                AUTO_GEAR.selectedGear = {}
                if allSelected then
                    for _, it in ipairs(AUTO_GEAR.availableGear) do it.selected=false end
                    toast("Cleared all gear selections")
                else
                    for _, it in ipairs(AUTO_GEAR.availableGear) do it.selected=true; table.insert(AUTO_GEAR.selectedGear, it) end
                    toast("Selected all "..#AUTO_GEAR.availableGear.." gear items!")
                end
                createGearList(); updateGearDropdownText()
            end)
            allRow.MouseEnter:Connect(function() allRow.BackgroundColor3 = THEME.BG3 end)
            allRow.MouseLeave:Connect(function() allRow.BackgroundColor3 = THEME.BG2 end)
        end
        for i, it in ipairs(AUTO_GEAR.availableGear) do
            local row = Instance.new("Frame"); row.Parent = gearListFrame; row.BackgroundColor3 = THEME.BG2; row.BorderSizePixel = 0; row.Size = UDim2.new(1, -16, 0, 32); row.LayoutOrder = i + 1; corner(row, 6)
            local checkbox = Instance.new("TextButton"); checkbox.Parent=row; checkbox.BackgroundColor3 = it.selected and Color3.fromRGB(0,150,0) or THEME.BG3; checkbox.Size = UDim2.new(0,24,0,24); checkbox.Position = UDim2.new(0,8,0.5,-12); checkbox.Text=""; checkbox.BorderSizePixel=0; corner(checkbox,4); stroke(checkbox,1,THEME.BORDER)
            local checkmark = Instance.new("TextLabel"); checkmark.Parent=checkbox; checkmark.BackgroundTransparency=1; checkmark.Size=UDim2.new(1,0,1,0); checkmark.Text="✓"; checkmark.TextColor3=Color3.new(1,1,1); checkmark.TextScaled=true; checkmark.Font=Enum.Font.GothamBold; checkmark.Visible = it.selected or false
            local label = Instance.new("TextLabel"); label.Parent=row; label.BackgroundTransparency=1; label.Size=UDim2.new(1,-40,1,0); label.Position=UDim2.new(0,40,0,0); label.Text=(it.displayName or it.name) .. ((it.price and it.price>0) and (" - "..it.price.."¢") or ""); label.TextColor3=THEME.TEXT; label.TextXAlignment=Enum.TextXAlignment.Left; label.Font=Enum.Font.Gotham; label.TextSize=13
            local function toggle()
                it.selected = not (it.selected or false); checkbox.BackgroundColor3 = it.selected and Color3.fromRGB(0,150,0) or THEME.BG3; checkmark.Visible = it.selected
                AUTO_GEAR.selectedGear = {}; for _, g in ipairs(AUTO_GEAR.availableGear) do if g.selected then table.insert(AUTO_GEAR.selectedGear, g) end end
                updateGearDropdownText()
            end
            checkbox.MouseButton1Click:Connect(toggle)
            row.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then toggle() end end)
            row.MouseEnter:Connect(function() if not it.selected then row.BackgroundColor3 = THEME.BG3 end end)
            row.MouseLeave:Connect(function() if not it.selected then row.BackgroundColor3 = THEME.BG2 end end)
        end
        gearListFrame.CanvasSize = UDim2.new(0,0,0,(#AUTO_GEAR.availableGear+1)*35+10)
        updateGearDropdownText()
    end
    gearDropdownButton.MouseButton1Click:Connect(function()
        gearListFrame.Visible = not gearListFrame.Visible
        local isOpen = gearListFrame.Visible
        gearDropdownButton.Text = gearDropdownButton.Text:gsub("▼", isOpen and "▲" or "▼")
        gearDropdownButton.Text = gearDropdownButton.Text:gsub("▲", isOpen and "▲" or "▼")
    end)
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if gearListFrame.Visible then
                local mousePos = UserInputService:GetMouseLocation()
                local btnPos, btnSize = gearDropdownButton.AbsolutePosition, gearDropdownButton.AbsoluteSize
                local listPos, listSize = gearListFrame.AbsolutePosition, gearListFrame.AbsoluteSize
                local outsideBtn = mousePos.X < btnPos.X or mousePos.X > btnPos.X + btnSize.X or mousePos.Y < btnPos.Y or mousePos.Y > btnPos.Y + btnSize.Y
                local outsideList = mousePos.X < listPos.X or mousePos.X > listPos.X + listSize.X or mousePos.Y < listPos.Y or mousePos.Y > listPos.Y + listSize.Y
                if outsideBtn and outsideList then gearListFrame.Visible = false; updateGearDropdownText() end
            end
        end
    end)
    createGearList()
    end
    addSide("Main","Main")
    addSide("Events","Events")
    addSide("Shops","Shops")
    addSide("Player","Player")
    addSide("Misc","Misc")
    addSide("Scripts","Scripts")
    applySide()
    showPage("Player")
    applyGlassLook(app)
    snapshotTransparency(win)
    local minimized=false
    local function fadeOutAll(done) tweenTo(win, FADE_DUR, true); task.delay(FADE_DUR, function() if done then done() end end) end
    local function fadeInAll() tweenTo(win, FADE_DUR, false) end
    local function showMinimizeHint()
        for _, child in ipairs(CoreGui:GetChildren()) do
            if child.Name == "SpeedStyleUI_Hint" then pcall(function() child:Destroy() end) end
        end
        local hintGui = mk("ScreenGui", {Name="SpeedStyleUI_Hint", IgnoreGuiInset=true, ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Global}, CoreGui)
        hintGui.DisplayOrder = 9999
        local box = mk("Frame", {Size=UDim2.new(0, 420, 0, 40), Position=UDim2.new(0.5, 0, 0, 10), AnchorPoint=Vector2.new(0.5,0), BackgroundColor3=THEME.BG2, BackgroundTransparency=0}, hintGui)
        corner(box, 8); stroke(box, 1, THEME.BORDER); pad(box, 8, 12, 8, 12)
        local lbl = mk("TextLabel", {BackgroundTransparency=1, Font=FONTS.H, Text="Press Right Ctrl to reopen", TextSize=14, TextColor3=THEME.TEXT, TextXAlignment=Enum.TextXAlignment.Center, Size=UDim2.new(1,0,1,0)}, box)
        box.BackgroundTransparency = 1; lbl.TextTransparency = 1
        TweenService:Create(box, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=0}):Play()
        TweenService:Create(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency=0}):Play()
        task.defer(function()
            if box and box.Parent then
                box.AnchorPoint = Vector2.new(0.5, 0)
                box.Position = UDim2.new(0.5, 0, 0, 10)
            end
        end)
        task.delay(2.5, function()
            if not hintGui or not hintGui.Parent then return end
            local t1 = TweenService:Create(box, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1})
            local t2 = TweenService:Create(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency=1})
            t1:Play(); t2:Play()
            task.wait(0.27)
            if hintGui and hintGui.Parent then hintGui:Destroy() end
        end)
    end
    local function hideMinimizeHint()
        local hint = CoreGui:FindFirstChild("SpeedStyleUI_Hint")
        if hint then hint:Destroy() end
    end
    local function shutdownAndClose()
        print("DEBUG: Shutting down all systems...")
        if AUTO.enabled then AutoStop() print("DEBUG: Auto-collect stopped") end
        if AUTO_SELL.enabled then stopAutoSell() end
        if AUTO_SELL.messageConnection then AUTO_SELL.messageConnection:Disconnect(); AUTO_SELL.messageConnection=nil end
        if AUTO_SELL.playerGuiConn then AUTO_SELL.playerGuiConn:Disconnect(); AUTO_SELL.playerGuiConn=nil end
        if AUTO_SELL.playerGuiDescendantConns then for _,c in ipairs(AUTO_SELL.playerGuiDescendantConns) do pcall(function() c:Disconnect() end) end; AUTO_SELL.playerGuiDescendantConns = {} end
        do
            local starterGui = game:GetService("StarterGui")
            if AUTO_SELL.starterGuiSetCoreOriginal then
                starterGui.SetCore = AUTO_SELL.starterGuiSetCoreOriginal
                AUTO_SELL.starterGuiSetCoreOriginal = nil
            end
        end
        if AUTO_FAIRY.enabled then stopAutoFairy() print("DEBUG: Auto-fairy stopped") end
        if AUTO_SHOP.enabled then stopAutoShop() print("DEBUG: Auto-shop stopped") end
        if GO.Enabled then GO_Stop() print("DEBUG: Grass overlay stopped") end
        beachCleanup()
        setNoClip(false)
        stopFly()
        setCustomSpeed(false)
        Teleport.Enabled=false
        InfiniteJump.Enabled=false
        if NoClip.Conn then pcall(function() NoClip.Conn:Disconnect() end); NoClip.Conn=nil end
        if Fly.Conn then pcall(function() Fly.Conn:Disconnect() end); Fly.Conn=nil end
        if JumpConn then pcall(function() JumpConn:Disconnect() end); JumpConn=nil end
        if TeleportConn then pcall(function() TeleportConn:Disconnect() end); TeleportConn=nil end
        if CharAddedConn then pcall(function() CharAddedConn:Disconnect() end); CharAddedConn=nil end
    if remoteCacheConn then pcall(function() remoteCacheConn:Disconnect() end); remoteCacheConn=nil end
    if GLOBAL_CONNS then for _,c in ipairs(GLOBAL_CONNS) do pcall(function() c:Disconnect() end) end; GLOBAL_CONNS = {} end
        local hint = CoreGui:FindFirstChild("SpeedStyleUI_Hint"); if hint then pcall(function() hint:Destroy() end) end
    FARM_MON.running = false
    if FARM_MON.thread then pcall(function() task.cancel(FARM_MON.thread) end); FARM_MON.thread=nil end
        print("DEBUG: All systems stopped, destroying GUI...")
        fadeOutAll(function()
            hideMinimizeHint()
            app:Destroy()
        end)
    end
    local function showCloseConfirm()
        if app:FindFirstChild("ConfirmOverlay") then return end
        local overlay = mk("Frame", {Name="ConfirmOverlay", BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.45, Size=UDim2.fromScale(1,1), ZIndex=1000}, app)
        local dlg = mk("Frame", {Size=UDim2.new(0, 360, 0, 140), Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=THEME.CARD, ZIndex=1001}, overlay)
        corner(dlg, 10); stroke(dlg, 1, THEME.BORDER); pad(dlg, 12, 12, 12, 12)
        mk("TextLabel", {BackgroundTransparency=1, Font=FONTS.HB, Text="Close GAG Hub?", TextSize=18, TextColor3=THEME.TEXT, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,24), ZIndex=1002}, dlg)
        mk("TextLabel", {BackgroundTransparency=1, Font=FONTS.B, Text="Are you sure you want to close? All features will stop.", TextWrapped=true, TextSize=14, TextColor3=THEME.MUTED, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,0,0,28), Size=UDim2.new(1,0,0,44), ZIndex=1002}, dlg)
        local btnRow = mk("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,40), Position=UDim2.new(0,0,1,-44), ZIndex=1002}, dlg)
        local btnCancel = mk("TextButton", {AutoButtonColor=false, BackgroundColor3=THEME.BG3, Size=UDim2.new(0.5,-6,1,0), Text="Cancel", TextColor3=THEME.TEXT, Font=FONTS.H, TextSize=14, ZIndex=1003}, btnRow)
        local btnYes    = mk("TextButton", {AutoButtonColor=false, BackgroundColor3=THEME.ACCENT, Size=UDim2.new(0.5,-6,1,0), Position=UDim2.new(0.5,12,0,0), Text="Yes, close", TextColor3=Color3.new(1,1,1), Font=FONTS.H, TextSize=14, ZIndex=1003}, btnRow)
        corner(btnCancel,8); stroke(btnCancel,1,THEME.BORDER); hover(btnCancel,{BackgroundColor3=THEME.BG2},{BackgroundColor3=THEME.BG3})
        corner(btnYes,8); stroke(btnYes,1,THEME.BORDER); hover(btnYes,{BackgroundColor3=Color3.fromRGB(240,90,90)},{BackgroundColor3=THEME.ACCENT})
        btnCancel.MouseButton1Click:Connect(function() overlay:Destroy() end)
        btnYes.MouseButton1Click:Connect(function()
            overlay:Destroy()
            shutdownAndClose()
        end)
    end
    btnMin.MouseButton1Click:Connect(function()
        minimized=true
        showMinimizeHint()
        fadeOutAll(function() app.Enabled=false end)
    end)
    btnClose.MouseButton1Click:Connect(function()
        showCloseConfirm()
    end)
    local rightCtrlConn
    rightCtrlConn = UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.RightControl then
            if minimized then
                app.Enabled=true; fadeInAll(); minimized=false; hideMinimizeHint()
            else
                minimized=true; showMinimizeHint(); fadeOutAll(function() app.Enabled=false end)
            end
        end
    end)
    table.insert(GLOBAL_CONNS, rightCtrlConn)
    CharAddedConn = Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(.1)
        applySpeedValue(SPEED.Enabled and SPEED.Chosen or SPEED.Default)
        if NoClip.Enabled then setNoClip(true) end
        if Fly.Enabled then startFly() end
        if GO.Enabled then GO_Start() end
    end)
end
createLoadingScreen(buildApp)


