require "metanorma-standoc"
require_relative "./validate_style.rb"
require_relative "./validate_requirements.rb"
require_relative "./validate_section.rb"
require "nokogiri"
require "jing"
require "pp"
require "iev"

module Asciidoctor
  module ISO
    class Converter < Standoc::Converter
      def title_intro_validate(root)
        title_intro_en = root.at("//title-intro[@language='en']")
        title_intro_fr = root.at("//title-intro[@language='fr']")
        if title_intro_en.nil? && !title_intro_fr.nil?
          warn "No English Title Intro!"
        end
        if !title_intro_en.nil? && title_intro_fr.nil?
          warn "No French Title Intro!"
        end
      end

      def title_main_validate(root)
        title_main_en = root.at("//title-main[@language='en']")
        title_main_fr = root.at("//title-main[@language='fr']")
        if title_main_en.nil? && !title_main_fr.nil?
          warn "No English Title!"
        end
        if !title_main_en.nil? && title_main_fr.nil?
          warn "No French Title!"
        end
      end

      def title_part_validate(root)
        title_part_en = root.at("//title-part[@language='en']")
        title_part_fr = root.at("//title-part[@language='fr']")
        (title_part_en.nil? && !title_part_fr.nil?) &&
          warn("No English Title Part!")
        (!title_part_en.nil? && title_part_fr.nil?) &&
          warn("No French Title Part!")
      end

      def title_subpart_validate(root)
        subpart = root.at("//bibdata/docidentifier/project-number[@subpart]")
        iec = root.at("//bibdata/contributor[role/@type = 'publisher']/"\
                      "organization[abbreviation = 'IEC' or "\
                      "name = 'International Electrotechnical Commission']")
        warn("Subpart defined on non-IEC document!") if subpart && !iec
      end

      def title_names_type_validate(root)
        doctypes = /International\sStandard | Technical\sSpecification |
        Publicly\sAvailable\sSpecification | Technical\sReport | Guide /xi
        title_main_en = root.at("//title-main[@language='en']")
        if !title_main_en.nil? && doctypes.match(title_main_en.text)
          warn "Main Title may name document type"
        end
        title_intro_en = root.at("//title-intro[@language='en']")
        if !title_intro_en.nil? && doctypes.match(title_intro_en.text)
          warn "Title Intro may name document type"
        end
      end

      def title_first_level_validate(root)
        root.xpath(SECTIONS_XPATH).each do |s|
          title = s&.at("./title")&.text || s.name
          s.xpath("./clause | ./terms | ./references").each do |ss|
            subtitle = ss.at("./title")
            !subtitle.nil? && !subtitle&.text&.empty? ||
              warn("#{title}: each first-level subclause must have a title")
          end
        end
      end

      def title_all_siblings(xpath, label)
        notitle = false
        withtitle = false
        xpath.each do |s|
          title_all_siblings(s.xpath("./clause | ./terms | ./references"),
                             s&.at("./title")&.text || s["id"])
          subtitle = s.at("./title")
          notitle = notitle || (!subtitle || subtitle.text.empty?)
          withtitle = withtitle || (subtitle && !subtitle.text.empty?)
        end
        notitle && withtitle &&
          warn("#{label}: all subclauses must have a title, or none")
      end

      def title_validate(root)
        title_intro_validate(root)
        title_main_validate(root)
        title_part_validate(root)
        title_subpart_validate(root)
        title_names_type_validate(root)
        title_first_level_validate(root)
        title_all_siblings(root.xpath(SECTIONS_XPATH), "(top level)")
      end

      def onlychild_clause_validate(root)
        root.xpath(Standoc::Utils::SUBCLAUSE_XPATH).each do |c|
          next unless c.xpath("../clause").size == 1
          title = c.at("./title")
          location = c["id"] || c.text[0..60] + "..."
          location += ":#{title.text}" if c["id"] && !title.nil?
          warn "ISO style: #{location}: subclause is only child"
        end
      end

      def isosubgroup_validate(root)
        root.xpath("//technical-committee/@type").each do |t|
          unless %w{TC PC JTC JPC}.include? t.text
            warn "ISO: invalid technical committee type #{t}"
          end
        end
        root.xpath("//subcommittee/@type").each do |t|
          unless %w{SC JSC}.include? t.text
            warn "ISO: invalid subcommittee type #{t}"
          end
        end
      end

      def see_xrefs_validate(root)
        root.xpath("//xref").each do |t|
          # does not deal with preceding text marked up
          preceding = t.at("./preceding-sibling::text()[last()]")
          next unless !preceding.nil? && /\bsee\s*$/mi.match(preceding)
          (target = root.at("//*[@id = '#{t['target']}']")) || next
          if target&.at("./ancestor-or-self::*[@obligation = 'normative']")
            warn "ISO: 'see #{t['target']}' is pointing to a normative section"
          end
        end
      end

      def see_erefs_validate(root)
        root.xpath("//eref").each do |t|
          preceding = t.at("./preceding-sibling::text()[last()]")
          next unless !preceding.nil? && /\bsee\s*$/mi.match(preceding)
          target = root.at("//*[@id = '#{t['bibitemid']}']")
          if target.at("./ancestor::references"\
              "[title = 'Normative References']")
            warn "ISO: 'see #{t}' is pointing to a normative reference"
          end
        end
      end

      def locality_erefs_validate(root)
        root.xpath("//eref[locality]").each do |t|
          if /^(ISO|IEC)/.match t["citeas"]
            unless /^:[ ]?(\d+{4}|--)$/.match t["citeas"]
              warn "ISO: undated reference #{t['citeas']} should not contain "\
                "specific elements"
            end
          end
        end
      end

      def termdef_warn(text, re, term, msg)
        re.match(text) && warn("ISO style: #{term}: #{msg}")
      end

      def termdef_style(xmldoc)
        xmldoc.xpath("//term").each do |t|
          para = t.at("./definition") || return
          term = t.at("./preferred").text
          termdef_warn(para.text, /^(the|a)\b/i, term,
                       "term definition starts with article")
          termdef_warn(para.text, /\.$/i, term,
                       "term definition ends with period")
        end
        cited_term_style(xmldoc)
      end

      def cited_term_style(xmldoc)
        xmldoc.xpath("//term//xref").each do |x|
          next unless xmldoc.at("//term[@id = '#{x['target']}']")
          x&.previous&.text == " (" and x&.previous&.previous&.name == "em" or
            style_warning(x, "term citation not preceded with italicised term",
                          x.parent.text)
        end
      end

      def content_validate(doc)
        super
        title_validate(doc.root)
        isosubgroup_validate(doc.root)
        onlychild_clause_validate(doc.root)
        termdef_style(doc.root)
        iev_validate(doc.root)
        see_xrefs_validate(doc.root)
        see_erefs_validate(doc.root)
        locality_erefs_validate(doc.root)
      end

      def validate(doc)
        content_validate(doc)
        schema_validate(formattedstr_strip(doc.dup),
                        File.join(File.dirname(__FILE__), "isostandard.rng"))
      end
    end
  end
end
