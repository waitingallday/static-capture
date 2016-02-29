MAX_THREADS = 8

#
class Capture
  def initialize(args)
    @opts = args[:opts]
    @current_uri = URI(@opts[:source])

    # Force site root for now
    @site = @current_uri.scheme + '://' + @current_uri.host
    @root = URI(@site)
    @current_uri = @root

    @output_loc = File.join(File.dirname(__FILE__), @current_uri.host)

    @sitemap = []

    @threads = []
    @semaphore = Queue.new
    MAX_THREADS.times { @semaphore.push(1) } # Init tokens

    print "Capturing from site root #{@site}\n\n"

    @threads << Thread.new do
      @semaphore.pop
      capture_page('/')
      @semaphore.push(1)
    end
    @threads.each(&:join)
  end

  def capture_page(loc = '')
    # Guard against dupe
    return if @sitemap.include? loc

    # Check for local file
    return if File.exist? File.join(@output_loc, loc, 'index.html')

    @current_uri = URI(@site + loc)
    @current_page = Faraday.get(@current_uri.to_s).body
    output_page(@current_page, loc)

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

    assets.map do |asset|
      @threads << Thread.new do
        @semaphore.pop
        output_asset URI(asset)
        @semaphore.push(1)
      end
    end
  end

  def parse_children
    children = []
    node = Nokogiri::HTML(@current_page)

    # <a> relative path without .ext
    node.css('a[href^="/"]').each do |el|
      next if el['href'][0..1] == '//' # Exclude schema-less
      dirs = el['href'].split('/')
      next if dirs.length > 1 && dirs.last[0] == '#' # Exclude anchor
      children << el['href'] if File.extname(el['href']).empty?
    end

    children.map do |child|
      child += '/' unless child[-1] == '/'

      @threads << Thread.new do
        @semaphore.pop
        capture_page(child)
        @semaphore.push(1)
      end
    end
  end

  private

  def output_asset(asset_uri)
    file = File.join(@output_loc, asset_uri.path)
    return if (File.exist? file) || (@sitemap.include? file)

    remote = File.join(@root.to_s, asset_uri.to_s)

    dirs = asset_uri.path.split('/')
    dirs.push # drop root /
    dirs.pop # drop file
    FileUtils.mkdir_p(File.join(@output_loc, dirs)) if dirs.length > 0

    open(file, 'w') do |captured|
      captured.write(Faraday.get(remote).body)
    end

    @sitemap << file
    print "#{remote}\n"
  end

  def output_page(content, loc = '')
    file = File.join(@output_loc, loc, 'index.html')
    return if (File.exist? file) || (@sitemap.include? file)

    FileUtils.mkdir_p(File.join(@output_loc, loc))

    open(file, 'w') do |captured|
      captured.write(content)
    end

    @sitemap << file
    print "#{@site + loc}index.html\n"
  end
end
