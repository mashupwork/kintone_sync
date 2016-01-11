require 'kconv'
require 'sanitize'
module KintoneSync
  class Gmail
    include ::KintoneSync::Base

    def self.sync(refresh=false)
      self.new.sync(refresh)
    end

    def model_names
      ['Mail']
    end

    def mails params = {}
      @gmails = []
      res = []
      passwords = ENV['GOOGLE_GMAIL_PASSWORDS'].split(',')
      ENV['GOOGLE_GMAIL_EMAILS'].split(',').each_with_index do |email, i|
        password = passwords[i]
        @gmails.push(::Gmail.connect(email, password))
      end
      @gmails.each do |gmail|
        gmail.inbox.find.each do |mail|
          params = {}
          #raise mail.charset.inspect # => 'UTF-8'
          params[:from] = ::Kconv.toutf8(mail.header['from'].value)
          params[:to] = ::Kconv.toutf8(mail.header['to'].value)
          params[:subject] = ::Kconv.toutf8(mail.subject)
          #params[:body] = Sanitize.fragment(Kconv.toutf8(mail.body.to_s))
          params[:body] = Sanitize.fragment(mail.body.decoded)
          res.push(params)
        end
        gmail.logout
      end
      return res
    end
  end
end
