#
module Helpers
  def schemaless?(path)
    path[0..1] == '//' ? true : false
  end

  def absolute?(path)
    path[0..3] == 'http' ? true : false
  end

  def anchor?(path)
    dirs = path.split('/')
    (dirs.length > 1 && dirs.last[0] == '#') ? true : false
  end

  def extension?(path)
    File.extname(path).empty? ? false : true
  end

  def trailing_slash(path)
    return '/' unless path.is_a? String
    path.insert(-1, '/') unless path[-1] == '/'
    path
  end

  def leading_slash(path)
    return '/' unless path.is_a? String
    path.insert(0, '/') unless path[0] == '/'
    path
  end

  def background_url_regex
    %r{^(?:url\(\s*["']?[.]*\/)([^'"#?]+)(?:["']?\s*\))}
  end

  def fontface_src_regex
    %r{(?:\(\s*["']?[.]*\/)([^"'?#]+)(?:[\?#]?[^"']*["']?\s*\))(?:;?)}
  end
end
