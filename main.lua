-- =====================================================================
-- lana vie en rose AIO
-- GitHub: lucivaantarez/lanavienrose
-- =====================================================================

local os = require("os")
local io = require("io")

-- Terminal Colors (WinterHub Default Aesthetic)
local CYAN = "\27[36m"
local WHITE = "\27[37m"
local GREEN = "\27[32m"
local RED = "\27[31m"
local RESET = "\27[0m"

local PID_FILE = "/sdcard/.lver_bg_pid"
local BG_SCRIPT_FILE = "/sdcard/.lver_bg.sh"

-- Auto-create 'lver' shortcut in Termux
local function setup_shortcut()
    local shortcut_path = "/data/data/com.termux/files/usr/bin/lver"
    local f = io.open(shortcut_path, "r")
    
    -- If the shortcut doesn't exist, create it silently
    if not f then
        local sf = io.open(shortcut_path, "w")
        if sf then
            sf:write("#!/system/bin/sh\nlua /sdcard/Download/main.lua\n")
            sf:close()
            -- Make it executable
            os.execute("chmod +x " .. shortcut_path)
        end
    else
        f:close()
    end
end

-- Clear terminal
local function clear_screen()
    os.execute("clear")
end

-- Get current background PID
local function get_pid()
    local f = io.open(PID_FILE, "r")
    if not f then return nil end
    local pid = f:read("*l")
    f:close()
    if pid == "" then return nil end
    return pid
end

-- Check if background service is actually alive (Hydra/Ghost Bug Fix)
local function is_service_running()
    local pid = get_pid()
    if not pid then return false, "NONE" end

    -- Ping the process to see if it still exists
    local handle = io.popen("su -c 'kill -0 " .. pid .. " 2>/dev/null && echo ALIVE || echo DEAD'")
    local result = handle:read("*a") or ""
    handle:close()

    if result:match("ALIVE") then
        return true, pid
    else
        -- Clean up dead ghost PID
        os.remove(PID_FILE)
        return false, "NONE"
    end
end

-- Safely execute root commands and check status
local function run_cmd(desc, cmd)
    -- Formatting output to align perfectly
    local formatted_desc = string.format("  %-45s", desc)
    io.write(formatted_desc)
    
    local handle = io.popen("su -c '" .. cmd .. " && echo _SUCCESS_ || echo _FAIL_' 2>/dev/null")
    local result = handle:read("*a") or ""
    handle:close()

    if result:match("_SUCCESS_") then
        print(GREEN .. "[SUCCESS]" .. RESET)
    else
        print(RED .. "[FAIL]" .. RESET)
    end
end

-- ============================================
-- CORE LOGIC
-- ============================================

local function start_auto_protector()
    local is_running, _ = is_service_running()
    if is_running then
        print("  [~] Auto-protector is already running. Skipping duplicate spawn. " .. GREEN .. "[OK]" .. RESET)
        return
    end

    -- Write background logic to a temp file to avoid string escaping bugs
    local bg_logic = [[
#!/system/bin/sh
trap "rm -f ]] .. PID_FILE .. [[; exit" TERM INT HUP
while true; do
    su -c 'for p in /proc/[0-9]*; do
        if [ -f "$p/cmdline" ] && grep -q "com.roblox" "$p/cmdline" 2>/dev/null; then
            # Sisyphus Fix: Unlock, write -1000, then permanently lock as Read-Only
            chmod 666 "$p/oom_score_adj" 2>/dev/null
            echo -1000 > "$p/oom_score_adj" 2>/dev/null
            chmod 444 "$p/oom_score_adj" 2>/dev/null
        fi
    done'
    sleep 120
done
]]
    
    local f = io.open(BG_SCRIPT_FILE, "w")
    if f then
        f:write(bg_logic)
        f:close()
    else
        print("  [~] Starting background auto-protector...          " .. RED .. "[FAIL]" .. RESET)
        return
    end

    -- Enable Wakelock
    os.execute("su -c 'termux-wake-lock 2>/dev/null'")

    -- Spawn the daemon
    local handle = io.popen("su -c 'setsid sh " .. BG_SCRIPT_FILE .. " >/dev/null 2>&1 & echo $!'")
    local new_pid = handle:read("*l")
    handle:close()

    if new_pid and new_pid ~= "" then
        os.execute("echo " .. new_pid .. " > " .. PID_FILE)
        print("  [~] Starting background auto-protector...          " .. GREEN .. "[SUCCESS]" .. RESET)
    else
        print("  [~] Starting background auto-protector...          " .. RED .. "[FAIL]" .. RESET)
    end
end

local function run_optimization()
    print("\n" .. CYAN .. "Executing System Optimization..." .. RESET)
    print("------------------------------------------------------------------------")
    
    run_cmd("[~] Closing heavy background apps...", "am force-stop com.google.android.youtube && am force-stop com.android.chrome && am force-stop com.google.android.apps.maps")
    run_cmd("[~] Stopping unnecessary system services...", "stop logd && stop statsd && stop mdnsd")
    run_cmd("[~] Turning off device animations...", "settings put global window_animation_scale 0 && settings put global transition_animation_scale 0 && settings put global animator_duration_scale 0")
    run_cmd("[~] Muting sounds and notifications...", "settings put global heads_up_notifications_enabled 0 && settings put system haptic_feedback_enabled 0")
    run_cmd("[~] Disabling Google Play Store...", "pm disable-user --user 0 com.android.vending")
    
    start_auto_protector()
    
    print("------------------------------------------------------------------------")
    print(CYAN .. "Optimization complete. Press Enter to return to menu." .. RESET)
    io.read()
end

local function stop_auto_protector()
    print("\n" .. CYAN .. "Stopping Auto-Protector..." .. RESET)
    local is_running, pid = is_service_running()
    
    if is_running then
        os.execute("su -c 'kill -9 " .. pid .. " 2>/dev/null'")
        os.remove(PID_FILE)
        os.remove(BG_SCRIPT_FILE)
        print("  [~] Background daemon terminated...                " .. GREEN .. "[SUCCESS]" .. RESET)
    else
        print("  [~] Auto-Protector is already stopped.             " .. GREEN .. "[OK]" .. RESET)
    end
    print("\nPress Enter to return to menu.")
    io.read()
end

local function clear_ram_now()
    print("\n" .. CYAN .. "Flushing System RAM..." .. RESET)
    run_cmd("[~] Dropping memory caches...", "echo 3 > /proc/sys/vm/drop_caches")
    print("\nPress Enter to return to menu.")
    io.read()
end

-- ============================================
-- MAIN MENU LOOP
-- ============================================
setup_shortcut()

while true do
    clear_screen()
    
    local running, pid = is_service_running()
    local status_text = running and (GREEN .. "RUNNING" .. RESET) or (RED .. "STOPPED" .. RESET)
    local pid_text = pid
    
    print(CYAN .. "========================================================================" .. RESET)
    print(WHITE .. "lana vie en rose AIO v1.0.0" .. RESET)
    print(CYAN .. "========================================================================" .. RESET)
    print("")
    print(CYAN .. "+----------------------------------------------------------------------+" .. RESET)
    print(CYAN .. "| " .. WHITE .. string.format("%-17s", "Module") .. CYAN .. " | " .. WHITE .. string.format("%-48s", "Status") .. CYAN .. " |" .. RESET)
    print(CYAN .. "+----------------------------------------------------------------------+" .. RESET)
    print(CYAN .. "| " .. WHITE .. string.format("%-17s", "Auto-Protector") .. CYAN .. " | [ " .. status_text .. CYAN .. string.rep(" ", 48 - 4 - 7) .. " ] |" .. RESET)
    print(CYAN .. "| " .. WHITE .. string.format("%-17s", "Background PID") .. CYAN .. " | [ " .. WHITE .. string.format("%-44s", pid_text) .. CYAN .. " ] |" .. RESET)
    print(CYAN .. "+----------------------------------------------------------------------+" .. RESET)
    print("")
    print(WHITE .. "Main Menu:" .. RESET)
    print(CYAN .. "  (Type 'lver' anywhere in Termux to open this menu!)" .. RESET)
    print("")
    print("  " .. CYAN .. "[1]" .. RESET .. " - Optimize System & Start Auto-Protector")
    print("  " .. CYAN .. "[2]" .. RESET .. " - Stop Auto-Protector")
    print("  " .. CYAN .. "[3]" .. RESET .. " - Clear RAM Now")
    print("")
    print("  " .. CYAN .. "[0]" .. RESET .. " - Exit")
    print("")
    io.write("Choose an option: ")
    
    local choice = io.read()
    
    if choice == "1" then
        run_optimization()
    elseif choice == "2" then
        stop_auto_protector()
    elseif choice == "3" then
        clear_ram_now()
    elseif choice == "0" then
        clear_screen()
        os.exit()
    end
end
