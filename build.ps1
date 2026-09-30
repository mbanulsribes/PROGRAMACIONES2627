param(
 [ValidatePattern('^[a-z0-9_-]+$')][string]$Modulo = 'todos',
 [ValidateSet('html','pdf','todos')][string]$Formato = 'todos'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$modules = if ($Modulo -eq 'todos') { Get-ChildItem -LiteralPath (Join-Path $root 'src/modulos') -Filter '*.adoc' | ForEach-Object { $_.BaseName } } else { @($Modulo) }
$formats = if ($Formato -eq 'todos') { @('html','pdf') } else { @($Formato) }
foreach ($m in $modules) {
 if (!(Test-Path -LiteralPath (Join-Path $root "src/modulos/$m.adoc"))) { throw "Módulo inexistente: $m" }
 foreach ($f in $formats) {
  $outDir = Join-Path $root "output/$f"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $out = Join-Path $outDir "programacion-$m.$f"
  $cli = if ($f -eq 'pdf') { 'asciidoctor-pdf' } else { 'asciidoctor' }
  $opts = @('--failure-level','WARN','-a',"modulo-id=$m",'-o',$out)
  if ($f -eq 'pdf') {
   $opts += @('-r',(Join-Path $root 'scripts/pdf-cover.rb'),'-a',"imagesdir=$root/assets/images",'-a',"pdf-themesdir=$root/theme",'-a',"pdf-fontsdir=$root/assets/fonts;GEM_FONTS_DIR")
  } else {
   $opts += @('-a','imagesdir=../../assets/images','-a','stylesdir=../../theme')
  }
  $opts += (Join-Path $root 'src/programacion.adoc')
  if (Get-Command $cli -ErrorAction SilentlyContinue) { & $cli @opts }
  elseif ((Test-Path -LiteralPath (Join-Path $root '.tools/jruby.jar')) -and (Get-Command java -ErrorAction SilentlyContinue)) {
   $oldGemHome=$env:GEM_HOME; $oldGemPath=$env:GEM_PATH
   try {
    $env:GEM_HOME=Join-Path $root '.tools/gems'; $env:GEM_PATH=$env:GEM_HOME
    & java '--enable-native-access=ALL-UNNAMED' -jar (Join-Path $root '.tools/jruby.jar') (Join-Path $root ".tools/gems/bin/$cli") @opts
   } finally { $env:GEM_HOME=$oldGemHome; $env:GEM_PATH=$oldGemPath }
  } else { throw "Falta $cli. Instale Ruby y ejecute: gem install asciidoctor asciidoctor-pdf. Consulte README.adoc." }
  if ($LASTEXITCODE -ne 0) { throw "Falló la compilación de $m ($f). Código: $LASTEXITCODE" }
  Write-Host "Generado: $out"
 }
}
