MAX_THREADS = 8

#
class Capture
  include Helpers
  include PageRules
  include AssetRules

  def initialize(args)
    @current_uri = URI(args[:opts][:source])

    setup_paths

    @semaphore = Queue.new
    @threads = []
    MAX_THREADS.times { @semaphore.push(1) } # Init tokens

    print "Capturing from site root #{@site}\n\n"

    capture_page('/')
    # @threads.each(&:join)
  end

  def capture_page(loc = '')
    file = File.join(loc, 'index.html')
    return if (schemaless? loc) ||
              (@sitemap.include? file) ||
              (File.exist? file)

    @current_uri = URI(@site + loc)

    content = Faraday.get(@site + @current_uri.path).body
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

  def setup_paths
    # Force site root for now
    @site = @current_uri.scheme + '://' + @current_uri.host
    @root = URI(@site)
    @current_uri = @root
    @output_loc = File.join(File.dirname(__FILE__), @current_uri.host)
    @sitemap = []
  end

  def parse_assets(node)
    threads = []
    semaphore = setup_q
    parse_asset_rules(node).each do |asset|
      threads << Thread.new do
        semaphore.pop
        output_asset URI(asset)
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
      threads << Thread.new do
        semaphore.pop
        capture_page(trailing_slash(page))
        semaphore.push(1)
      end
    end
    threads.each(&:join)
  end

  def output_asset(asset_uri)
    remote = File.join(@root.to_s, asset_uri.to_s)
    content = Faraday.get(remote).body

    write_file(asset_uri.path, content)
  end

  def create_path(file)
    asset_uri = URI(@site + file)
    dirs = asset_uri.path.split('/')
    dirs.push # drop root /
    dirs.pop # drop file

    FileUtils.mkdir_p(File.join(@output_loc, dirs)) if dirs.length > 0
  end

  def write_file(file, content)
    return if @sitemap.include? file

    create_path(file)

    f = File.join(@output_loc, file)
    return if File.exist? f

    open(f, 'w') do |captured|
      captured.write(content)
    end

    @sitemap << file
    print "#{@site + file}\n"
  end
end
