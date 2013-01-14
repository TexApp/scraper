require 'cloudfiles'
require 'uri'
require 'digest/md5'

module TexAppScraper
  class CloudUploader

    FILENAME_SEPARATOR = '_'

    def upload(url, container, prefix)
      file = open(url)
      hash = Digest::MD5.hexdigest(file.path)
      filename = prefix + FILENAME_SEPARATOR + hash
      if container.object_exists?(filename)
      else
        object = container.create_object filename
        object.write file
      end
    end
  end
end
