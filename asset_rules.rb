#
module AssetRules
  def parse_asset_rules(node)
    assets = []

    assets += asset_link(node)   # <link> relative path with .ext
    assets += asset_script(node) # <script> relative path with .ext
    assets += asset_anchor(node) # <a> relative path with .ext
    assets += asset_img(node)    # <img>
    assets += asset_svg(node)    # <svg> relative path with .ext
    assets += asset_style(node)  # style="background:url()"

    assets.compact
  end

  # <link> relative path with .ext
  def asset_link(node)
    assets = []
    node.css('link[href^="/"]').each do |el|
      next if schemaless? el['href']
      assets << el['href'] if extension? el['href']
    end

    assets
  end

  # <script> relative path with .ext
  def asset_script(node)
    assets = []
    node.css('script[src^="/"]').each do |el|
      next if schemaless? el['src']
      assets << el['src'] if extension? el['src']
    end

    assets
  end

  # <a> relative path with .ext
  def asset_anchor(node)
    assets = []
    node.css('a[href^="/"]').each do |el|
      next if schemaless? el['href']
      assets << el['href'] if extension? el['href']
    end

    assets
  end

  # <img>
  def asset_img(node)
    assets = []
    node.css('img').each do |el|
      next if (absolute? el['src']) || (schemaless? el['src'])
      assets << el['src'] if extension? el['src']
    end

    assets
  end

  # <svg> relative path with .ext
  def asset_svg(node)
    assets = []
    node.css('image').each do |el|
      assets << el['src'] if el.attr('src') && extension?(el.attr('src'))
      if el.attr('xlink:href') && extension?(el.attr('xlink:href'))
        assets << el['xlink:href']
      end
    end

    assets
  end

  # style="background:url()"
  def asset_style(node)
    assets = []
    node.css('[style]').each do |el|
      el[:style].split(';').each do |dir|
        assets << asset_style_directive(dir)
      end
    end

    assets
  end

  def asset_style_directive(arg)
    return unless arg.start_with? 'background'

    regex = %r{^(?:[background].*\:\s?url\(\s*["']?\/)([^'"#?]+)(?:["']?\s*\))}
    arg = arg.match(regex)

    return unless arg
    return if arg[1][0] == '/'

    '/' + arg[1].strip
  end
end
