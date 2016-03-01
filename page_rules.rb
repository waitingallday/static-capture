#
module PageRules
  # <a> relative path without .ext
  def page_anchor(node)
    pages = []
    node.css('a[href^="/"]').each do |el|
      next if (schemaless? el['href']) ||
              (anchor? el['href']) ||
              el['href'] == '/'

      # split on ?
      uri = URI(el['href'])
      pages << uri.path unless extension? uri.path
    end
    pages
  end
end
