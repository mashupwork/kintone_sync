module KintoneSync
  class Twitter
    include ::KintoneSync::Base

    def self.sync
      self.new.sync
    end

    def model_names
      ['Tweet']
    end

    def tweets params = {}
      @client = ::Twitter::REST::Client.new do |config|
        config.consumer_key    = ENV['TWITTER_KEY']
        config.consumer_secret = ENV['TWITTER_SECRET']
        config.access_token    = get('token')
        config.access_token_secret = get('secret')
      end
      #@client.user_timeline("pandeiro245")
      @client.home_timeline
      #@client.search("kintone", result_type: "recent", lang: "ja")
    end
  end
end


