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
    "#{path.chomp('/')}/"
  end

  def leading_slash(path)
    "/#{path.reverse.chomp('/').reverse}"
  end
end
