require "nokogiri"
require "mime"
require "asciimath"
require "xml/xslt"
require "uuidtools"
require "base64"
require "mime/types"
require "image_size"
require "asciidoctor/iso/isoxml/utils"
require "asciidoctor/iso/word/postprocessing"
require "asciidoctor/iso/word/utils"
require "asciidoctor/iso/word/metadata"
require "asciidoctor/iso/word/section"
require "asciidoctor/iso/word/references"
require "asciidoctor/iso/word/terms"
require "asciidoctor/iso/word/blocks"
require "asciidoctor/iso/word/inline"
require "asciidoctor/iso/isoxml/utils"
require "pp"

module Asciidoctor
  module ISO
    module Word
      module ISO2WordHTML
        class << self
          include ::Asciidoctor::ISO::Word::Postprocessing
          include ::Asciidoctor::ISO::Word::Utils
          include ::Asciidoctor::ISO::Word::Metadata
          include ::Asciidoctor::ISO::Word::Section
          include ::Asciidoctor::ISO::Word::References
          include ::Asciidoctor::ISO::Word::Terms
          include ::Asciidoctor::ISO::Word::Blocks
          include ::Asciidoctor::ISO::Word::Inline
          include ::Asciidoctor::ISO::ISOXML::Utils

          $anchors = {}
          $footnotes = []
          $termdomain = ""
          $filename = ""
          $dir = ""
          $xslt = XML::XSLT.new
          $xslt.xsl = File.read(File.join(File.dirname(__FILE__),
                                          "mathml2omml.xsl"))

          def convert(filename)
            init_file(filename)
            docxml = Nokogiri::XML(File.read(filename))
            docxml.root.default_namespace = ""
            result = noko do |xml|
              xml.html do |html|
                Postprocessing::html_header(html, docxml, $filename)
                make_body(xml, docxml)
              end
            end.join("\n")
            Postprocessing::postprocess(result, $filename)
          end

          def init_file(filename)
            $filename = filename.gsub(%r{\.[^/.]+$}, "")
            $dir = "#{$filename}_files"
            Dir.mkdir($dir) unless File.exists?($dir)
            system "rm -r #{$dir}/*"
          end

          def make_body(xml, docxml)
            body_attr = { lang: "EN-US", link: "blue", vlink: "#954F72" }
            xml.body **body_attr do |body|
              make_body1(body, docxml)
              make_body2(body, docxml)
              make_body3(body, docxml)
            end
          end

          def make_body1(body, docxml)
            body.div **{ class: "WordSection1" } do |div1|
              Postprocessing::titlepage docxml, div1
            end
            section_break(body)
          end

          def make_body2(body, docxml)
            body.div **{ class: "WordSection2" } do |div2|
              info docxml, div2
            end
            section_break(body)
          end

          def make_body3(body, docxml)
            body.div **{ class: "WordSection3" } do |div3|
              middle docxml, div3
              footnotes div3
            end
          end

          def info(isoxml, out)
            fn = File.join(File.dirname(__FILE__), "iso_intro.html")
            intropage = File.read(fn, encoding: "UTF-8")
            out.parent.add_child intropage
            title isoxml, out
            subtitle isoxml, out
            id isoxml, out
            author isoxml, out
            version isoxml, out
            foreword isoxml, out
            introduction isoxml, out
          end

          def middle(isoxml, out)
            out.p **{ class: "zzSTDTitle1" } { |p| p << $iso_doctitle }
            scope isoxml, out
            norm_ref isoxml, out
            terms_defs isoxml, out
            symbols_abbrevs isoxml, out
            clause isoxml, out
            annex isoxml, out
            bibliography isoxml, out
          end

          def parse(node, out)
            if node.text?
              out << node.text
            else
              case node.name
              when "em" then out.i { |e| e << node.text }
              when "strong" then out.b { |e| e << node.text }
              when "sup" then out.sup { |e| e << node.text }
              when "sub" then out.sub { |e| e << node.text }
              when "tt" then out.tt { |e| e << node.text }
              when "br" then out.br
              when "stem" then stem_parse(node, out)
              when "clause" then clause_parse(node, out)
              when "xref" then xref_parse(node, out)
              when "eref" then eref_parse(node, out)
              when "ul" then ul_parse(node, out)
              when "ol" then ol_parse(node, out)
              when "li" then li_parse(node, out)
              when "dl" then dl_parse(node, out)
              when "fn" then footnote_parse(node, out)
              when "p" then para_parse(node, out)
              when "tr" then tr_parse(node, out)
              when "note" then note_parse(node, out)
              when "warning" then warning_parse(node, out)
              when "formula" then formula_parse(node, out)
              when "table" then table_parse(node, out)
              when "figure" then figure_parse(node, out)
              when "termdef" then termdef_parse(node, out)
              when "term" then term_parse(node, out)
              when "admitted_term" then admitted_term_parse(node, out)
              when "termsymbol" then termsymbol_parse(node, out)
              when "deprecated_term" then deprecated_term_parse(node, out)
              when "termdomain" then $termdomain = node.text
              when "termdefinition"
                node.children.each { |n| parse(n, out) }
              when "termref" then termref_parse(node, out)
              when "isosection"
                out << "[ISOSECTION] #{node.text}"
              when "modification" then modification_parse(node, out)
              when "termnote" then termnote_parse(node, out)
              when "termexample" then termexample_parse(node, out)
              else
                error_parse(node, out)
              end
            end
          end
        end
      end
    end
  end
end