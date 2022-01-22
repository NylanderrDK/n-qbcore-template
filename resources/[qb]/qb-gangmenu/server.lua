local QBCore = exports['qb-core']:GetCoreObject()
local Accounts = {}

CreateThread(function()
    Wait(500)
    local result = json.decode(LoadResourceFile(GetCurrentResourceName(), "./accounts.json"))
    if not result then
        return
    end
    for k,v in pairs(result) do
        local k = tostring(k)
        local v = tonumber(v)
        if k and v then
            Accounts[k] = v
        end
    end
end)

QBCore.Functions.CreateCallback('qb-gangmenu:server:GetAccount', function(source, cb, gangname)
    local result = GetAccount(gangname)
    cb(result)
end)

-- Export
function GetAccount(account)
    return Accounts[account] or 0
end

-- Withdraw Money
RegisterServerEvent("qb-gangmenu:server:withdrawMoney")
AddEventHandler("qb-gangmenu:server:withdrawMoney", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local gang = Player.PlayerData.gang.name

    if not Accounts[gang] then
        Accounts[gang] = 0
    end

    if Accounts[gang] >= amount and amount > 0 then
        Accounts[gang] = Accounts[gang] - amount
        Player.Functions.AddMoney("cash", amount)
    else
        TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Not Enough Money"}, 'error')
        return
    end
    SaveResourceFile(GetCurrentResourceName(), "./accounts.json", json.encode(Accounts), -1)
    TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Withdraw Money', 'lightgreen', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully withdrew $' .. amount .. ' (' .. gang .. ')', false)
end)

-- Deposit Money
RegisterServerEvent("qb-gangmenu:server:depositMoney")
AddEventHandler("qb-gangmenu:server:depositMoney", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local gang = Player.PlayerData.gang.name

    if not Accounts[gang] then
        Accounts[gang] = 0
    end

    if Player.Functions.RemoveMoney("cash", amount) then
        Accounts[gang] = Accounts[gang] + amount
    else
        TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Not Enough Money"}, "error")
        return
    end
    SaveResourceFile(GetCurrentResourceName(), "./accounts.json", json.encode(Accounts), -1)
    TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Deposit Money', 'lightgreen', "Successfully deposited $" .. amount .. ' (' .. gang .. ')', false)
end)

RegisterServerEvent("qb-gangmenu:server:addAccountMoney")
AddEventHandler("qb-gangmenu:server:addAccountMoney", function(account, amount)
    if not Accounts[account] then
        Accounts[account] = 0
    end

    Accounts[account] = Accounts[account] + amount
    TriggerClientEvent('qb-gangmenu:client:refreshSociety', -1, account, Accounts[account])
    SaveResourceFile(GetCurrentResourceName(), "./accounts.json", json.encode(Accounts), -1)
end)

RegisterServerEvent("qb-gangmenu:server:removeAccountMoney")
AddEventHandler("qb-gangmenu:server:removeAccountMoney", function(account, amount)
    if not Accounts[account] then
        Accounts[account] = 0
    end

    if Accounts[account] >= amount then
        Accounts[account] = Accounts[account] - amount
    end

    TriggerClientEvent('qb-gangmenu:client:refreshSociety', -1, account, Accounts[account])
    SaveResourceFile(GetCurrentResourceName(), "./accounts.json", json.encode(Accounts), -1)
end)

-- Get Employees
QBCore.Functions.CreateCallback('qb-gangmenu:server:GetEmployees', function(source, cb, gangname)
    local src = source
    local employees = {}
    if not Accounts[gangname] then
        Accounts[gangname] = 0
    end
    local players = exports.oxmysql:executeSync("SELECT * FROM `players` WHERE `gang` LIKE '%".. gangname .."%'")
    if players[1] ~= nil then
        for key, value in pairs(players) do
            local isOnline = QBCore.Functions.GetPlayerByCitizenId(value.citizenid)

            if isOnline then
                employees[#employees+1] = {
                    empSource = isOnline.PlayerData.citizenid,
                    grade = isOnline.PlayerData.gang.grade,
                    level = isOnline.PlayerData.gang.grade.level,
                    isboss = isOnline.PlayerData.gang.isboss,
                    name = isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
                }
            else
                employees[#employees+1] = {
                    empSource = value.citizenid,
                    grade =  json.decode(value.gang).grade,
                    level = json.decode(value.gang).grade.level,
                    isboss = json.decode(value.gang).isboss,
                    name = json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
                }
            end
        end
    end
    cb(employees)
end)

-- Grade Change
RegisterServerEvent('qb-gangmenu:server:updateGrade')
AddEventHandler('qb-gangmenu:server:updateGrade', function(target, grade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Employee = QBCore.Functions.GetPlayerByCitizenId(target)
    if grade == nil then
        TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Invalid grade. Numbers only, with 0 being the lowest grade. What is this, amateur hour?"}, "error", 6000)
        return
    end
    if Player.PlayerData.gang.grade.level >= grade and grade <= Player.PlayerData.gang.grade.level then
        if Employee then
            if Employee.Functions.SetGang(Player.PlayerData.gang.name, grade) then
                TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Gang Grade Changed', 'lightgreen', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' changed grade to ' .. grade .. ' for ' .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Grade Changed Successfully!"}, "success")
                TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, {text="Gang Menu", caption="Your new gang grade is now [" ..grade.."]."}, "success")
            else
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Grade Does Not Exist! We keep it simple around here, 0-10 only!"}, "error")
            end
        else
            local playerGang = '%' .. Player.PlayerData.gang.name .. '%'
            local result = exports.oxmysql:scalarSync('SELECT gang FROM players WHERE citizenid = ? AND gang LIKE ?', {target, playerGang})
            if result then
                gangFinal = checkGang(Player.PlayerData.gang.name, grade)
                if gangFinal ~= false then
                    TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Gang Grade Changed', 'lightgreen', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' changed grade to ' .. gangFinal.grade.name .. ' for '  .. target .. ' (' .. Player.PlayerData.gang.name .. ')', false)
                    TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Grade Changed Successfully!"}, "success")
                    exports.oxmysql:execute('UPDATE players SET gang = ? WHERE citizenid = ?', { json.encode(gangFinal), target })
                else
                    TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Invalid grade. Numbers only, with 0 being the lowest grade. What is this, amateur hour?"}, "error", 6000)
                end
            else
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="This person is not on your payroll"}, "error", 5000)
            end
        end
    else
        TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Unfair Gang Change', 'lightgreen', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' tried to changed grade to ' .. checkGang(Player.PlayerData.gang.name, grade).grade.name .. ' ('.. grade ..') for '  .. target .. ' (' .. Player.PlayerData.gang.name .. ') but failed because they are lower rank than the person or are trying to climb the ladder themselves.', true)
        TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu",caption="You are not authorized to do this. This has been reported to the feds."}, "error", 8000)
    end
end)

-- Fire Employee
RegisterServerEvent('qb-gangmenu:server:fireEmployee')
AddEventHandler('qb-gangmenu:server:fireEmployee', function(target)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Employee = QBCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        if Player.PlayerData.gang.grade.level >= Employee.PlayerData.gang.grade.level then
            if Employee.Functions.SetGang("none", '0') then
                TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Gang Fire', 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu",caption="You have kicked out a member of your organization. We will be sending the records to " .. Player.PlayerData.gang.label .. "'s treasurer and the local charter."}, "error", 10000)
                TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source , {text="Gang Menu", caption="You were released from your gang. Think hard about your decisions and you're gonna realize this ain't the life for you."}, "error", 10000)
            else
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Mail in a video raffle ticket with full details regarding this error."}, "error")
            end
        else
            TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Unfair Firing', 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' tried to fire ('.. target .. ') at (' .. Player.PlayerData.gang.name .. ') but failed because they are lower rank than the person. Something amiss is afoot.', true)
            TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu",caption="You are not authorized to do this. This has been reported to the " .. Player.PlayerData.gang.label .. " treasurer and the government."}, "error", 15000)
        end
    else
        local playerGang = '%' .. Player.PlayerData.gang.name .. '%'
        local result = exports.oxmysql:scalarSync('SELECT gang FROM players WHERE citizenid = ? AND gang LIKE ?', {target, playerGang})
        if result then
            gangFinal = checkGang('none', 0)
            if gangFinal ~= false then
                exports.oxmysql:execute('UPDATE players SET gang = ? WHERE citizenid = ?', { json.encode(gangFinal), target })
                TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Fired Employee', 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' fired ('.. target .. ') at (' .. Player.PlayerData.gang.name .. ')', false)
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu",caption="You have kicked out a member of your organization. We will be sending the records to " .. Player.PlayerData.gang.label .. "'s treasurer and the local charter."}, "error", 10000)
            else
                TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="Something failed. Did you try turning it off and on again?"}, "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="This person is not on your payroll."}, "error", 4000)
        end




    end
end)

-- Recruit Player
RegisterServerEvent('qb-gangmenu:server:giveJob')
AddEventHandler('qb-gangmenu:server:giveJob', function(recruit)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(recruit)
    if Player.PlayerData.gang.isboss == true then
        if Target and Target.Functions.SetGang(Player.PlayerData.gang.name, 0) then
            TriggerClientEvent('QBCore:Notify', src, {text="Gang Menu", caption="You Recruited " .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. " To " .. Player.PlayerData.gang.label .. ""}, "success")
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source , {text="Gang Menu", caption="You've Been Recruited To " .. Player.PlayerData.gang.label .. "!"}, "success")
            TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Gang Recruit', 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully recruited ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
        end
    end
end)

-- Functions

function checkGang(gangName, grade)
    gang = {}
    grade = tostring(grade) or '0'

    if QBCore.Shared.Gangs[gangName] then
        gang.name = gangName
        gang.label = QBCore.Shared.Gangs[gangName].label
        if QBCore.Shared.Gangs[gangName].grades[grade] then
            local ganggrade = QBCore.Shared.Gangs[gangName].grades[grade]
            gang.grade = {}
            gang.grade.name = ganggrade.name
            gang.grade.level = tonumber(grade)
            gang.isboss = ganggrade.isboss or false
        else
            gang.grade = {}
            gang.grade.name = 'Bad Grades'
            gang.grade.level = 0
            gang.isboss = false
        end
    return gang
    end
    return false
end
