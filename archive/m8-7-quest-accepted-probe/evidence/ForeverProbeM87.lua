
ForeverProbeM87DB = {
["sessions"] = {
{
["probe_version"] = "m8-7-probe-0.1",
["quest_log_count_source"] = "C_QuestLog.GetNumQuestLogEntries",
["build_date"] = "Sep 29 2026",
["registration"] = {
["QUEST_REMOVED"] = "registered",
["QUEST_ACCEPTED"] = "registered",
["UNIT_QUEST_LOG_CHANGED"] = "registered",
["QUEST_DETAIL"] = "registered",
["QUEST_TURNED_IN"] = "registered",
["QUEST_ACCEPT_CONFIRM"] = "registered",
["QUEST_LOG_UPDATE"] = "registered",
},
["started_wallclock"] = 1790742109,
["hooks"] = {
["C_QuestLog.AbandonQuest"] = "installed",
["AbandonQuest"] = "failed: hooksecurefunc(): AbandonQuest is not a function",
["AcceptQuest"] = "installed",
["SetAbandonQuest"] = "failed: hooksecurefunc(): SetAbandonQuest is not a function",
},
["quest_log_count_at_start"] = 10,
["events"] = {
{
["hook"] = "C_QuestLog.AbandonQuest",
["kind"] = "hook",
["t"] = 1162891.055,
["seq"] = 1,
["quest_log_count"] = 10,
},
{
["args"] = {
{
["value"] = "player",
["type"] = "string",
},
["n"] = 1,
},
["t"] = 1162891.399,
["kind"] = "event",
["seq"] = 2,
["event"] = "UNIT_QUEST_LOG_CHANGED",
},
{
["kind"] = "event",
["args"] = {
{
["value"] = 92421,
["type"] = "number",
},
{
["value"] = false,
["type"] = "boolean",
},
["n"] = 2,
},
["event"] = "QUEST_REMOVED",
["t"] = 1162891.399,
["seq"] = 3,
["quest_log_count"] = 9,
},
{
["args"] = {
["n"] = 0,
},
["t"] = 1162891.417,
["kind"] = "event",
["seq"] = 4,
["event"] = "QUEST_LOG_UPDATE",
},
},
["game_version"] = "1.60.1",
["toc_version"] = 16001,
["started_t"] = 1162649.674,
["counts"] = {
["QUEST_LOG_UPDATE"] = 12,
["QUEST_REMOVED"] = 1,
["hook:C_QuestLog.AbandonQuest"] = 1,
["UNIT_QUEST_LOG_CHANGED"] = 1,
},
["build"] = "70124",
},
{
["probe_version"] = "m8-7-probe-0.1",
["quest_log_count_source"] = "C_QuestLog.GetNumQuestLogEntries",
["build_date"] = "Sep 29 2026",
["registration"] = {
["QUEST_REMOVED"] = "registered",
["UNIT_QUEST_LOG_CHANGED"] = "registered",
["QUEST_ACCEPTED"] = "registered",
["QUEST_ACCEPT_CONFIRM"] = "registered",
["QUEST_TURNED_IN"] = "registered",
["QUEST_DETAIL"] = "registered",
["QUEST_LOG_UPDATE"] = "registered",
},
["started_wallclock"] = 1790742373,
["hooks"] = {
["C_QuestLog.AbandonQuest"] = "installed",
["AbandonQuest"] = "failed: hooksecurefunc(): AbandonQuest is not a function",
["AcceptQuest"] = "installed",
["SetAbandonQuest"] = "failed: hooksecurefunc(): SetAbandonQuest is not a function",
},
["quest_log_count_at_start"] = 9,
["events"] = {
{
["seq"] = 1,
["title_text"] = "The Book of Ur",
["t"] = 1162967.235,
["args"] = {
{
["value"] = 0,
["type"] = "number",
},
["n"] = 1,
},
["get_quest_id"] = 1013,
["kind"] = "event",
["event"] = "QUEST_DETAIL",
["quest_log_count"] = 9,
},
{
["seq"] = 2,
["hook"] = "AcceptQuest",
["t"] = 1162967.819,
["args"] = {
["n"] = 0,
},
["title_text"] = "",
["kind"] = "hook",
["get_quest_id"] = 0,
["quest_log_count"] = 9,
},
{
["args"] = {
{
["value"] = "player",
["type"] = "string",
},
["n"] = 1,
},
["seq"] = 3,
["kind"] = "event",
["event"] = "UNIT_QUEST_LOG_CHANGED",
["t"] = 1162968.213,
},
{
["seq"] = 4,
["quest_log_count_source"] = "C_QuestLog.GetNumQuestLogEntries",
["t"] = 1162968.213,
["args"] = {
{
["value"] = 1013,
["type"] = "number",
},
["n"] = 1,
},
["quest_log_count"] = 11,
["kind"] = "event",
["event"] = "QUEST_ACCEPTED",
["resolved"] = {
{
["value"] = 1013,
["is_on_quest"] = true,
["log_index_for_quest_id"] = 7,
["title_for_quest_id"] = "The Book of Ur",
},
},
},
{
["args"] = {
["n"] = 0,
},
["seq"] = 5,
["kind"] = "event",
["event"] = "QUEST_LOG_UPDATE",
["t"] = 1162968.228,
},
{
["args"] = {
["n"] = 0,
},
["seq"] = 6,
["kind"] = "event",
["event"] = "QUEST_LOG_UPDATE",
["t"] = 1162968.26,
},
{
["seq"] = 7,
["title_text"] = "Light's Justice",
["t"] = 1163034.361,
["args"] = {
{
["value"] = 0,
["type"] = "number",
},
["n"] = 1,
},
["get_quest_id"] = 92421,
["kind"] = "event",
["event"] = "QUEST_DETAIL",
["quest_log_count"] = 11,
},
{
["seq"] = 8,
["hook"] = "AcceptQuest",
["t"] = 1163034.961,
["args"] = {
["n"] = 0,
},
["title_text"] = "",
["kind"] = "hook",
["get_quest_id"] = 0,
["quest_log_count"] = 11,
},
{
["args"] = {
{
["value"] = "player",
["type"] = "string",
},
["n"] = 1,
},
["seq"] = 9,
["kind"] = "event",
["event"] = "UNIT_QUEST_LOG_CHANGED",
["t"] = 1163035.348,
},
{
["seq"] = 10,
["quest_log_count_source"] = "C_QuestLog.GetNumQuestLogEntries",
["t"] = 1163035.348,
["args"] = {
{
["value"] = 92421,
["type"] = "number",
},
["n"] = 1,
},
["quest_log_count"] = 12,
["kind"] = "event",
["event"] = "QUEST_ACCEPTED",
["resolved"] = {
{
["value"] = 92421,
["is_on_quest"] = true,
["log_index_for_quest_id"] = 4,
["title_for_quest_id"] = "Light's Justice",
},
},
},
{
["args"] = {
["n"] = 0,
},
["seq"] = 11,
["kind"] = "event",
["event"] = "QUEST_LOG_UPDATE",
["t"] = 1163035.357,
},
},
["game_version"] = "1.60.1",
["toc_version"] = 16001,
["started_t"] = 1162913.553,
["counts"] = {
["UNIT_QUEST_LOG_CHANGED"] = 2,
["hook:AcceptQuest"] = 2,
["QUEST_ACCEPTED"] = 2,
["QUEST_DETAIL"] = 2,
["QUEST_LOG_UPDATE"] = 12,
},
["build"] = "70124",
},
},
}
