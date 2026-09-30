require 'asciidoctor-pdf'
# Applies the DOCX cover panel background only to the table with role "modulo".
module InstitutionalCoverTable
  def convert_table(node)
    return super unless node.role? 'modulo'
    keys = %i(table_background_color table_body_background_color table_body_stripe_background_color)
    previous = keys.map { |key| @theme[key] }
    begin
      keys.each { |key| @theme[key] = 'DFDFDF' }
      super
    ensure
      keys.zip(previous).each { |key, value| @theme[key] = value }
    end
  end
end
Asciidoctor::PDF::Converter.prepend InstitutionalCoverTable
