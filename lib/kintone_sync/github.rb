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
      #fetch "/repos/pandeiro245/kintone_portal/issues"
      fetch "/issues?page=#{page}&state=all&filter=all"
    end
  end
end
