--[[
	This file deals with subscribing to sends and receives on ACF's networking library
]]

local Network    = ACF.Networking

Network.Sender   = Network.Sender or {}
Network.Receiver = Network.Receiver or {}

local Sender     = Network.Sender
local Receiver   = Network.Receiver
local isstring   = isstring
local isfunction = isfunction

--- Every time the given variable should be sent, run this function before sending
--- @param Name string The name of the variable
--- @param Function function The function to run
function Network.CreateSender(Name, Function)
	if not isstring(Name) then return end
	if not isfunction(Function) then return end

	Sender[Name] = Function
end

--- Removes the callback attached in Network.CreateSender
--- @param Name string The name of the variable
function Network.RemoveSender(Name)
	if not isstring(Name) then return end

	Sender[Name] = nil
end

--- Every time the given variable will be received, run this function 
--- @param Name string The name of the variable
--- @param Function function The function to run
function Network.CreateReceiver(Name, Function)
	if not isstring(Name) then return end
	if not isfunction(Function) then return end

	Receiver[Name] = Function
end

--- Removes the callback attached in Network.CreateReceiver
--- @param Name string The name of the variable
function Network.RemoveReceiver(Name)
	if not isstring(Name) then return end

	Receiver[Name] = nil
end
