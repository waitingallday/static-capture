#
module AssetRules
  def parse_asset_rules(node)
    assets = []

    assets.concat(
      asset_link(node)   # <link> relative path with .ext
    ).concat(
      asset_script(node) # <script> relative path with .ext
    ).concat(
      asset_anchor(node) # <a> relative path with .ext
    ).concat(
      asset_img(node)    # <img>
    ).concat(
      asset_svg(node)    # <svg> relative path with .ext
    ).concat(
      asset_style(node)  # style="background:url()"
    )

    assets
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
    node.css('image[src^="/"]').each do |el|
      assets << el['src'] if extension? el['src']
      assets << el['xlink:href'] if extension? el['xlink:href']
    end
    assets
  end

  # style="background:url()"
  def asset_style(node)
    assets = []
    node.css('[style]').each do |el|
      el[:style].split(';').each do |arg|
        next unless arg.start_with? 'background'

        arg = arg.match %r{^[background].*\:\s?url\(\/(.*)[\)].*$}
        if arg
          next if arg[1][0] == '/'
          assets << arg[1].strip
        end
      end
    end
    assets
  end
end
