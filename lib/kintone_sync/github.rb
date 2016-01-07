module KintoneSync
  class Github
    include ::KintoneSync::Base
    def setting
      {
        site: 'https://api.github.com',
      }
    end

    def self.sync
      self.new.sync
    end

    def model_names
      ['Issue']
    end

    def issues params={}
      page = params[:page] || 1
      fetch "/issues?page=#{page}&state=all"
    end
  end
end
