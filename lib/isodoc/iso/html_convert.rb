require "isodoc"
require_relative "metadata"

module IsoDoc
  module Iso
    class HtmlConvert < IsoDoc::HtmlConvert
      def metadata_init(lang, script, labels)
        @meta = Metadata.new(lang, script, labels)
      end

      def initialize(options)
        @libdir = File.dirname(__FILE__)
        super
      end

      def default_fonts(options)
        {
          bodyfont: (options[:script] == "Hans" ? '"SimSun",serif' : options[:alt] ? '"Lato",sans-serif' : '"Cambria",serif'),
          headerfont: (options[:script] == "Hans" ? '"SimHei",sans-serif' : options[:alt] ? '"Lato",sans-serif' : '"Cambria",serif'),
          monospacefont: (options[:alt] ?  '"Space Mono",monospace' : '"Courier New",monospace'),
        }
      end

      def default_file_locations(options)
        {
          htmlstylesheet: options[:alt] ? html_doc_path("style-human.scss") : html_doc_path("style-iso.scss"),
          htmlcoverpage: html_doc_path("html_iso_titlepage.html"),
          htmlintropage: html_doc_path("html_iso_intro.html"),
          scripts: html_doc_path("scripts.html"),
        }
      end

      def implicit_reference(b)
        isocode = b.at(ns("./docidentifier")).text
        isocode == "IEV"
      end

      def introduction(isoxml, out)
        f = isoxml.at(ns("//introduction")) || return
        num = f.at(ns(".//clause")) ? "0" : nil
        title_attr = { class: "IntroTitle" }
        page_break(out)
        out.div **{ class: "Section3", id: f["id"] } do |div|
          # div.h1 "Introduction", **attr_code(title_attr)
          clause_name(num, @introduction_lbl, div, title_attr)
          f.elements.each do |e|
            if e.name == "patent-notice"
              e.elements.each { |e1| parse(e1, div) }
            else
              parse(e, div) unless e.name == "title"
            end
          end
        end
      end

      def foreword(isoxml, out)
        f = isoxml.at(ns("//foreword")) || return
        page_break(out)
        out.div **attr_code(id: f["id"]) do |s|
          s.h1(**{ class: "ForewordTitle" }) { |h1| h1 << @foreword_lbl }
          f.elements.each { |e| parse(e, s) unless e.name == "title" }
        end
      end

      def initial_anchor_names(d)
        super
        introduction_names(d.at(ns("//introduction")))
      end

      # we can reference 0-number clauses in introduction
      def introduction_names(clause)
        return if clause.nil?
        clause.xpath(ns("./clause")).each_with_index do |c, i|
          section_names1(c, "0.#{i + 1}", 2)
        end
      end

      # terms not defined in standoc
      def error_parse(node, out)
        case node.name
        when "appendix" then clause_parse(node, out)
        else
          super
        end
      end

      def annex_names(clause, num)
        appendix_names(clause, num)
        super
      end

      def appendix_names(clause, num)
        clause.xpath(ns("./appendix")).each_with_index do |c, i|
          @anchors[c["id"]] = anchor_struct(i + 1, nil, @appendix_lbl, "clause")
          @anchors[c["id"]][:level] = 2
          @anchors[c["id"]][:container] = clause["id"]
        end
      end

      def section_names1(clause, num, level)
        @anchors[clause["id"]] =
          { label: num, level: level, xref: num }
        # subclauses are not prefixed with "Clause"
        clause.xpath(ns("./clause | ./terms | ./term | ./definitions")).
          each_with_index do |c, i|
          section_names1(c, "#{num}.#{i + 1}", level + 1)
        end
      end

      def annex_names1(clause, num, level)
        @anchors[clause["id"]] = { label: num, xref: num, level: level }
        clause.xpath(ns(".//clause")).each_with_index do |c, i|
          annex_names1(c, "#{num}.#{i + 1}", level + 1)
        end
      end

      def eref_localities1_zh(target, type, from, to)
        subsection = from&.text&.match(/\./)
        ret = type == "list" ? "" : ","
        ret += " 第#{from.text}" if from
        ret += "&ndash;#{to}" if to
        loc = (@locality[type] || type.sub(/^locality:/, "").capitalize )
        ret += " #{loc}" unless subsection && type == "clause" || type == "list" || target.match(/^IEV$/)
        ret += ")" if type == "list"
        ret
      end

      def eref_localities1(target, type, from, to, lang = "en")
        subsection = from&.text&.match(/\./)
        return l10n(eref_localities1_zh(target, type, from, to)) if lang == "zh"
        ret = type == "list" ? "" : ","
        loc = @locality[type] || type.sub(/^locality:/, "").capitalize
        ret += " #{loc}" unless subsection && type == "clause" || type == "list" || target.match(/^IEV$/)
        ret += " #{from.text}" if from
        ret += "&ndash;#{to.text}" if to
        ret += ")" if type == "list"
        l10n(ret)
      end

      def prefix_container(container, linkend, target)
        delim = get_anchors[target][:type] == "listitem" ? " " : ", "
        l10n(get_anchors[container][:xref] + delim + linkend)
      end
    end
  end
end
