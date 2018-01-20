require "pp"
module Asciidoctor
  module ISO
    module ISOXML
      module Lists
        def li(xml_ul, item)
          xml_ul.li **attr_code(anchor: item.id) do |xml_li|
            Validate::style(item, item.text)
            if item.blocks?
              xml_li.p { |t| t << item.text }
              xml_li << item.content
            else
              xml_li.p { |p| p << item.text }
            end
          end
        end

        def ulist(node)
          return reference(node, true) if $norm_ref
          return reference(node, false) if $biblio
          noko do |xml|
            xml.ul **attr_code(anchor: node.id) do |xml_ul|
              node.items.each do |item|
                li(xml_ul, item)
              end
            end
          end.join("\n")
        end

        def isorefmatches(xml, matched)
          ref_attributes = {
            anchor: matched[:anchor],
          }
          xml.iso_ref_title **attr_code(ref_attributes) do |t|
            t.isocode matched[:code]
            t.isodate matched[:year] if matched[:year]
            t.isotitle { |i| i << ref_normalise(matched[:text]) }
          end
        end

        def isorefmatches2(xml, matched2)
          ref_attributes = {
            anchor: matched2[:anchor],
          }
          xml.iso_ref_title **attr_code(ref_attributes) do |t|
            t.isocode matched2[:code]
            t.isodate "--"
            t.date_footnote matched2[:fn]
            t.isotitle { |i| i << ref_normalise(matched2[:text]) }
          end
        end

        def isorefmatches3(xml, matched2)
          ref_attributes = {
            anchor: matched2[:anchor],
          }
          xml.iso_ref_title **attr_code(ref_attributes) do |t|
            t.isocode matched2[:code], **attr_code(allparts: true)
            t.isotitle { |i| i << ref_normalise(matched2[:text]) }
          end
        end

        def ref_normalise(ref)
          ref.
            # gsub(/&#8201;&#8212;&#8201;/, " -- ").
            gsub(/&amp;amp;/, "&amp;")
        end

        def reference2(matched, matched2, matched3, xml, item)
          if matched3.nil? && matched2.nil? && matched.nil?
            xml.reference do |t|
              t.p { |p| p << ref_normalise(item) }
            end
          end
          if !matched.nil?
            isorefmatches(xml, matched)
          elsif !matched2.nil?
            isorefmatches2(xml, matched2)
          elsif !matched3.nil?
            isorefmatches3(xml, matched3)
          end
        end

        def reference1(node, item, xml, normative)
          matched = %r{^<ref\sanchor="(?<anchor>[^"]+)">
          \[ISO\s(?<code>[0-9-]+)(:(?<year>[0-9]+))?\]</ref>,?\s
          (?<text>.*)$}x.match item
          matched2 = %r{^<ref\sanchor="(?<anchor>[^"]+)">
          \[ISO\s(?<code>[0-9-]+):--\]</ref>,?\s?
          <fn>(?<fn>[^\]]+)</fn>,?\s?(?<text>.*)$}x.match item
          matched3 = %r{^<ref\sanchor="(?<anchor>[^"]+)">
          \[ISO\s(?<code>[0-9]+)\s\(all\sparts\)\]</ref>(<p>)?,?\s?
          (?<text>.*)(</p>)?$}x.match item
          reference2(matched, matched2, matched3, xml, item)
          if matched3.nil? && matched2.nil? && matched.nil? && normative
            warning(node, "non-ISO/IEC reference not expected as normative",
                    item)
          end
        end

        def reference(node, normative)
          noko do |xml|
            node.items.each do |item|
              reference1(node, item.text, xml, normative)
            end
          end.join("\n")
        end

        def olist(node)
          noko do |xml|
            xml.ol **attr_code(anchor: node.id, type: node.style) do |xml_ol|
              node.items.each do |item|
                li(xml_ol, item)
              end
            end
          end.join("\n")
        end

        def dt(terms, xml_dl)
          terms.each_with_index do |dt, idx|
            Validate::style(dt, dt.text)
            xml_dl.dt { |xml_dt| xml_dt << dt.text }
            if idx < terms.size - 1
              xml_dl.dd
            end
          end
        end

        def dd(dd, xml_dl)
          if dd.nil?
            xml_dl.dd
            return
          end
          xml_dl.dd do |xml_dd|
            Validate::style(dd, dd.text)
            xml_dd.p { |t| t << dd.text } if dd.text?
            xml_dd << dd.content if dd.blocks?
          end
        end

        def dlist(node)
          noko do |xml|
            xml.dl **attr_code(anchor: node.id) do |xml_dl|
              node.items.each do |terms, dd|
                dt(terms, xml_dl)
                dd(dd, xml_dl)
              end
            end
          end.join("\n")
        end

        def colist(node)
          noko do |xml|
            xml.colist **attr_code(anchor: node.id) do |xml_ul|
              node.items.each_with_index do |item, i|
                xml_ul.annotation **attr_code(id: i + 1) do |xml_li|
                  Validate::style(item, item.text)
                  xml_li << item.text
                end
              end
            end
          end.join("\n")
        end
      end
    end
  end
end