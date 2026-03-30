-- =====================================================================
-- lana vie en rose AIO
-- GitHub: lucivaantarez/lanavienrose
-- Theme: The Saturnity Vibe
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

-- Take a snapshot of the perfect terminal state before doing anything
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

-- Get current background PID natively via Lua
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

    local handle = io.popen("kill -0 " .. pid .. " 2>/dev/null && echo ALIVE || echo DEAD")
    local result = handle:read("*a") or ""
    handle:close()

    if result:match("ALIVE") then
        return true, pid
    else
        os.remove(PID_FILE)
        return false, "NONE"
    end
end

-- Get live CPU Usage (%) and Frequency (GHz)
local function get_cpu_info()
    local function read_stat()
        local f = io.open("/proc/stat", "r")
        if not f then return 0, 0 end
        local line = f:read("*l")
        f:close()
        if not line or not line:match("^cpu ") then return 0, 0 end
        
        local total, idle = 0, 0
        local col = 1
        for val in line:gmatch("%d+") do
            local v = tonumber(val)
            total = total + v
            if col == 4 or col == 5 then
                idle = idle + v
            end
            col = col + 1
        end
        return total, idle
    end

    local t1, i1 = read_stat()
    os.execute("sleep 0.5") 
    local t2, i2 = read_stat()
    
    local usage_str = "??%"
    local total_diff = t2 - t1
    local idle_diff = i2 - i1
    
    if total_diff > 0 then
        local usage = math.floor((total_diff - idle_diff) / total_diff * 100)
        if usage < 0 then usage = 0 end
        if usage > 100 then usage = 100 end
        usage_str = tostring(usage) .. "%"
    end

    local ghz_str = ""
    local freq_file = io.open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", "r")
    if freq_file then
        local khz = freq_file:read("*n")
        freq_file:close()
        if khz and tonumber(khz) > 0 then
            local ghz = tonumber(khz) / 1000000
            ghz_str = string.format(" @ %.2f GHz", ghz)
        end
    end

    return usage_str .. ghz_str
end

-- Safely execute root commands without wrapping UI
local function run_cmd(desc, cmd)
    io.write("  " .. desc .. " ")
    
    -- Pad spaces so [SUCCESS] perfectly aligns on the right edge
    local pad_len = 39 - #desc
    if pad_len > 0 then io.write(string.rep(" ", pad_len)) end
    
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
        println("  [~] Saturnity ward is already active." .. GREEN .. " [OK]" .. RESET)
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
    done' </dev/null 2>/dev/null
    sleep 120
done
]]
    
    local f = io.open(BG_SCRIPT_FILE, "w")
    if f then
        f:write(bg_logic)
        f:close()
    else
        println("  [~] Casting the Saturnity ward...    " .. RED .. "[FAIL]" .. RESET)
        return
    end

    os.execute("termux-wake-lock 2>/dev/null")

    local handle = io.popen("sh " .. BG_SCRIPT_FILE .. " </dev/null >/dev/null 2>&1 & echo $!")
    local new_pid = handle:read("*l")
    handle:close()

    if new_pid and new_pid ~= "" then
        local pf = io.open(PID_FILE, "w")
        if pf then
            pf:write(new_pid .. "\n")
            pf:close()
        end
        println("  [~] Casting the Saturnity ward...    " .. GREEN .. "[SUCCESS]" .. RESET)
    else
        println("  [~] Casting the Saturnity ward...    " .. RED .. "[FAIL]" .. RESET)
    end
end

local function run_optimization()
    println("\n" .. CYAN .. "Initiating Orbital Optimization..." .. RESET)
    println("--------------------------------------------------")
    
    run_cmd("[~] Eclipsing stray background signals...", "am force-stop com.google.android.youtube ; am force-stop com.android.chrome ; am force-stop com.google.android.apps.maps")
    run_cmd("[~] Quieting the internal system orbit...", "stop logd ; stop statsd ; stop mdnsd")
    run_cmd("[~] Creating a zero-gravity soundscape...", "settings put global heads_up_notifications_enabled 0 ; settings put system haptic_feedback_enabled 0")
    run_cmd("[~] Detaching from the Google network...", "pm disable-user --user 0 com.android.vending")
    
    start_auto_protector()
    
    println("--------------------------------------------------")
    println(CYAN .. "Orbit stabilized. Press Enter to return." .. RESET)
    
    restore_tty() 
    io.read()
end

local function stop_auto_protector()
    println("\n" .. CYAN .. "Dissolving Saturnity Ward..." .. RESET)
    local is_running, pid = is_service_running()
    
    if is_running then
        os.execute("kill -9 " .. pid .. " 2>/dev/null")
        os.remove(PID_FILE)
        os.remove(BG_SCRIPT_FILE)
        run_cmd("[~] Dissolving the Saturnity ward...", "echo 1") 
    else
        println("  [~] Saturnity ward is already down.  " .. GREEN .. "[OK]" .. RESET)
    end
    println("\nPress Enter to return to menu.")
    
    restore_tty() 
    io.read()
end

local function clear_ram_now()
    println("\n" .. CYAN .. "Flushing Stardust Memory..." .. RESET)
    run_cmd("[~] Flushing stardust memory cache...", "echo 3 > /proc/sys/vm/drop_caches")
    println("\nPress Enter to return to menu.")
    
    restore_tty() 
    io.read()
end

local function run_debloater()
    println("\n" .. CYAN .. "Executing Void Debloater..." .. RESET)
    println("--------------------------------------------------")
    
    run_cmd("[~] Banishing Chrome to the void...", "pm disable-user --user 0 com.android.chrome")
    run_cmd("[~] Banishing YouTube to the void...", "pm disable-user --user 0 com.google.android.youtube")
    run_cmd("[~] Banishing Maps to the void...", "pm disable-user --user 0 com.google.android.apps.maps")
    run_cmd("[~] Banishing Photos to the void...", "pm disable-user --user 0 com.google.android.apps.photos")
    run_cmd("[~] Banishing Google App to the void...", "pm disable-user --user 0 com.google.android.googlequicksearchbox")
    
    println("--------------------------------------------------")
    println(CYAN .. "Debloat complete. Targets frozen in the void." .. RESET)
    println(CYAN .. "Press Enter to return to menu." .. RESET)
    
    restore_tty() 
    io.read()
end

local function lock_cpu_performance()
    println("\n" .. CYAN .. "Locking CPU to Orbital Maximum..." .. RESET)
    println("--------------------------------------------------")
    
    run_cmd("[~] Igniting orbital cores to max...", "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo 'performance' > $cpu 2>/dev/null; done")
    
    println("--------------------------------------------------")
    println(CYAN .. "CPU cores ignited. Press Enter to return." .. RESET)
    
    restore_tty() 
    io.read()
end

-- ============================================
-- MAIN MENU LOOP
-- ============================================
setup_shortcut()

while true do
    clear_screen()
    
    local cpu_val = get_cpu_info()
    local running, pid = is_service_running()
    local status_val = running and "ACTIVE" or "OFFLINE"
    local pid_val = pid or "NONE"
    
    println(CYAN .. "==================================================" .. RESET)
    println(WHITE .. "lana vie en rose AIO v1.0.0" .. RESET)
    println(CYAN .. "==================================================" .. RESET)
    println("")
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    println(CYAN .. "| " .. WHITE .. "Module          " .. CYAN .. " | " .. WHITE .. "Status                 " .. CYAN .. "|" .. RESET)
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    draw_table_row("Saturnity Ward", status_val, running)
    draw_table_row("Background PID", pid_val, nil)
    draw_table_row("CPU Monitor", cpu_val, nil)
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    println("")
    println(WHITE .. "Main Menu:" .. RESET)
    println(CYAN .. "  (Type 'lver' anywhere in Termux to open this!)" .. RESET)
    println("")
    println("  " .. CYAN .. "[1]" .. RESET .. " - Stabilize Orbit & Cast Saturnity Ward")
    println("  " .. CYAN .. "[2]" .. RESET .. " - Dissolve Saturnity Ward")
    println("  " .. CYAN .. "[3]" .. RESET .. " - Flush Stardust Memory (RAM)")
    println("  " .. CYAN .. "[4]" .. RESET .. " - Banish System Bloatware (Run Once)")
    println("  " .. CYAN .. "[5]" .. RESET .. " - Ignite CPU Cores to Max Performance")
    println("")
    println("  " .. CYAN .. "[0]" .. RESET .. " - Exit")
    println("")
    io.write("Choose an option: ")
    
    restore_tty()
    local choice = io.read()
    
    if choice == "1" then
        run_optimization()
    elseif choice == "2" then
        stop_auto_protector()
    elseif choice == "3" then
        clear_ram_now()
    elseif choice == "4" then
        run_debloater()
    elseif choice == "5" then
        lock_cpu_performance()
    elseif choice == "0" then
        clear_screen()
        restore_tty()
        os.exit()
    end
end
