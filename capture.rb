MAX_THREADS = 4

#
class Capture
  include Helpers
  include PageRules
  include AssetRules
  include StylesheetRules

  def initialize(args)
    setup_paths(URI(args[:opts][:source]))

    print "Capturing from site root #{@site}\n\n"

    capture_page('/')
  end

  def capture_page(loc = '')
    return if loc.nil?

    file = File.join(loc, 'index.html')
    return if (schemaless? loc) ||
              (@sitemap.include? file) ||
              (File.exist? file)

    current_uri = URI(@site + loc)
    content = Faraday.get(@site + current_uri.path).body
    write_file(file, content)

    node = Nokogiri::HTML(content)
    parse_assets(node)
    parse_children(node)
  end

  private

  def setup_q
    q = Queue.new
    MAX_THREADS.times { q.push(1) }
    q
  end

  def setup_paths(current_uri)
    # Force site root for now
    @site = current_uri.scheme + '://' + current_uri.host
    @root = URI(@site)
    current_uri = @root
    @output_loc = File.join(File.dirname(__FILE__), current_uri.host)
    FileUtils.mkdir_p(@output_loc)
    @sitemap = []
  end

  def parse_assets(node)
    threads = []
    semaphore = setup_q

    parse_asset_rules(node).each do |asset|
      asset_uri = URI(asset)
      next if file_exists(asset_uri.path)
      threads << Thread.new do
        semaphore.pop
        output_asset(asset_uri)
        semaphore.push(1)
      end
    end
    threads.each(&:join)
  end

  def parse_stylesheet(content)
    threads = []
    semaphore = setup_q

    stylesheet_rules(content).each do |asset|
      asset_uri = URI('/'+asset)
      next if file_exists(asset_uri.path)
      threads << Thread.new do
        semaphore.pop
        output_asset(asset_uri)
        semaphore.push(1)
      end
    end
    threads.each(&:join)
  end

  def parse_children(node)
    threads = []
    semaphore = setup_q

    # <a> relative path without .ext
    page_anchor(node).each do |page|
      path = trailing_slash(page)
      next if file_exists(path)
      threads << Thread.new do
        semaphore.pop
        capture_page(path)
        semaphore.push(1)
      end
    end
    threads.each(&:join)
  end

  def output_asset(asset_uri)
    return if file_exists(asset_uri.path)

    remote = File.join(@root.to_s, asset_uri.to_s)
    content = Faraday.get(remote).body

    write_file(asset_uri.path, content)

    # Parse asset content for further assets
    return unless File.extname(asset_uri.to_s) == '.css'
    parse_stylesheet(content)
  end

  def create_path(file)
    asset_uri = URI(@site + file)
    dirs = asset_uri.path.split('/')
    dirs.shift # drop root /
    dirs.pop # drop file

    FileUtils.mkdir_p(File.join(@output_loc, dirs)) if dirs.length > 0
  end

  def write_file(file, content)
    return if file_exists(file)

    create_path(file)
    f = File.join(@output_loc, file)
    open(f, 'w') do |captured|
      captured.write(content)
    end

    @sitemap << file
    print "#{@site + leading_slash(file)}\n"
  end

  def file_exists(file)
    return true if @sitemap.include? file

    f = File.join(@output_loc, file)
    if File.exist? f
      # print "#{@site + leading_slash(file)} [exists]\n"
      @sitemap << file
      return true
    else
      return false
    end
  end
end
