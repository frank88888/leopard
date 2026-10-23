# Launches this Godot project; used by .vscode/launch.json.
# Extra arguments are passed through to Godot (e.g. --resolution 540x748).
$godot = if ($env:GODOT4) { $env:GODOT4 } else { 'C:\Users\frank\tools\godot\Godot_v4.4.1-stable_win64_console.exe' }
$project = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $godot)) {
    Write-Error "Godot not found: $godot (set the GODOT4 environment variable)"
    exit 1
}

& $godot --path $project @args
exit $LASTEXITCODE
