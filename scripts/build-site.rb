require 'asciidoctor'
require 'json'
require 'fileutils'
require 'cgi'
require 'time'
root = File.expand_path('..', __dir__)
destination = File.join(root, 'docs')
catalog = JSON.parse(File.read(File.join(root, 'site/catalogo.json'), encoding: 'UTF-8'))
ids = catalog.map { |entry| entry.fetch('id') }
abort 'Identificadores duplicados o no válidos' unless ids.uniq == ids && ids.all? { |id| /\A[a-z0-9-]+\z/.match? id }
# Build in a dedicated temporary directory. Replace only files owned by this builder.
staging = File.join(root, 'output/site-build')
FileUtils.mkdir_p(staging)
owned = []
write = lambda do |relative, contents|
  path = File.join(staging, relative)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, contents, encoding: 'UTF-8')
  owned << relative
end
copy = lambda do |source, relative|
  path = File.join(staging, relative)
  FileUtils.mkdir_p(File.dirname(path))
  FileUtils.cp(source, path)
  owned << relative
end
escape = ->(text) { CGI.escapeHTML(text.to_s) }
copy.call(File.join(root, 'site/site.css'), 'assets/styles/site.css')
copy.call(File.join(root, 'site/document.css'), 'assets/styles/document.css')
copy.call(File.join(root, 'theme/programacion.css'), 'assets/styles/institutional.css')
Dir.glob(File.join(root, 'assets/images/*')).select { |f| File.file?(f) }.each do |f|
  copy.call(f, "assets/images/#{File.basename(f)}")
end
cards = []
catalog.each do |entry|
  id = entry.fetch('id')
  source = File.expand_path(entry.fetch('source'), root)
  abort "Fuente fuera del proyecto: #{source}" unless source.start_with?(root + File::SEPARATOR)
  logger = Asciidoctor::MemoryLogger.new
  Asciidoctor::LoggerManager.logger = logger
  html = Asciidoctor.convert_file(source, safe: :unsafe, to_file: false, header_footer: true, attributes: {
    'stylesheet' => 'document.css', 'stylesdir' => '../assets/styles', 'linkcss' => '',
    'imagesdir' => '../assets/images', 'webfonts!' => '', 'icons!' => '', 'source-highlighter!' => ''
  })
  unless logger.messages.empty?
    logger.messages.each { |message| warn message.inspect }
    abort "Revisar advertencias al compilar #{id}"
  end
  pdf_link = ''
  if entry['pdf'] && File.file?(pdf = File.join(root, entry['pdf']))
    copy.call(pdf, "descargas/#{id}.pdf")
    stamp = File.mtime(pdf).strftime('%d/%m/%Y')
    pdf_link = %(<a href="../descargas/#{id}.pdf">Descargar PDF <small>(#{stamp})</small></a>)
  end
  nav = %(<nav class="site-nav" aria-label="Navegación"><a href="../index.html">← Todas las programaciones</a><span>#{escape.call(entry['level'])} · 2026–2027</span>#{pdf_link}</nav>)
  html = html.sub(/(<body[^>]*>)/, "\1\n#{nav}")
  write.call("#{id}/index.html", html)
  cards << %(<article class="card" data-stage="#{escape.call(entry['stage'])}"><p class="level">#{escape.call(entry['level'])}</p><h3><a href="#{id}/index.html">#{escape.call(entry['title'])}</a></h3><p class="card-action"><a href="#{id}/index.html">Consultar programación <span aria-hidden="true">→</span></a></p>#{pdf_link.gsub('../descargas/', 'descargas/')}</article>)
end
sections = ['ESO', 'Formación Profesional'].map do |stage|
  selected = cards.select { |card| card.include?(%(data-stage="#{stage}")) }
  %(<section aria-label="#{stage}"><h2>#{stage}</h2><div class="grid">#{selected.join("\n")}</div></section>)
end.join("\n")
write.call('index.html', <<~HTML)
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Programaciones 2026–2027 · IES Font de Sant Lluís</title><meta name="description" content="Programaciones didácticas del Departamento de Informática: ESO y Formación Profesional."><link rel="stylesheet" href="assets/styles/site.css"></head>
<body><a class="skip" href="#contenido">Saltar al contenido</a><header><div class="brand"><img src="assets/images/logo-ies-font.jpeg" width="98" height="49" alt=""><div>IES Font de Sant Lluís<br><span>Departamento de Informática</span></div></div><p class="year">Curso 2026–2027</p></header><main id="contenido"><div class="intro"><p class="eyebrow">Documentación docente</p><h1>Programaciones didácticas</h1><p>Consulta la programación de cada materia o módulo, sus unidades y sus criterios de evaluación.</p><p class="notice">Documentos de trabajo. Cada programación conserva sus indicaciones de revisión y los acuerdos pendientes de validación.</p></div>#{sections}</main><footer>IES Font de Sant Lluís · Departamento de Informática · Curso 2026–2027</footer></body></html>
HTML
write.call('.nojekyll', '')
# Only the explicit public files above enter docs. No originals, fonts, DOCX or tools.
FileUtils.mkdir_p(destination)
old_manifest_path = File.join(destination, '.generated-files.json')
old_files = File.exist?(old_manifest_path) ? JSON.parse(File.read(old_manifest_path)) : []
(old_files - owned).each do |relative|
  path = File.expand_path(relative, destination)
  abort 'Ruta pública no válida' unless path.start_with?(destination + File::SEPARATOR)
  File.delete(path) if File.file?(path)
end
owned.each { |relative| target = File.join(destination, relative); FileUtils.mkdir_p(File.dirname(target)); FileUtils.cp(File.join(staging, relative), target) }
File.write(old_manifest_path, JSON.pretty_generate(owned), encoding: 'UTF-8')
puts "Web preparada: #{destination}/index.html (#{catalog.length} programaciones)"
