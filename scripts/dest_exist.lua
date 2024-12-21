--[[
Author: Sreekanth Balu
Date: 2024-12-21
Email: balusreekanth@gmail.com
Description: Lua script to handle session-based callbacks, interact with SQLite 
             and PostgreSQL databases, and manage call origination in FreeSWITCH.
--]]

-- Set defaults
local max_tries = 3
local digit_timeout = 5000

local destination_number = argv[1]
local caller_number = argv[2]
local domain_name = argv[3]
local db_path = "/var/lib/freeswitch/db/sofia_reg_internal.db"

-- Include config.lua
require "resources.functions.config"

-- Require the LuaSQL module
local luasql = require "luasql.sqlite3"

-- Answer the session if it's ready
if session:ready() then
    session:execute("set", "ringback=$${us-ring}")
    session:answer()
end

-- Log the incoming destination number
session:consoleLog("INFO", "Checking activity for destination number: " .. (destination_number or "nil"))

-- Get domain information
if session:ready() then
    domain_name = domain_name or session:getVariable("domain_name") or session:getVariable("sip_auth_realm")
end

-- Set the sounds path for language, dialect, and voice
local default_language = session:getVariable("default_language") or "en"
local default_dialect = session:getVariable("default_dialect") or "us"
local default_voice = session:getVariable("default_voice") or "callie"
local sounds_dir = session:getVariable("sounds_dir")

-- Connect to the SQLite database
local env = luasql.sqlite3()
local conn, err = env:connect(db_path)
if not conn then
    session:consoleLog("ERROR", "Database connection failed: " .. (err or "unknown error"))
    session:hangup("NORMAL_CLEARING")
    return
end

-- Query the database for active session
local query = string.format("SELECT uuid FROM sip_dialogs WHERE contact_user = '%s' LIMIT 1", destination_number)
local cursor, query_err = conn:execute(query)
if not cursor then
    session:consoleLog("ERROR", "Database query failed: " .. (query_err or "unknown error"))
    conn:close()
    env:close()
    session:hangup("NORMAL_CLEARING")
    return
end

-- Fetch the query result
local result = cursor:fetch({}, "a")
local dialog_uuid = result and result.uuid or nil

cursor:close()
conn:close()
env:close()

if dialog_uuid then
    session:consoleLog("INFO", "Active session found for extension: " .. destination_number .. ", UUID: " .. dialog_uuid)
    session:setVariable("sip_dialogs_status", "1")
    session:sleep(100)

    -- Play and get digits
    local min_digits = 1
    local max_digits = 1
    local digits = session:playAndGetDigits(
        min_digits,
        max_digits,
        max_tries,
        digit_timeout,
        "#",
        sounds_dir .. "/" .. default_language .. "/" .. default_dialect .. "/" .. default_voice .. "/ivr/busy_ivr.wav",
        "",
        "\\d+"
    )

    if digits == "1" then
        session:hangup()
        local Database = require "resources.functions.database"
        local dbh = Database.new('system')

        local check_sql = "SELECT 1 FROM v_busy_extensions WHERE dialog_uuid = :dialog_uuid LIMIT 1"
        local check_params = { dialog_uuid = dialog_uuid }
        local check_result = dbh:first_row(check_sql, check_params)

        local sql
        if check_result then
            sql = [[
                UPDATE v_busy_extensions
                SET timestamp = :timestamp, status = :status
                WHERE dialog_uuid = :dialog_uuid
            ]]
        else
            sql = [[
                INSERT INTO v_busy_extensions (from_extension, to_extension, timestamp, status, dialog_uuid, domainname)
                VALUES (:from_extension, :to_extension, :timestamp, :status, :dialog_uuid, :domainname)
            ]]
        end

        local params = {
            from_extension = destination_number,
            to_extension = caller_number,
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            status = "pending",
            dialog_uuid = dialog_uuid,
            domainname = domain_name
        }

        freeswitch.consoleLog("NOTICE", "[call-back] SQL: " .. sql .. "; params: " .. require("resources.functions.lunajson").encode(params) .. "\n")
        dbh:query(sql, params)
    else
        session:hangup("NORMAL_CLEARING")
    end
else
    session:consoleLog("INFO", "No active session found for extension: " .. destination_number)
    session:setVariable("sip_dialogs_status", "0")
    session:sleep(500)
end