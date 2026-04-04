-- =====================================================================
-- lana vie en rose AIO
-- GitHub: lucivaantarez/lanavienrose
-- Theme: Clean & Tactical (v1.4.3 - Absolute Debloat Edition)
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

local function println(str)
    io.write((str or "") .. "\r\n")
end

-- ============================================
-- AUTO-INSTALLERS & SHORTCUTS
-- ============================================

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

local function setup_smart_autolaunch()
    -- Automatically configure Termux to open the dashboard ONLY on the first tab
    local bash_script = [[
        BASHRC="/data/data/com.termux/files/home/.bashrc"
        touch "$BASHRC"
        # Remove the old, dumb autolaunch rule if it exists
        sed -i '/^lver$/d' "$BASHRC"
        # Inject the smart autolaunch rule if it's missing
        if ! grep -q 'pgrep -f "main.lua"' "$BASHRC"; then
            echo 'if ! pgrep -f "main.lua" > /dev/null; then lver; fi' >> "$BASHRC"
        fi
    ]]
    os.execute(bash_script)
end

local function clear_screen()
    os.execute("clear")
end

-- ============================================
-- SYSTEM MONITORS
-- ============================================

local function is_service_running()
    local f = io.open(PID_FILE, "r")
    if not f then return false, "NONE" end
    local pid = f:read("*l")
    f:close()
    if not pid or pid == "" then return false, "NONE" end

    local handle = io.popen("kill -0 " .. pid .. " 2>/dev/null && cat /proc/" .. pid .. "/cmdline 2>/dev/null")
    local cmdline = handle:read("*a") or ""
    handle:close()

    if cmdline:match("lver_bg") then
        return true, pid
    else
        os.remove(PID_FILE)
        return false, "NONE"
    end
end

local function get_cpu_info()
    local function read_stat()
        local f = io.open("/proc/stat", "r")
        if not f then return 0, 0 end
        local line = f:read("*l")
        f:close()
        if not line or not line:match("^cpu ") then return 0, 0 end
        local total, idle = 0, 0, 1
        for val in line:gmatch("%d+") do
            local v = tonumber(val)
            total = total + v
            if idle == 4 or idle == 5 then idle = idle + v end
        end
        return total, idle
    end

    local t1, i1 = read_stat()
    os.execute("sleep 0.3") 
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

    local handle = io.popen("cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | sort -nr | head -n1")
    local max_khz = handle:read("*n")
    handle:close()

    local ghz_str = ""
    if max_khz and max_khz > 0 then
        ghz_str = string.format(" @ %.2f GHz", max_khz / 1000000)
    end

    return usage_str .. ghz_str
end

local function get_ram_info()
    local f = io.open("/proc/meminfo", "r")
    if not f then return "?? GB Used / ?? GB" end
    local text = f:read("*a")
    f:close()

    local mem_total = text:match("MemTotal:%s+(%d+) kB")
    local mem_avail = text:match("MemAvailable:%s+(%d+) kB") or text:match("MemFree:%s+(%d+) kB")
    
    if mem_total and mem_avail then
        local total_gb = tonumber(mem_total) / (1024 * 1024)
        local used_gb = (tonumber(mem_total) - tonumber(mem_avail)) / (1024 * 1024)
        return string.format("%.1f GB Used / %.1f GB", used_gb, total_gb)
    end
    return "?? GB Used / ?? GB"
end

-- ============================================
-- EXECUTION HELPERS
-- ============================================

local function run_cmd(desc, cmd)
    io.write("  " .. desc .. " ")
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

local function draw_table_row(name, val, is_green)
    local name_pad = name .. string.rep(" ", 16 - #name)
    local color = is_green == nil and WHITE or (is_green and GREEN or RED)
    local val_pad = string.rep(" ", 25 - #val)
    println(CYAN .. "| " .. WHITE .. name_pad .. CYAN .. " | " .. color .. "[ " .. val .. " ]" .. val_pad .. CYAN .. "|" .. RESET)
end

-- ============================================
-- CORE LOGIC
-- ============================================

local function engage_max_performance()
    println("\n" .. CYAN .. "Engaging Max Performance & Anti-Kill Ward..." .. RESET)
    println("--------------------------------------------------")
    
    run_cmd("[~] Force-closing background apps...", "am force-stop com.google.android.youtube ; am force-stop com.android.chrome ; am force-stop com.google.android.apps.maps")
    run_cmd("[~] Muting notifications & haptics...", "settings put global heads_up_notifications_enabled 0 ; settings put system haptic_feedback_enabled 0")
    run_cmd("[~] Locking CPU to max performance...", "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo 'performance' > $cpu 2>/dev/null; done")
    run_cmd("[~] Disabling HW Overlays (Force GPU)...", "service call SurfaceFlinger 1008 i32 1")
    run_cmd("[~] Optimizing TCP window scaling...", "sysctl -w net.ipv4.tcp_window_scaling=1")
    run_cmd("[~] Expanding network buffers...", "sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' ; sysctl -w net.ipv4.tcp_wmem='4096 16384 16777216'")
    run_cmd("[~] Maximizing Disk I/O throughput...", "for f in /sys/block/*/queue/scheduler; do echo noop > $f 2>/dev/null; done ; for f in /sys/block/*/queue/read_ahead_kb; do echo 2048 > $f 2>/dev/null; done")

    local is_running, _ = is_service_running()
    if is_running then
        println("  [~] Anti-Kill Daemon...                " .. GREEN .. "[ACTIVE]" .. RESET)
    else
        local bg_logic = [[
#!/system/bin/sh
trap "rm -f ]] .. PID_FILE .. [[; exit" TERM INT HUP
while true; do
    su -c 'for p in /proc/[0-9]*; do
        if [ -f "$p/cmdline" ] && grep -qE "com.roblox|com.termux" "$p/cmdline" 2>/dev/null; then
            echo -1000 > "$p/oom_score_adj" 2>/dev/null
        fi
    done' </dev/null 2>/dev/null
    
    if ! ps -A | grep -q "com.termux"; then
        am start -n com.termux/com.termux.app.TermuxActivity > /dev/null 2>&1
    fi
    
    sleep 30
done
]]
        local f = io.open(BG_SCRIPT_FILE, "w")
        if f then
            f:write(bg_logic)
            f:close()
            os.execute("termux-wake-lock 2>/dev/null")
            local handle = io.popen("sh " .. BG_SCRIPT_FILE .. " </dev/null >/dev/null 2>&1 & echo $!")
            local new_pid = handle:read("*l")
            handle:close()
            if new_pid and new_pid ~= "" then
                local pf = io.open(PID_FILE, "w")
                if pf then pf:write(new_pid .. "\n"); pf:close() end
                println("  [~] Starting Anti-Kill Daemon...       " .. GREEN .. "[SUCCESS]" .. RESET)
            else
                println("  [~] Starting Anti-Kill Daemon...       " .. RED .. "[FAIL]" .. RESET)
            end
        end
    end

    println("--------------------------------------------------")
    println(CYAN .. "Server ready. Press Enter to return." .. RESET)
    restore_tty(); io.read()
end

local function flush_and_wipe()
    println("\n" .. CYAN .. "Flushing System RAM & Wiping Caches..." .. RESET)
    println("--------------------------------------------------")
    run_cmd("[~] Dropping system RAM caches...", "echo 3 > /proc/sys/vm/drop_caches")
    run_cmd("[~] Deleting junk client textures...", "rm -rf /data/data/com.roblox*/cache/*")
    run_cmd("[~] Vaporizing Roblox telemetry logs...", "rm -rf /sdcard/Roblox/logs/* ; rm -rf /data/data/com.roblox*/app_roblox/logs/*")
    run_cmd("[~] Trimming virtual SSD blocks...", "sm fstrim")
    println("--------------------------------------------------")
    println(CYAN .. "Maintenance complete. Press Enter to return." .. RESET)
    restore_tty(); io.read()
end

local function terminate_daemon()
    println("\n" .. CYAN .. "Terminating Anti-Kill Daemon..." .. RESET)
    local is_running, pid = is_service_running()
    if is_running then
        os.execute("kill -9 " .. pid .. " 2>/dev/null")
        os.remove(PID_FILE)
        os.remove(BG_SCRIPT_FILE)
        run_cmd("[~] Terminating background process...", "echo 1") 
    else
        println("  [~] Daemon is already stopped.         " .. GREEN .. "[OK]" .. RESET)
    end
    println("\nPress Enter to return to menu.")
    restore_tty(); io.read()
end

local function freeze_bloatware()
    println("\n" .. CYAN .. "Freezing System Bloatware..." .. RESET)
    println("--------------------------------------------------")
    
    -- Phase 1: Heavy Google Apps (Search Updated)
    run_cmd("[~] Freezing Google Chrome...", "pm disable-user --user 0 com.android.chrome")
    run_cmd("[~] Freezing YouTube...", "pm disable-user --user 0 com.google.android.youtube")
    run_cmd("[~] Freezing Google Maps...", "pm disable-user --user 0 com.google.android.apps.maps")
    run_cmd("[~] Freezing Google Photos...", "pm disable-user --user 0 com.google.android.apps.photos")
    run_cmd("[~] Freezing Google Search...", "pm disable-user --user 0 com.google.android.googlequicksearchbox ; pm disable-user --user 0 com.android.quicksearchbox")
    run_cmd("[~] Freezing Play Games...", "pm disable-user --user 0 com.google.android.play.games")
    
    -- Phase 2: Useless Android AOSP Apps (Messaging Updated)
    run_cmd("[~] Freezing Phone/SMS/Contacts...", "pm disable-user --user 0 com.android.dialer ; pm disable-user --user 0 com.android.mms ; pm disable-user --user 0 com.android.contacts ; pm disable-user --user 0 com.android.messaging")
    run_cmd("[~] Freezing Clock/Calendar/Email/Gallery...", "pm disable-user --user 0 com.android.deskclock ; pm disable-user --user 0 com.android.calendar ; pm disable-user --user 0 com.android.email ; pm disable-user --user 0 com.android.gallery3d")
    
    -- Phase 3: The Deep Clean (Hardcoded Targets)
    run_cmd("[~] Freezing Google Play Store...", "pm disable-user --user 0 com.android.vending")
    run_cmd("[~] Freezing Redfinger App Store...", "pm disable-user --user 0 com.wsh.appstore")
    run_cmd("[~] Freezing Extended Services...", "pm disable-user --user 0 com.baidu.cloud.service ; pm disable-user --user 0 com.wshl.file.observerservice")
    run_cmd("[~] Freezing File Manager...", "pm disable-user --user 0 com.google.android.apps.nbu.files ; pm disable-user --user 0 com.android.documentsui")
    run_cmd("[~] Freezing Root Tools UI...", "pm disable-user --user 0 com.wsh.toolkit ; pm disable-user --user 0 com.android.tools")

    println("--------------------------------------------------")
    println(CYAN .. "Bloatware frozen. Press Enter to return." .. RESET)
    restore_tty(); io.read()
end

local function interactive_sweeper()
    println("\n" .. CYAN .. "Interactive SD Card Sweeper" .. RESET)
    println("--------------------------------------------------")
    println("Scanning /sdcard/ for all items...\n")
    
    local handle = io.popen("ls -1p /sdcard/ 2>/dev/null")
    local items = {}
    local display_index = 1
    
    for line in handle:lines() do
        if line ~= ".lver_bg.sh" and line ~= ".lver_bg_pid" and line ~= "" then
            items[display_index] = line
            local display_name = line
            if not line:match("/$") then
                display_name = line .. " (File)"
            end
            println("  [" .. display_index .. "] " .. display_name)
            display_index = display_index + 1
        end
    end
    handle:close()

    if #items == 0 then
        println("  " .. GREEN .. "SD card is already clean!" .. RESET)
        println("--------------------------------------------------")
        println("Press Enter to return.")
        restore_tty(); io.read(); return
    end

    println("\nType the numbers of the items to " .. GREEN .. "KEEP" .. RESET .. ".")
    println("Everything else will be " .. RED .. "VAPORIZED" .. RESET .. ".")
    println("(Example: 1,3,4)\n")
    
    io.write("Keep: ")
    restore_tty()
    local choice = io.read() or ""
    
    local keep_map = {}
    for k in choice:gmatch("%d+") do
        keep_map[tonumber(k)] = true
    end

    println("\n" .. CYAN .. "Executing Root Storage Sweep..." .. RESET)
    println("--------------------------------------------------")
    
    for i, file_name in ipairs(items) do
        local display_name = file_name
        if not file_name:match("/$") then display_name = file_name end
        
        io.write("  [~] Processing " .. string.sub(display_name, 1, 20) .. "... ")
        local pad = 24 - #string.sub(display_name, 1, 20)
        if pad > 0 then io.write(string.rep(" ", pad)) end

        if keep_map[i] then
            println(GREEN .. "[KEPT]" .. RESET)
        else
            os.execute("su -c 'rm -rf \"/sdcard/" .. file_name .. "\"' 2>/dev/null")
            println(RED .. "[VAPORIZED]" .. RESET)
        end
    end
    println("--------------------------------------------------")
    println(CYAN .. "Sweep complete. Press Enter to return." .. RESET)
    restore_tty(); io.read()
end

-- ============================================
-- MAIN MENU LOOP
-- ============================================
setup_shortcut()
setup_smart_autolaunch()

while true do
    clear_screen()
    
    local cpu_val = get_cpu_info()
    local ram_val = get_ram_info()
    local running, pid = is_service_running()
    
    local status_val = "OFFLINE"
    if running then status_val = "ACTIVE (PID: " .. pid .. ")" end
    
    local title = "lana vie en rose AIO v1.4.3"
    local timestamp = "[ " .. os.date("%b %d, %I:%M %p") .. " ]"
    local spaces_needed = 50 - (#title + #timestamp)
    local header_line = title .. string.rep(" ", spaces_needed) .. timestamp

    println(CYAN .. "==================================================" .. RESET)
    println(WHITE .. header_line .. RESET)
    println(CYAN .. "==================================================" .. RESET)
    println("")
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    println(CYAN .. "| " .. WHITE .. "Module          " .. CYAN .. " | " .. WHITE .. "Status                   " .. CYAN .. "|" .. RESET)
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    draw_table_row("Anti-Kill Daemon", status_val, running)
    draw_table_row("CPU Monitor", cpu_val, nil)
    draw_table_row("RAM Monitor", ram_val, nil)
    println(CYAN .. "+------------------------------------------------+" .. RESET)
    println("")
    println(WHITE .. "Main Menu:" .. RESET)
    println(CYAN .. "  (Type 'lver' anywhere in Termux to open this!)" .. RESET)
    println("")
    println("  " .. CYAN .. "[1]" .. RESET .. " - Engage Max Performance & Anti-Kill Ward")
    println("  " .. CYAN .. "[2]" .. RESET .. " - Flush System RAM & Wipe Roblox Caches")
    println("  " .. CYAN .. "[3]" .. RESET .. " - Terminate Anti-Kill Daemon")
    println("  " .. CYAN .. "[4]" .. RESET .. " - Freeze System Bloatware (Run Once)")
    println("  " .. CYAN .. "[5]" .. RESET .. " - Interactive SD Card Sweeper")
    println("")
    println("  " .. CYAN .. "[0]" .. RESET .. " - Exit")
    println("")
    io.write("Choose an option: ")
    
    restore_tty()
    local choice = io.read()
    
    if choice == "1" then
        engage_max_performance()
    elseif choice == "2" then
        flush_and_wipe()
    elseif choice == "3" then
        terminate_daemon()
    elseif choice == "4" then
        freeze_bloatware()
    elseif choice == "5" then
        interactive_sweeper()
    elseif choice == "0" then
        clear_screen()
        restore_tty()
        os.exit()
    end
end
