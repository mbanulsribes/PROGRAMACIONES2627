$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$script = Join-Path $root 'scripts/build-site.rb'
if (Get-Command ruby -ErrorAction SilentlyContinue) {
 & ruby $script
} elseif ((Test-Path -LiteralPath (Join-Path $root '.tools/jruby.jar')) -and (Get-Command java -ErrorAction SilentlyContinue)) {
 $savedHome=$env:GEM_HOME; $savedPath=$env:GEM_PATH
 try {
  $env:GEM_HOME=Join-Path $root '.tools/gems'; $env:GEM_PATH=$env:GEM_HOME
  & java '--enable-native-access=ALL-UNNAMED' -jar (Join-Path $root '.tools/jruby.jar') $script
 } finally { $env:GEM_HOME=$savedHome; $env:GEM_PATH=$savedPath }
} else { throw 'Instale Ruby y Asciidoctor (gem install asciidoctor), o utilice el compilador local de .tools con Java.' }
if($LASTEXITCODE -ne 0){throw "No se ha completado la web. Código: $LASTEXITCODE"}
