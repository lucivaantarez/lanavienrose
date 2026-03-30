-- =====================================================================
-- lana vie en rose AIO
-- GitHub: lucivaantarez/lanavienrose
-- =====================================================================

local os = require("os")
local io = require("io")

-- Terminal Colors
local CYAN = "\27[36m"
local WHITE = "\27[37m"
local GREEN = "\27[32m"
local RED = "\27[31m"
local RESET = "\27[0m"

local PID_FILE = "/sdcard/.lver_bg_pid"
local BG_SCRIPT_FILE = "/sdcard/.lver_bg.sh"

-- [NEW FIX] Take a snapshot of the perfect terminal state before doing anything
local ORIGINAL_TTY = io.popen("stty -g 2>/dev/null"):read("*l")

local function restore_tty()
    if ORIGINAL_TTY and ORIGINAL_TTY ~= "" then
        os.execute("stty " .. ORIGINAL_TTY .. " 2>/dev/null")
    end
end

-- Custom print function to bypass terminal staircase bug
local function println(str)
    io.write((str or "") .. "\r\n")
end

-- Auto-create 'lver' shortcut in Termux
local function setup_shortcut()
    local shortcut_path = "/data/data/com.termux/files/usr/bin/lver"
    local f = io.open(shortcut_path, "r")
    
    if not f then
        local sf = io.open(shortcut_path, "w")
        if sf then
            sf:write("#!/data/data/com.termux/files/usr/bin/sh\n")
            sf:write("curl -s -f -o /sdcard/Download/main_tmp.lua https://raw.githubusercontent.com/lucivaantarez/lanavienrose/main/main.lua && mv /sdcard/Download/main_tmp.lua /sdcard/Download/main.lua\n")
            sf:write("lua /sdcard/Download/main.lua\n")
            sf:close()
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

-- Check if background service is actually alive
local function is_service_running()
    local pid = get_pid()
    if not pid then return false, "NONE" end

    -- [FIX] Added </dev/null here to prevent su from hijacking the background TTY
    local handle = io.popen("su -c 'kill -0 " .. pid .. " 2>/dev/null && echo ALIVE || echo DEAD' </dev/null")
    local result = handle:read("*a") or ""
    handle:close()

    if result:match("ALIVE") then
        return true, pid
    else
        os.remove(PID_FILE)
        return false, "NONE"
    end
end

-- Safely execute root commands without wrapping UI
local function run_cmd(desc, cmd)
    io.write("  " .. desc .. " ")
    
    local handle = io.popen("su -c '" .. cmd .. " ; echo _DONE_' </dev/null 2>/dev/null")
    local result = handle:read("*a") or ""
    handle:close()

    if result:match("_DONE_") then
        println(GREEN .. "[SUCCESS]" .. RESET)
    else
        println(RED .. "[FAIL]" .. RESET)
    end
end

-- Helper to draw the table perfectly every time (Max width: 50)
local function draw_table_row(name, val, is_green)
    local name_pad = name .. string.rep(" ", 16 - #name)
    local color = is_green == nil and WHITE or (is_green and GREEN or RED)
    local val_pad = string.rep(" ", 22 - #val)
    println(CYAN .. "| " .. WHITE .. name_pad .. CYAN .. " | " .. color .. "[ " .. val .. " ]" .. val_pad .. CYAN .. "|" .. RESET)
end

-- ============================================
-- CORE LOGIC
-- ============================================

local function start_auto_protector()
    local is_running, _ = is_service_running()
    if is_running then
        println("  [~] Auto-protector already running.  " .. GREEN .. "[OK]" .. RESET)
        return
    end

    local bg_logic = [[
#!/system/bin/sh
trap "rm -f ]] .. PID_FILE .. [[; exit" TERM INT HUP
while true; do
    su -c 'for p in /proc/[0-9]*; do
        if [ -f "$p/cmdline" ] && grep -q "com.roblox" "$p/cmdline" 2>/dev/null; then
            echo -1000 > "$p/oom_score_adj" 2>/dev/null
        fi
    done' </dev/null
    sleep 120
done
]]
    
    local f = io.open(BG_SCRIPT_FILE, "w")
    if f then
        f:write(bg_logic)
        f:close()
    else
        println("  [~] Starting auto-protector...       " .. RED .. "[FAIL]" .. RESET)
        return
    end

    os.execute("termux-wake-lock 2>/dev/null")

    local handle = io.popen("su -c 'nohup sh " .. BG_SCRIPT_FILE .. " </dev/null >/dev/null 2>&1 & echo $!'")
    local new_pid = handle:read("*l")
    handle:close()

    if new_pid and new_pid ~= "" then
        os.execute("echo " .. new_pid .. " > " .. PID_FILE)
        println("  [~] Starting auto-protector...       " .. GREEN .. "[SUCCESS]" .. RESET)
    else
        println("  [~] Starting auto-protector...       " .. RED .. "[FAIL]" .. RESET)
    end
end

local function run_optimization()
    println("\n" .. CYAN .. "Executing System Optimization..." .. RESET)
    println("--------------------------------------------------")
    
    run_cmd("[~] Closing background apps...", "am force-stop com.google.android.youtube ; am force-stop com.android.chrome ; am force-stop com.google.android.apps.maps")
    run_cmd("[~] Stopping system services...", "stop logd ; stop statsd ; stop mdnsd")
    run_cmd("[~] Turning off UI animations...", "settings put global window_animation_scale 0 ; settings put global transition_animation_scale 0 ; settings put global animator_duration_scale 0")
    run_cmd("[~] Muting system sounds...", "settings put global heads_up_notifications_enabled 0 ; settings put system haptic_feedback_enabled 0")
    run_cmd("[~] Disabling Play Store...", "pm disable-user --user 0 com.android.vending")
    
    start_auto_protector()
    
    println("--------------------------------------------------")
    println(CYAN .. "Optimization complete. Press Enter to return." .. RESET)
    
    restore_tty() -- [NEW FIX] Restores keyboard functionality
    io.read()
end

local function stop_auto_protector()
    println("\n" .. CYAN .. "Stopping Auto-Protector..." .. RESET)
    local is_running, pid = is_service_running()
    
    if is_running then
        os.execute("su -c 'kill -9 " .. pid .. " 2>/dev/null'")
        os.remove(PID_FILE)
        os.remove(BG_SCRIPT_FILE)
        run_cmd("[~] Terminating background daemon...", "echo 1") 
    else
        println("  [~] Auto-Protector is already stopped. " .. GREEN .. "[OK]" .. RESET)
    end
    println("\nPress Enter to return to menu.")
    
    restore_tty() -- [NEW FIX] Restores keyboard functionality
    io.read()
end

local function clear_ram_now()
    println("\n" .. CYAN .. "Flushing System RAM..." .. RESET)
    run_cmd("[~] Dropping memory caches...", "echo 3 > /proc/sys/vm/drop_caches")
    println("\nPress Enter to return to menu.")
    
    restore_tty() -- [NEW FIX] Restores keyboard functionality
    io.read()
end

-- ============================================
-- MAIN MENU LOOP
-- ============================================
setup_shortcut()

while true do
    clear_screen()
    
    local running, pid = is_service_running()
    local status_val = running and "RUNNING" or "STOPPED"
    local pid_val = pid or "NONE"
    
    println(CYAN .. "==================================================" .. RESET)
    println(WHITE .. "lana vie en rose AIO v1.0.0" .. RESET)
    println(CYAN .. "==================================================" .. RESET)
    println("")
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    println(CYAN .. "| " .. WHITE .. "Module          " .. CYAN .. " | " .. WHITE .. "Status                 " .. CYAN .. "|" .. RESET)
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    draw_table_row("Auto-Protector", status_val, running)
    draw_table_row("Background PID", pid_val, nil)
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    println("")
    println(WHITE .. "Main Menu:" .. RESET)
    println(CYAN .. "  (Type 'lver' anywhere in Termux to open this!)" .. RESET)
    println("")
    println("  " .. CYAN .. "[1]" .. RESET .. " - Optimize System & Start Auto-Protector")
    println("  " .. CYAN .. "[2]" .. RESET .. " - Stop Auto-Protector")
    println("  " .. CYAN .. "[3]" .. RESET .. " - Clear RAM Now")
    println("")
    println("  " .. CYAN .. "[0]" .. RESET .. " - Exit")
    println("")
    io.write("Choose an option: ")
    
    restore_tty() -- [NEW FIX] Guarantees option selection works
    local choice = io.read()
    
    if choice == "1" then
        run_optimization()
    elseif choice == "2" then
        stop_auto_protector()
    elseif choice == "3" then
        clear_ram_now()
    elseif choice == "0" then
        clear_screen()
        restore_tty()
        os.exit()
    end
end
