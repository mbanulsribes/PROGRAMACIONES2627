param([string]$Modulo = 'todos')
& (Join-Path $PSScriptRoot 'build.ps1') -Modulo $Modulo -Formato pdf
