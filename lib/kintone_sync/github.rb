module KintoneSync
  class Github
    include ::KintoneSync::Base
    def setting
      {
        site: 'https://api.github.com',
      }
    end

    def self.sync(refresh=false)
      self.new.sync(refresh)
    end

    def model_names
      ['Issue']
    end

    def issues params={}
      page = params[:page] || 1
      fetch "/issues?page=#{page}&state=all&assignee_login=all"
    end
  end
end