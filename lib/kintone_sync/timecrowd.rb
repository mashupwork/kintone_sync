module KintoneSync
  class Timecrowd
    include ::KintoneSync::Base
    def setting
      {
        site: 'https://timecrowd.net',
      }
    end

    def self.sync(refresh=false)
      self.new.sync(refresh)
    end

    def model_names
      ['Task']
    end

    def tasks params={}
      team_id = params[:team_id]
      page    = params[:page] || 1
      fetch "/api/v1/teams/#{team_id}/tasks?page=#{page}"
    end
  end
end
