local _, ns = ...

ns.PREFIX = "PartyPulse"
ns.comm = {}

local callbacks = {}

function ns.comm.OnReceive(cb)
    callbacks[#callbacks + 1] = cb
end

function ns.comm.Send(msg)
    -- Cross-realm instance groups (M+, LFG, LFR) only deliver addon messages
    -- on the INSTANCE_CHAT channel; PARTY/RAID silently drops them for
    -- cross-realm teammates. Prefer INSTANCE_CHAT whenever we're in an
    -- instance group.
    local channel
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    else
        return
    end
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
