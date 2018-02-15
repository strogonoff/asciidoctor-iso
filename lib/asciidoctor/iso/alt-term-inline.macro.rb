class AltTermInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
  use_dsl
  named :alt
  parse_content_as :text
  def process parent, target, attributes
    warn "XXXXX"
    %{<alt>#{attrs["text"]}</alt>}
  end
end

class DeprecatedTermInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
  use_dsl
  named :deprecated
  parse_content_as :text
  def process parent, target, attributes
    %{<deprecated>#{attrs["text"]}</deprecated>}
  end
end

