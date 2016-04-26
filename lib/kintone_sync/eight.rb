require 'csv'
module KintoneSync
  class Eight
    def self.emails
      res = {}
      Kintone.new(ENV['KINTONE_EIGHT']).all.each do |item|
        email = item['e_mail']['value']
        id = item['$id']['value'].to_i
        res[email] = id
      end
      res
    end

    def self.import
      start = 9
      i     = 0
      field_names = []
      emails = self.emails
      CSV.foreach("tmp/eight.csv") do |row|
        i += 1
        field_names = row if row.present? && row.first == '会社名'
        next if i < 9

        next if emails[row[4]].present?

        field_names.each_with_index do |column_name, i2|
          puts "#{column_name}: #{row[i2]}"
        end
      end
    end

    def self.from
      Kintone.new(ENV['KINTONE_EIGHT'])
    end

    def self.to
      Kintone.new(ENV['KINTONE_PEOPLE'])
    end

    def self.sync (refresh =1)
      from = self.from
      to = self.to
      to.remove if refresh
      eight_ids = {}
      if to.all.present?
        to.all.each do |record|
          val = record['eight_id']['value']
          next if val.blank?
          eight_ids[val] = true
        end
      end
      from.all.each do |record|
        next unless record['e_mail']['value']
        #next if eight_ids[record['id']['value']] # CSVにはidなかった
        next if eight_ids[record['e_mail']['value']]
        next if record['Name']['value'].blank?
        next if record['Address']['value'].blank?
        params = {
          Company: record['Company']['value'],
          Address: record['Address']['value'],
          Name: record['Name']['value'],
          Division: record['Division']['value'],
          #eight_id: record['id']['value']
          eight_id: record['e_mail']['value']
        }
        to.save!(params)
      end
    end
  end
end

