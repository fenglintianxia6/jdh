-- /hs 触发显示上屏历史
--  recognizer/patterns/+: 
--       history: "^(/hs|hisz)$"                   # 上屏历史
local T = {}
require("tools/metatable")
local reload_env = require("tools/env_api")

local function is_candidate_in_type(cand, excluded_types)
    local cs = cand:get_genuines()
    for _, c in pairs(cs) do
        if table.find_index(excluded_types, c.type) then
            return true
        end
    end
    return false
end

function T.init(env)
    reload_env(env)
    env.history_list = {}
    local config = env.engine.schema.config
    local history_num_max = config:get_string("history" .. "/history_num_max") or 30
    local excluded_types = env:Config_get("history" .. "/excluded_types") or {}
    if #env.history_list >= tonumber(history_num_max) then
        table.remove(env.history_list, 1)
    end
    env.notifier_commit_history = env.engine.context.commit_notifier:connect(function(ctx)
        local cand = ctx:get_selected_candidate()
        if cand and not is_candidate_in_type(cand, excluded_types) then
            table.insert(env.history_list, cand)
        end
    end)
end

function T.fini(env)
    env.notifier_commit_history:disconnect()
end

function T.func(input, seg, env)
    local config = env.engine.schema.config
    local composition = env.engine.context.composition
    if (composition:empty()) then return end
    if #env.history_list < 1 then return end
    local segment = composition:back()
    local trigger_prefix = config:get_string("history" .. "/prefix") or "/hs"
    local prompt = config:get_string("history" .. "/tips") or "上屏历史"
    if seg:has_tag("history") or (input == trigger_prefix) then
        segment.prompt = "〔" .. prompt .. "〕"
        for i = #env.history_list, 1, -1 do
            local cand = Candidate("history", seg.start, seg._end, env.history_list[i].text, "")
            ---@diagnostic disable-next-line: redundant-parameter
            local cand_uniq = cand:to_uniquified_candidate(cand.type, cand.text, cand.comment)
            cand_uniq.quality = 999
            yield(cand_uniq)
        end
    end
end

return T
