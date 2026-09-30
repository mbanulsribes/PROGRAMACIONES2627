param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9_-]+$')][string]$Id)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$master=Join-Path $root "src/modulos/$Id.adoc"
$attrs=Join-Path $root "src/atributos/$Id.adoc"
$chapters=Join-Path $root "src/capitulos/$Id"
foreach($p in @($master,$attrs,$chapters)){if(Test-Path -LiteralPath $p){throw "Ya existe: $p"}}
New-Item -ItemType Directory -Path $chapters | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'templates/modulo/atributos.adoc') -Destination $attrs
Copy-Item -Path (Join-Path $root 'templates/modulo/capitulos/*.adoc') -Destination $chapters
$text=[IO.File]::ReadAllText((Join-Path $root 'templates/modulo/programacion.adoc')).Replace('@ID@',$Id)
[IO.File]::WriteAllText($master,$text,[Text.UTF8Encoding]::new($false))
Write-Host "Creado $Id. Edite src/atributos/$Id.adoc y src/capitulos/$Id. Compile con ./build.ps1 -Modulo $Id"
