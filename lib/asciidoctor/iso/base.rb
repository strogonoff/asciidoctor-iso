require "date"
require "nokogiri"
require "htmlentities"
require "json"
require "pathname"
require "open-uri"
require "pp"
require "sass"
require "isodoc"
require "relaton"

module Asciidoctor
  module ISO
    class Converter < Standoc::Converter
      def html_converter(node)
        IsoDoc::Iso::HtmlConvert.new(
          script: node.attr("script"),
          bodyfont: node.attr("body-font"),
          headerfont: node.attr("header-font"),
          monospacefont: node.attr("monospace-font"),
          i18nyaml: node.attr("i18nyaml"),
        )
      end

      def html_converter_alt(node)
        IsoDoc::Iso::HtmlConvert.new(
          script: node.attr("script"),
          bodyfont: node.attr("body-font"),
          headerfont: node.attr("header-font"),
          monospacefont: node.attr("monospace-font"),
          i18nyaml: node.attr("i18nyaml"),
          alt: true,
        )
      end

      def doc_converter(node)
        IsoDoc::Iso::WordConvert.new(
          script: node.attr("script"),
          bodyfont: node.attr("body-font"),
          headerfont: node.attr("header-font"),
          monospacefont: node.attr("monospace-font"),
          i18nyaml: node.attr("i18nyaml"),
        )
      end

      def document(node)
        init(node)
        ret = makexml(node).to_xml(indent: 2)
        unless node.attr("nodoc") || !node.attr("docfile")
          File.open(@filename + ".xml", "w:UTF-8") { |f| f.write(ret) }
          html_converter_alt(node).convert(@filename + ".xml")
          system "mv #{@filename}.html #{@filename}_alt.html"
          html_converter(node).convert(@filename + ".xml")
          doc_converter(node).convert(@filename + ".xml")
        end
        @files_to_delete.each { |f| system "rm #{f}" }
        ret
      end
    end
  end
end
