module KintoneSync
  class Facebook
    include ::KintoneSync::Base
    def self.setting
      {
        site: 'https://graph.facebook.com/v2.5/',
        model_names: ['Group', 'Feed', 'Event', 'Like']
      }
    end

    def me
      fetch "/me"
    end

    def mine key
      fetch("/#{me['id']}/#{key}")
    end
   
    def likes
      mine 'likes'
    end

    def events
      mine 'events'
    end

    def friends
      mine 'friends'
    end

    def feeds
      mine 'feed'
    end

    def groups
      mine 'groups'
    end
  end
end

