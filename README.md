Android keybindings:

<leader>ah opens Android health/status
<leader>ap selects the active Android device
<leader>ae launches an emulator
<leader>ab builds the debug app
<leader>ai installs the debug app
<leader>aa runs the app
<leader>ar reruns the app
<leader>ax installs, launches, and attaches the debugger
<leader>al opens logcat
Debug keybindings:

<F5> continue/start DAP
<F9> toggle breakpoint
<F10> step over
<F11> step into
<F12> step out
Useful existing general bindings:

<leader>f format file
gd go to definition
K hover docs
<leader>vca code action
<leader>vrr references
<leader>vrn rename
[d previous diagnostic
]d next diagnostic
<leader>vd diagnostic float
<C-Space> completion menu
<C-y> confirm selected completion
<C-e> abort completion
<Tab> / <S-Tab> next/previous completion or snippet jump
Direct commands if you prefer typing:

:AndroidEmulator
:AndroidRun
:AndroidRerun
:AndroidDebug
:AndroidBuildDebug
:AndroidInstallDebug
:AndroidLogcat
:AndroidSelectDevice
:AndroidDevices
:AndroidHealth
For the exact flow you asked about:

Launch emulator: <leader>ae
Run project: <leader>aa
Re-run project: <leader>ar
Run with debugger: <leader>ax