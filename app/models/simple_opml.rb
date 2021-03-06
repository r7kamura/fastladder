require 'kconv'
class SimpleOPML
  def initialize
    @outline = []
  end

  def add_item(item)
    @outline << site_to_outline(item)
  end

  def add_outline(folder, items)
    str = %!<outline text="#{CGI.escapeHTML folder}">!
    str += items.map {|item| site_to_outline item }.join("")
    str += "</outline>"
    @outline << str
  end

  def generate_opml
    <<EOD
<?xml version="1.0" encoding="utf-8"?>
<opml version="1.0">
<head>
<title>Subscriptions</title>
<dateCreated>#{Time.now.rfc822}</dateCreated>
<ownerName />
</head>
<body>
#{@outline.join("")}
</body>
</opml>
EOD
  end

  def site_to_outline(site)
    %!<outline title="#{CGI.escapeHTML site[:title].toutf8}" htmlUrl="#{CGI.escapeHTML site[:link]}" text="#{CGI.escapeHTML site[:title].toutf8}" type="rss" xmlUrl="#{CGI.escapeHTML site[:feedlink]}" />\n!
  end
end
