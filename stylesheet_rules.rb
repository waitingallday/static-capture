#
module StylesheetRules
  # url() paths in content
  def stylesheet_rules(content)
    parser = CssParser::Parser.new
    parser.add_block!(content)

    assets = []

    parser.each_rule_set do |set|
      set.each_declaration do |dec, val|
        parsed = stylesheet_url_declaration(dec, val)
        assets += parsed unless parsed.nil?
      end
    end

    assets
  end

  private

  def stylesheet_url_declaration(dec, val)
    assets = []

    if ['background-image', 'background'].include? dec
      return unless val.start_with? 'url'
      assets += un_url(val)
    end

    assets += un_fontface_url(val) if dec == 'src'

    assets
  end

  def regex_url(arr, regex)
    matches = []

    arr.each do |res|
      t = res.match regex
      matches << t[1] unless t.nil?
    end

    matches
  end

  def un_url(arg)
    regex_url([arg], %r{^(?:url\(\s*["']?\/)([^'"#?]+)(?:["']?\s*\))})
  end

  def un_fontface_url(arg)
    arg = arg.split('url')
    arg.shift

    regex = %r{(?:\(\s*["']?\/)([^"'?#]+)(?:[\?#]?[^"']*["']?\s*\))(?:;?)}
    regex_url(arg, regex)
  end
end
