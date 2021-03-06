# frozen_string_literal: true

# unregister all Mime types, keep only :text
Mime::EXTENSION_LOOKUP.map { |i| i.first.to_sym }.each do |f|
  Mime::Type.unregister(f)
end

# re-register some default Mime types
Mime::Type.register "text/html", :html, %w( application/xhtml+xml ), %w( xhtml )
Mime::Type.register "text/plain", :text, [], %w(txt)
Mime::Type.register "application/json", :json, %w( text/x-json application/jsonrequest application/vnd.api+json )
Mime::Type.register "text/csv", :csv

# Mime types supported by bolognese gem https://github.com/datacite/bolognese
Mime::Type.register "application/vnd.crossref.unixref+xml", :crossref
Mime::Type.register "application/vnd.crosscite.crosscite+json", :crosscite
Mime::Type.register "application/vnd.datacite.datacite+xml", :datacite, %w( application/x-datacite+xml )
Mime::Type.register "application/vnd.datacite.datacite+json", :datacite_json
Mime::Type.register "application/vnd.schemaorg.ld+json", :schema_org, %w( application/ld+json )
Mime::Type.register "application/vnd.jats+xml", :jats
Mime::Type.register "application/vnd.citationstyles.csl+json", :citeproc, %w( application/citeproc+json )
Mime::Type.register "application/vnd.codemeta.ld+json", :codemeta
Mime::Type.register "application/x-bibtex", :bibtex
Mime::Type.register "application/x-research-info-systems", :ris
Mime::Type.register "text/x-bibliography", :citation

# register renderers for these Mime types
# :citation and :datacite is handled differently
ActionController::Renderers.add :datacite do |obj, options|
  Array.wrap(obj).map { |o| o.xml }.join("\n")
end

ActionController::Renderers.add :citation do |obj, options|
  begin
    Array.wrap(obj).map do |o|
      o.style = options[:style] || "apa"
      o.locale = options[:locale] || "en-US"
      o.citation
    end.join("\n\n")
  rescue CSL::ParseError # unknown style and/or location
    Array.wrap(obj).map do |o|
      o.style = "apa"
      o.locale = "en-US"
      o.citation
    end.join("\n\n")
  end
end

%w(datacite_json schema_org crosscite citeproc codemeta).each do |f|
  ActionController::Renderers.add f.to_sym do |obj, options|
    if obj.is_a?(Array)
      "[\n" + Array.wrap(obj).map { |o| o.send(f) }.join(",\n") + "\n]"
    else
      obj.send(f)
    end
  end
end

%w(jats).each do |f|
  ActionController::Renderers.add f.to_sym do |obj, options|
    Array.wrap(obj).map { |o| o.send(f) }.join("\n")
  end
end

ActionController::Renderers.add :bibtex do |obj, options|
  Array.wrap(obj).map { |o| o.send("bibtex") }.join("\n")
end

ActionController::Renderers.add :ris do |obj, options|
  Array.wrap(obj).map { |o| o.send("ris") }.join("\n\n")
end

ActionController::Renderers.add :csv do |obj, options|
  options[:header].to_csv +
  Array.wrap(obj).map { |o| o.send("csv") }.join("")
end
