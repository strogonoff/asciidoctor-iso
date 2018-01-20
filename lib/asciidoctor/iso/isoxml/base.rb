require "date"
require "nokogiri"
require "htmlentities"
require "json"
require "pathname"
require "open-uri"
require "pp"

module Asciidoctor
  module ISO
    module ISOXML
      module Base
        def content(node)
          node.content
        end

        def skip(node, name = nil)
          name = name || node.node_name
          w = "converter missing for #{name} node in ISO backend"
          warning(node, w, nil)
          nil
        end

        def document(node)
          result = ["<?xml version='1.0' encoding='UTF-8'?>\n<iso-standard>"]
          $draft = node.attributes.has_key?("draft")
          result << noko { |ixml| front node, ixml }
          result << noko { |ixml| middle node, ixml }
          result << "</iso-standard>"
          ret1 = Cleanup::cleanup(Nokogiri::XML(result.flatten * "\n"))
          ret1.root.add_namespace(nil, "http://riboseinc.com/isoxml")
          Validate::validate(ret1)
          ret1.to_xml(indent: 2)
        end

        def front(node, xml)
          xml.front do |xml_front|
            title node, xml_front
            metadata node, xml_front
          end
        end

        def middle(node, xml)
          xml.middle do |xml_middle|
            xml_middle << node.content if node.blocks?
          end
        end

        def add_term_source(xml_t, seen_xref, matched)
          attr = {
            target: seen_xref.children[0]["target"],
            format: seen_xref.children[0]["format"],
          }
          xml_t.xref seen_xref.children[0].content, **attr_code(attr)
          xml_t.isosection matched[:section] if matched[:section]
          xml_t.modification { |m| m << matched[:text] } if matched[:text]
        end

        def termsource(node)
          noko do |xml|
            xml.termref do |xml_t|
              matched = /^(?<xref><xref[^>]+>)
              (,\s(?<section>.[^, ]+))?
                (,\s(?<text>.*))?$/x.match node.content
              if matched.nil?
                w = "term reference not in expected format"
                warning(node, w, node.content)
              else
                seen_xref = Nokogiri::XML.fragment(matched[:xref])
                add_term_source(xml_t, seen_xref, matched)
                Validate::style(node, matched[:text])
              end
            end
          end.join("\n")
        end

        def paragraph(node)
          return termsource(node) if node.role == "source"
          noko do |xml|
            xml.p do |xml_t|
              xml_t << node.content
              Validate::style(node, Utils::flatten_rawtext(node).join(" "))
            end
          end.join("")
        end

        def inline_footnote(node)
          noko do |xml|
            xml.fn do |xml_t|
              xml_t << node.text
              Validate::footnote_style(node, node.text)
            end
          end.join("\n")
        end

        def open(node)
          # open block is a container of multiple blocks,
          # treated as a single block.
          # We append each contained block to its parent
          result = []
          if node.blocks?
            node.blocks.each do |b|
              result << send(b.context, b)
            end
          else
            result = paragraph(node)
          end
          result
        end

        def inline_break(node)
          noko do |xml|
            xml << node.text
            xml.br
          end.join("\n")
        end

        def page_break(node)
          noko do |xml|
            xml << node.text
            xml.pagebreak
          end.join("\n")
        end

        def inline_quoted(node)
          noko do |xml|
            case node.type
            when :emphasis then xml.em node.text
            when :strong then xml.strong node.text
            when :monospaced then xml.tt node.text
            when :double then xml << "\"#{node.text}\""
            when :single then xml << "'#{node.text}'"
            when :superscript then xml.sup node.text
            when :subscript then xml.sub node.text
            when :asciimath then xml.stem node.text
            else
              if node.role == "alt"
                xml.admitted_term { |a| a << node.text }
              elsif node.role == "deprecated"
                xml.deprecated_term { |a| a << node.text }
              elsif node.role == "domain"
                xml.termdomain { |a| a << node.text }
              else
                xml << node.text
              end
            end
          end.join
        end
      end
    end
  end
end