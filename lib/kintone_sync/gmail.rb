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
          params[:account] = gmail.username
          
          %w(from to).each do |key|
            params[key.to_sym] = ::Kconv.toutf8(mail.header[key].value)
          end
          #params[:sender] = ::Kconv.toutf8(mail.header['sender'].value)
          #params[:cc] = ::Kconv.toutf8(mail.header['cc'].value)

          params[:subject] = ::Kconv.toutf8(mail.subject)
          #params[:body] = Sanitize.fragment(Kconv.toutf8(mail.body.to_s))
          #params[:body] = Sanitize.fragment(mail.body.decoded)
          body = (mail.parts.present? ? mail.parts.first : mail.body).decoded
          params[:body] =  body
          params[:created_at] =  mail.date
          message_id = mail.message_id.to_s(16)
          params[:message_id] = message_id 
          params[:url_gmail] = "https://mail.google.com/mail/u/#{gmail.username}/#inbox/#{message_id}"

          res.push(params)
        end
        gmail.logout
      end
      return res
    end
  end
end
