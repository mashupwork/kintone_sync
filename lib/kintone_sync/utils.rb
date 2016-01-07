module KintoneSync
  module Utils
    def key2path key
      provider = self.class.to_s
      .split('::').last.downcase
      "tmp/#{provider}_#{key}.txt"
    end

    def exist? key
      File.exist?(key2path(key))
    end

    def get key
      return nil unless exist? key
      File.open(key2path(key), 'r').read
    end

    def set key, val
      File.open(key2path(key), 'w') { |file| file.write(val) }
    end
  end
end
