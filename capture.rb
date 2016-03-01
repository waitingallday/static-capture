MAX_THREADS = 8

#
class Capture
  include Helpers
  include PageRules
  include AssetRules

  def initialize(args)
    @current_uri = URI(args[:opts][:source])

    setup_paths
    @threads = []
    @buffer = []
    @semaphore = Queue.new
    MAX_THREADS.times { @semaphore.push(1) } # Init tokens

    print "Capturing from site root #{@site}\n\n"

    capture_page('/')
    @threads.each(&:join)
  end

  def capture_page(loc = '')
    return if (schemaless? loc) || (@sitemap.include? loc)

    @current_uri = URI(@site + loc)

    content = Faraday.get(@site + @current_uri.path).body
    write_file(File.join(loc, 'index.html'), content)

    print "#{@site + loc}index.html\n"

    node = Nokogiri::HTML(content)
    parse_assets(node)
    parse_children(node)
  end

  private

  def setup_paths
    # Force site root for now
    @site = @current_uri.scheme + '://' + @current_uri.host
    @root = URI(@site)
    @current_uri = @root
    @output_loc = File.join(File.dirname(__FILE__), @current_uri.host)
    @sitemap = []
  end

  def parse_assets(node)
    parse_asset_rules(node).each do |asset|
      next if @sitemap.include? asset

      @sitemap << asset

      @threads << Thread.new do
        @semaphore.pop
        output_asset URI(asset)
        @semaphore.push(1)
      end
    end
  end

  def parse_children(node)
    # <a> relative path without .ext
    page_anchor(node).each do |page|
      page = trailing_slash(page)
      next if (@sitemap.include? page) || page.nil?

      @threads << Thread.new do
        @semaphore.pop
        capture_page(page)
        @sitemap << page
        @semaphore.push(1)
      end
    end
  end

  def output_asset(asset_uri)
    remote = File.join(@root.to_s, asset_uri.to_s)
    content = Faraday.get(remote).body

    write_file(asset_uri.path, content)

    print "#{remote}\n"
  end

  def create_path(asset_uri)
    dirs = asset_uri.path.split('/')
    dirs.push # drop root /
    dirs.pop # drop file

    FileUtils.mkdir_p(File.join(@output_loc, dirs)) if dirs.length > 0
  end

  def write_file(file, content)
    create_path(URI(@site + file))

    file = File.join(@output_loc, file)
    next if File.exist? file

    open(file, 'w') do |captured|
      captured.write(content)
    end
  end
end
