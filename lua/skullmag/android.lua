local M = {}

local uv = vim.uv or vim.loop
local setup_done = false
local state = {
  debug_port = 5005,
}

local root_markers = {
  "gradlew",
  "settings.gradle",
  "settings.gradle.kts",
  "build.gradle",
  "build.gradle.kts",
  ".git",
}

local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level or vim.log.levels.INFO, { title = "Android" })
  end)
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function joinpath(...)
  if vim.fs and vim.fs.joinpath then
    return vim.fs.joinpath(...)
  end

  return table.concat({ ... }, "/")
end

local function file_exists(path)
  return path ~= nil and uv.fs_stat(path) ~= nil
end

local function is_dir(path)
  local stat = path and uv.fs_stat(path) or nil
  return stat and stat.type == "directory" or false
end

local function read_file(path)
  if not file_exists(path) then
    return nil
  end

  local lines = vim.fn.readfile(path)
  return table.concat(lines, "\n")
end

local function split_lines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  return lines
end

local function relative_path(path, root)
  if not path or not root then
    return path
  end

  if path == root then
    return "."
  end

  local prefix = root .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end

  return path
end

local function project_root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local start_dir = name ~= "" and vim.fs.dirname(name) or uv.cwd()

  return vim.fs.root(start_dir, root_markers) or uv.cwd()
end

local function android_local_properties_sdk(root)
  local content = read_file(joinpath(root, "local.properties"))
  if not content then
    return nil
  end

  local sdk_dir = content:match("sdk%.dir%s*=%s*([^\n\r]+)")
  if not sdk_dir then
    return nil
  end

  sdk_dir = trim(sdk_dir)
  sdk_dir = sdk_dir:gsub("\\:", ":")
  sdk_dir = sdk_dir:gsub("\\\\", "/")
  return sdk_dir
end

local function sdk_root(root)
  local candidates = {
    vim.g.android_sdk_root,
    vim.env.ANDROID_SDK_ROOT,
    vim.env.ANDROID_HOME,
    root and android_local_properties_sdk(root) or nil,
    joinpath(vim.env.HOME or "", "Android", "Sdk"),
  }

  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" and is_dir(candidate) then
      return candidate
    end
  end

  return nil
end

local function tool_from_sdk(root, segments)
  local sdk = sdk_root(root)
  if not sdk then
    return nil
  end

  local path = sdk
  for _, segment in ipairs(segments) do
    path = joinpath(path, segment)
  end

  if file_exists(path) then
    return path
  end

  return nil
end

local function adb_path(root)
  local system_adb = vim.fn.exepath("adb")
  if system_adb ~= "" then
    return system_adb
  end

  return tool_from_sdk(root, { "platform-tools", "adb" })
end

local function emulator_path(root)
  local system_emulator = vim.fn.exepath("emulator")
  if system_emulator ~= "" then
    return system_emulator
  end

  return tool_from_sdk(root, { "emulator", "emulator" })
end

local function gradle_cmd(root)
  local wrapper = joinpath(root, "gradlew")
  if file_exists(wrapper) then
    if vim.fn.executable(wrapper) == 1 then
      return { wrapper, "--console=plain" }
    end

    return { "bash", wrapper, "--console=plain" }
  end

  local gradle = vim.fn.exepath("gradle")
  if gradle ~= "" then
    return { gradle, "--console=plain" }
  end

  return nil
end

local function build_files(root)
  local matches = vim.fn.globpath(root, "**/build.gradle*", false, true)
  local results = {}

  for _, path in ipairs(matches) do
    if file_exists(path) then
      table.insert(results, path)
    end
  end

  table.sort(results)
  return results
end

local function android_modules(root)
  local modules = {}

  for _, build_file in ipairs(build_files(root)) do
    local content = read_file(build_file)
    if content and content:find("com%.android%.application") then
      local module_dir = vim.fs.dirname(build_file)
      local rel = relative_path(module_dir, root)
      local module_name = rel == "." and ":" or (":" .. rel:gsub("/", ":"))

      table.insert(modules, {
        name = module_name,
        dir = module_dir,
        build_file = build_file,
      })
    end
  end

  table.sort(modules, function(left, right)
    return left.name < right.name
  end)

  return modules
end

local function primary_module(root)
  local modules = android_modules(root)
  if #modules == 0 then
    return nil
  end

  for _, module in ipairs(modules) do
    if module.name == ":app" then
      return module
    end
  end

  return modules[1]
end

local function gradle_task(module, task)
  if not module or module.name == ":" then
    return task
  end

  return module.name .. ":" .. task
end

local function application_id(module)
  if not module then
    return nil
  end

  local content = read_file(module.build_file)
  if content then
    local patterns = {
      'applicationId%s*=%s*"([^"]+)"',
      "applicationId%s*=%s*'([^']+)'",
      'applicationId%s+"([^"]+)"',
      "applicationId%s+'([^']+)'",
      'namespace%s*=%s*"([^"]+)"',
      "namespace%s*=%s*'([^']+)'",
      'namespace%s+"([^"]+)"',
      "namespace%s+'([^']+)'",
    }

    for _, pattern in ipairs(patterns) do
      local value = content:match(pattern)
      if value then
        return value
      end
    end
  end

  local manifest = joinpath(module.dir, "src", "main", "AndroidManifest.xml")
  local manifest_content = read_file(manifest)
  if manifest_content then
    return manifest_content:match('package%s*=%s*"([^"]+)"')
  end

  return nil
end

local function scratch(title, lines)
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

local function open_term(cmd, opts)
  opts = opts or {}

  vim.cmd("botright 14split")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = "wipe"

  if opts.title then
    pcall(vim.api.nvim_buf_set_name, buf, opts.title)
  end

  vim.fn.termopen(cmd, {
    cwd = opts.cwd,
    on_exit = function(_, code)
      if opts.on_exit then
        vim.schedule(function()
          opts.on_exit(code)
        end)
      elseif code ~= 0 then
        notify("Command failed: " .. (opts.title or table.concat(cmd, " ")), vim.log.levels.ERROR)
      end
    end,
  })

  vim.cmd("startinsert")
end

local function system(cmd)
  return vim.system(cmd, { text = true }):wait()
end

local function adb_command(root, serial, ...)
  local adb = adb_path(root)
  if not adb then
    return nil
  end

  local command = { adb }
  if serial and serial ~= "" then
    table.insert(command, "-s")
    table.insert(command, serial)
  end

  vim.list_extend(command, { ... })
  return command
end

local function connected_devices(root)
  local command = adb_command(root, nil, "devices", "-l")
  if not command then
    return nil, "Could not find adb. Set ANDROID_SDK_ROOT or create local.properties with sdk.dir."
  end

  local result = system(command)
  if result.code ~= 0 then
    return nil, trim(result.stderr) ~= "" and trim(result.stderr) or "adb devices failed"
  end

  local devices = {}
  for _, line in ipairs(split_lines(result.stdout)) do
    if line ~= "" and not line:match("^List of devices attached") then
      local serial, device_state, details = line:match("^(%S+)%s+(%S+)%s*(.*)$")
      if serial and device_state == "device" then
        table.insert(devices, {
          serial = serial,
          details = trim(details),
        })
      end
    end
  end

  return devices, nil
end

local function selected_device(root)
  if vim.g.android_device_serial and vim.g.android_device_serial ~= "" then
    return vim.g.android_device_serial
  end

  local devices, err = connected_devices(root)
  if not devices then
    return nil, err
  end

  if #devices == 1 then
    vim.g.android_device_serial = devices[1].serial
    return devices[1].serial
  end

  if #devices == 0 then
    return nil, "No Android device or emulator is connected."
  end

  return nil, "Multiple Android devices are connected. Run :AndroidSelectDevice first."
end

local function avds(root)
  local emulator = emulator_path(root)
  if not emulator then
    return nil, "Could not find the Android emulator binary."
  end

  local result = system({ emulator, "-list-avds" })
  if result.code ~= 0 then
    return nil, trim(result.stderr) ~= "" and trim(result.stderr) or "Failed to list AVDs"
  end

  local names = {}
  for _, line in ipairs(split_lines(result.stdout)) do
    line = trim(line)
    if line ~= "" then
      table.insert(names, line)
    end
  end

  return names, nil
end

local function choose_from_list(prompt, items, value_fn)
  if #items == 0 then
    return nil
  end

  if #items == 1 then
    return value_fn(items[1])
  end

  local labels = { prompt }
  for index, item in ipairs(items) do
    table.insert(labels, string.format("%d. %s", index, value_fn(item)))
  end

  local selection = vim.fn.inputlist(labels)
  if selection < 1 or selection > #items then
    return nil
  end

  return value_fn(items[selection])
end

local function resolve_component(root, package_name, serial)
  local command = adb_command(root, serial, "shell", "cmd", "package", "resolve-activity", "--brief", package_name)
  if not command then
    return nil
  end

  local result = system(command)
  if result.code ~= 0 then
    return nil
  end

  local component = nil
  for _, line in ipairs(split_lines(result.stdout)) do
    line = trim(line)
    if line:find("/", 1, true) then
      component = line
    end
  end

  return component
end

local function force_stop(root, serial, package_name)
  local command = adb_command(root, serial, "shell", "am", "force-stop", package_name)
  if command then
    system(command)
  end
end

local function launch_app(root, serial, package_name, debug_wait)
  local component = resolve_component(root, package_name, serial)
  if component then
    local command = adb_command(root, serial, "shell", "am", "start", "-W")
    if debug_wait then
      table.insert(command, "-D")
    end
    table.insert(command, "-n")
    table.insert(command, component)

    local result = system(command)
    if result.code == 0 then
      return true
    end

    notify(trim(result.stderr) ~= "" and trim(result.stderr) or "Failed to launch Android activity", vim.log.levels.ERROR)
    return false
  end

  if debug_wait then
    notify("Could not resolve the launcher activity for debug start.", vim.log.levels.ERROR)
    return false
  end

  local result = system(adb_command(root, serial, "shell", "monkey", "-p", package_name, "-c", "android.intent.category.LAUNCHER", "1"))
  if result.code == 0 then
    return true
  end

  notify(trim(result.stderr) ~= "" and trim(result.stderr) or "Failed to launch Android app", vim.log.levels.ERROR)
  return false
end

local function current_pid(root, serial, package_name)
  local command = adb_command(root, serial, "shell", "pidof", "-s", package_name)
  if not command then
    return nil
  end

  local result = system(command)
  if result.code == 0 then
    local pid = trim(result.stdout)
    if pid ~= "" then
      return pid
    end
  end

  local ps_result = system(adb_command(root, serial, "shell", "ps"))
  if ps_result.code ~= 0 then
    return nil
  end

  for _, line in ipairs(split_lines(ps_result.stdout)) do
    if line:match(package_name:gsub("%.", "%%.")) then
      local pid = line:match("^%S+%s+(%d+)")
      if pid then
        return pid
      end
    end
  end

  return nil
end

local function wait_for_pid(root, serial, package_name, timeout_ms)
  local pid = nil
  vim.wait(timeout_ms or 5000, function()
    pid = current_pid(root, serial, package_name)
    return pid ~= nil
  end, 200)
  return pid
end

local function forward_debug_port(root, serial, pid)
  local remove_command = adb_command(root, serial, "forward", "--remove", ("tcp:%d"):format(state.debug_port))
  if remove_command then
    system(remove_command)
  end

  local command = adb_command(root, serial, "forward", ("tcp:%d"):format(state.debug_port), "jdwp:" .. pid)
  if not command then
    return false
  end

  local result = system(command)
  if result.code ~= 0 then
    notify(trim(result.stderr) ~= "" and trim(result.stderr) or "Failed to forward Android JDWP port", vim.log.levels.ERROR)
    return false
  end

  return true
end

local function run_gradle(root, task, title, on_success)
  local command = gradle_cmd(root)
  if not command then
    notify("Could not find Gradle. This setup expects a project-local gradlew or a gradle binary in PATH.", vim.log.levels.ERROR)
    return
  end

  table.insert(command, task)
  open_term(command, {
    cwd = root,
    title = title,
    on_exit = function(code)
      if code ~= 0 then
        notify(task .. " failed", vim.log.levels.ERROR)
        return
      end

      if on_success then
        on_success()
      else
        notify(task .. " finished")
      end
    end,
  })
end

function M.guess_kotlin_main_class()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return ""
  end

  local content = read_file(file) or ""
  local package_name = content:match("^%s*package%s+([%w%._]+)")
  local base = vim.fn.fnamemodify(file, ":t:r")
  local default_class = base .. "Kt"

  if package_name and package_name ~= "" then
    return package_name .. "." .. default_class
  end

  return default_class
end

local function android_context()
  local root = project_root(0)
  local module = primary_module(root)
  local package_name = module and application_id(module) or nil

  return {
    root = root,
    module = module,
    package_name = package_name,
  }
end

local function install_and_launch(debug_attach)
  local context = android_context()
  if not context.module then
    notify("Could not find an Android application module. Expected a build.gradle/build.gradle.kts with com.android.application.", vim.log.levels.ERROR)
    return
  end

  if not context.package_name then
    notify("Could not detect the Android applicationId or namespace for the app module.", vim.log.levels.ERROR)
    return
  end

  local serial, device_err = selected_device(context.root)
  if not serial then
    notify(device_err, vim.log.levels.ERROR)
    return
  end

  run_gradle(
    context.root,
    gradle_task(context.module, "installDebug"),
    "Android Install",
    function()
      force_stop(context.root, serial, context.package_name)

      if not launch_app(context.root, serial, context.package_name, debug_attach) then
        return
      end

      if not debug_attach then
        notify("Android app launched on " .. serial)
        return
      end

      local pid = wait_for_pid(context.root, serial, context.package_name, 8000)
      if not pid then
        notify("The app did not expose a debuggable process in time. Make sure you are installing a debuggable variant.", vim.log.levels.ERROR)
        return
      end

      if not forward_debug_port(context.root, serial, pid) then
        return
      end

      local ok, dap = pcall(require, "dap")
      if not ok then
        notify("nvim-dap is not available.", vim.log.levels.ERROR)
        return
      end

      dap.run({
        type = "kotlin",
        request = "attach",
        name = "Android attach (" .. context.package_name .. ")",
        projectRoot = context.root,
        hostName = "127.0.0.1",
        port = state.debug_port,
        timeout = 8000,
      })
    end
  )
end

function M.setup()
  if setup_done then
    return
  end

  setup_done = true

  vim.api.nvim_create_user_command("AndroidHealth", function()
    local context = android_context()
    local lines = {
      "# Android Health",
      "",
      "Project root: " .. context.root,
      "Gradle wrapper: " .. (gradle_cmd(context.root) and table.concat(gradle_cmd(context.root), " ") or "missing"),
      "Android SDK: " .. (sdk_root(context.root) or "missing"),
      "adb: " .. (adb_path(context.root) or "missing"),
      "emulator: " .. (emulator_path(context.root) or "missing"),
      "App module: " .. (context.module and context.module.name or "missing"),
      "App package: " .. (context.package_name or "missing"),
      "Selected device: " .. (vim.g.android_device_serial or "auto"),
      "Debug port: " .. tostring(state.debug_port),
    }

    scratch("Android Health", lines)
  end, {})

  vim.api.nvim_create_user_command("AndroidDevices", function()
    local devices, err = connected_devices(project_root(0))
    if not devices then
      notify(err, vim.log.levels.ERROR)
      return
    end

    local lines = { "# Android Devices", "" }
    if #devices == 0 then
      table.insert(lines, "No devices connected.")
    else
      for _, device in ipairs(devices) do
        table.insert(lines, "- " .. device.serial .. (device.details ~= "" and ("  " .. device.details) or ""))
      end
    end

    scratch("Android Devices", lines)
  end, {})

  vim.api.nvim_create_user_command("AndroidSelectDevice", function(opts)
    local root = project_root(0)

    if opts.args ~= "" then
      vim.g.android_device_serial = opts.args
      notify("Using Android device " .. opts.args)
      return
    end

    local devices, err = connected_devices(root)
    if not devices then
      notify(err, vim.log.levels.ERROR)
      return
    end

    local serial = choose_from_list("Select Android device", devices, function(device)
      return device.serial
    end)

    if serial then
      vim.g.android_device_serial = serial
      notify("Using Android device " .. serial)
    end
  end, {
    nargs = "?",
    complete = function()
      local devices = connected_devices(project_root(0)) or {}
      local serials = {}
      for _, device in ipairs(devices) do
        table.insert(serials, device.serial)
      end
      return serials
    end,
  })

  vim.api.nvim_create_user_command("AndroidEmulator", function(opts)
    local root = project_root(0)
    local emulator = emulator_path(root)
    if not emulator then
      notify("Could not find the Android emulator binary.", vim.log.levels.ERROR)
      return
    end

    local avd_name = opts.args
    if avd_name == "" then
      local avd_names, err = avds(root)
      if not avd_names then
        notify(err, vim.log.levels.ERROR)
        return
      end

      avd_name = choose_from_list("Select AVD", avd_names, function(item)
        return item
      end)
    end

    if not avd_name or avd_name == "" then
      return
    end

    vim.fn.jobstart({ emulator, "-avd", avd_name }, { detach = true })
    notify("Starting emulator " .. avd_name)
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("AndroidBuildDebug", function()
    local context = android_context()
    if not context.module then
      notify("Could not find an Android application module.", vim.log.levels.ERROR)
      return
    end

    run_gradle(context.root, gradle_task(context.module, "assembleDebug"), "Android Build")
  end, {})

  vim.api.nvim_create_user_command("AndroidInstallDebug", function()
    local context = android_context()
    if not context.module then
      notify("Could not find an Android application module.", vim.log.levels.ERROR)
      return
    end

    run_gradle(context.root, gradle_task(context.module, "installDebug"), "Android Install")
  end, {})

  vim.api.nvim_create_user_command("AndroidRun", function()
    install_and_launch(false)
  end, {})

  vim.api.nvim_create_user_command("AndroidRerun", function()
    install_and_launch(false)
  end, {})

  vim.api.nvim_create_user_command("AndroidDebug", function()
    install_and_launch(true)
  end, {})

  vim.api.nvim_create_user_command("AndroidLogcat", function()
    local context = android_context()
    local serial, err = selected_device(context.root)
    if not serial then
      notify(err, vim.log.levels.ERROR)
      return
    end

    local command = nil
    if context.package_name then
      local pid = current_pid(context.root, serial, context.package_name)
      if pid then
        command = adb_command(context.root, serial, "logcat", "--pid=" .. pid)
      end
    end

    command = command or adb_command(context.root, serial, "logcat")
    if not command then
      notify("Could not find adb.", vim.log.levels.ERROR)
      return
    end

    open_term(command, {
      cwd = context.root,
      title = "Android Logcat",
    })
  end, {})

  vim.api.nvim_create_user_command("AndroidDebugAttach", function()
    local context = android_context()
    if not context.package_name then
      notify("Could not detect the Android applicationId or namespace for the app module.", vim.log.levels.ERROR)
      return
    end

    local serial, err = selected_device(context.root)
    if not serial then
      notify(err, vim.log.levels.ERROR)
      return
    end

    local pid = wait_for_pid(context.root, serial, context.package_name, 3000)
    if not pid then
      notify("No debuggable app process was found. Start the debug build first with :AndroidDebug or :AndroidRun.", vim.log.levels.ERROR)
      return
    end

    if not forward_debug_port(context.root, serial, pid) then
      return
    end

    local ok, dap = pcall(require, "dap")
    if not ok then
      notify("nvim-dap is not available.", vim.log.levels.ERROR)
      return
    end

    dap.run({
      type = "kotlin",
      request = "attach",
      name = "Android attach (" .. context.package_name .. ")",
      projectRoot = context.root,
      hostName = "127.0.0.1",
      port = state.debug_port,
      timeout = 8000,
    })
  end, {})

  vim.keymap.set("n", "<leader>ah", "<cmd>AndroidHealth<CR>", { desc = "Android health" })
  vim.keymap.set("n", "<leader>ap", "<cmd>AndroidSelectDevice<CR>", { desc = "Android pick device" })
  vim.keymap.set("n", "<leader>ae", "<cmd>AndroidEmulator<CR>", { desc = "Android emulator" })
  vim.keymap.set("n", "<leader>ab", "<cmd>AndroidBuildDebug<CR>", { desc = "Android build debug" })
  vim.keymap.set("n", "<leader>ai", "<cmd>AndroidInstallDebug<CR>", { desc = "Android install debug" })
  vim.keymap.set("n", "<leader>aa", "<cmd>AndroidRun<CR>", { desc = "Android run app" })
  vim.keymap.set("n", "<leader>ar", "<cmd>AndroidRerun<CR>", { desc = "Android rerun app" })
  vim.keymap.set("n", "<leader>ax", "<cmd>AndroidDebug<CR>", { desc = "Android debug app" })
  vim.keymap.set("n", "<leader>al", "<cmd>AndroidLogcat<CR>", { desc = "Android logcat" })

  vim.keymap.set("n", "<F5>", function()
    require("dap").continue()
  end, { desc = "Debug continue" })
  vim.keymap.set("n", "<F9>", function()
    require("dap").toggle_breakpoint()
  end, { desc = "Debug breakpoint" })
  vim.keymap.set("n", "<F10>", function()
    require("dap").step_over()
  end, { desc = "Debug step over" })
  vim.keymap.set("n", "<F11>", function()
    require("dap").step_into()
  end, { desc = "Debug step into" })
  vim.keymap.set("n", "<F12>", function()
    require("dap").step_out()
  end, { desc = "Debug step out" })
end

return M
