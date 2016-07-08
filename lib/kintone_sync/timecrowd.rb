module KintoneSync
  class Timecrowd
    include ::KintoneSync::Base
    def setting
      {
        site: 'https://timecrowd.net',
      }
    end

    def tasks params={}
      fetch_all "/api/v1/teams/5/tasks", pager_key: 'page'
    end

    def time_entries params={}
      res = []
      tasks.each do |task|
        res += fetch "/api/v1/teams/5/tasks/#{task['id']}/time_entries"
      end
      res
    end

    def model_names
      #['Task']
      ['TimeEntry']
    end
  end
end

