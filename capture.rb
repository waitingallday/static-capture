#
class Capture
  def initialize(args)
    @opts = args[:opts]
    @current_uri = URI(@opts[:source])

    # Force site root for now
    @site = @current_uri.scheme + '://' + @current_uri.host
    @root = @current_uri = URI(@site)

    @output_loc = File.join(File.dirname(__FILE__), @current_uri.host)

    @sitemap = []

    puts "Capturing from site root #{@site}\n"
    capture_page('/')
  end

  def capture_page(loc = '')
    # Guard against dupe
    return if @sitemap.include? loc

    # Check for local file
    return if File.exist? File.join(@output_loc, loc, 'index.html')

    @current_page = Faraday.get(@current_uri.to_s).body

    buf = "#{@site + loc}index.html"
    output_page(@current_page, loc)
    print("#{buf}\n")

    @sitemap << @current_uri.path

    parse_assets
    parse_children
  end

  # In page parse rules
  def parse_assets
    assets = []
    node = Nokogiri::HTML(@current_page)

    # <link> relative path with .ext
    node.css('link[href^="/"]').each do |el|
      assets << el['href'] unless File.extname(el['href']).empty?
    end

    # <script> relative path with .ext
    node.css('script[src^="/"]').each do |el|
      next if el['src'][0..1] == '//' # Exclude schema-less
      assets << el['src'] unless File.extname(el['src']).empty?
    end

    # <a> relative path with .ext
    node.css('a[href^="/"]').each do |el|
      assets << el['href'] unless File.extname(el['href']).empty?
    end

    # <img> relative path with .ext
    node.css('img[src^="/"]').each do |el|
      assets << el['src'] unless File.extname(el['src']).empty?
    end

    # <svg> relative path with .ext
    node.css('image[src^="/"]').each do |el|
      assets << el['src'] unless File.extname(el['src']).empty?
      assets << el['xlink:href'] unless File.extname(el['xlink:href']).empty?
    end

    # style="background:url()"
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

    threads = []
    assets.map do |asset|
      threads << Thread.new { process_asset(asset) }
    end
    threads.each(&:join)
  end

  def process_asset(url)
    asset_uri = URI(url)
    file = File.join(@output_loc, asset_uri.path)
    return if File.exist? file

    dirs = asset_uri.path.split('/')
    dirs.push # drop root /
    dirs.pop # drop file
    FileUtils.mkdir_p(File.join(@output_loc, dirs)) if dirs.length > 0

    remote = File.join(@root.to_s, asset_uri.to_s)
    open(file, 'w') do |captured|
      captured.write Faraday.get(remote).body
    end

    print("#{remote}\n")
  end

  def parse_children
    children = []
    node = Nokogiri::HTML(@current_page)

    # <a> relative path without .ext
    node.css('a[href^="/"]').each do |el|
      next if el['href'][0..1] == '/#' # Exclude anchor
      next if el['href'][0..1] == '//' # Exclude schema-less
      children << el['href'] if File.extname(el['href']).empty?
    end

    threads = []
    children.map do |child|
      child += '/' unless child[-1] == '/'
      @current_uri = URI(@site + child)
      threads << Thread.new { capture_page(child) }
    end
    threads.each(&:join)
  end

  private

  def output_page(content, loc = '')
    FileUtils.mkdir_p(File.join(@output_loc, loc))

    open(File.join(@output_loc, loc, 'index.html'), 'w') do |captured|
      captured.write(content)
    end
  end
end
