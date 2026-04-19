local _, ns = ...

ns.PREFIX = "PartyPulse"
ns.comm = {}

local callbacks = {}

function ns.comm.OnReceive(cb)
    callbacks[#callbacks + 1] = cb
end

function ns.comm.Send(msg)
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(ns.PREFIX, msg, channel)
end

function ns.comm.SendWhisper(msg, target)
    if not target then return end
    C_ChatInfo.SendAddonMessage(ns.PREFIX, msg, "WHISPER", target)
end

function ns.comm.Init()
    C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
end

function ns.comm.Handle(prefix, text, _, sender)
    if prefix ~= ns.PREFIX then return end
    for i = 1, #callbacks do
        callbacks[i](text, sender)
    end
end
