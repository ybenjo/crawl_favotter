require 'nokogiri'
require 'mongo'
require 'yaml'
require 'logger'
require 'date'
require 'time'
require 'open-uri'
require 'fileutils'

class FavotterCrawler
  def initialize(from = '2011-12-30', to = '2011-12-31')
    current = File.dirname(File.expand_path(__FILE__))
    conf = YAML.load_file("#{current}/../config.yaml")

    @db = Mongo::Connection.new('localhost', conf['port']).db(conf['db'])[conf['collections']]
    @sleep = conf['sleep']
    @url = conf['url']
    @from = Date.parse(from)
    @to = Date.parse(to)
    @fav_limit = conf['fav_limit']
    @limit_flag = false

    FileUtils.mkdir("#{current}/../logs") if !File.exist?("#{current}/../logs")
    @log = Logger.new("#{current}/../logs/#{Time.now.strftime('%Y_%m_%d_%H_%M')}.log")
  end

  def get(day)
    1.upto(1/0.0) do |i|
      break if @limit_flag
      begin
        sleep @sleep
        @log.info("Get #{url}")
        url = "#{@url}/home.php?mode=best&date=#{day.to_s}&page=#{i}"
        doc = Nokogiri::HTML(open(url).read)

        (doc/'div.clear'/'div.entry.xfolkentry.hentry').each do |elem|
          tweet = (elem/'span.status_text.description').inner_text.gsub(/\n/, "")
          user_name = (elem/'div.thumb'/'img').attribute('alt').value
          count = (elem/'span.favotters'/'a').size
          updated = Time.parse((elem/'div.info'/'a.taggedlink').first.inner_text)

          if count < @fav_limit
            @limit_flag = true
            @log.info('fav limit.')
            break
          end

          @db.insert({
                       :tweet => tweet,
                       :user_name => user_name,
                       :count => count,
                       :updated => updated
                     })
        end
      rescue => e
        @log.error(e.message)
      end
    end
  end

  def crawl
    @from.upto(@to) do |date|
      get(date)
    end
  end
end


if __FILE__ == $0
  c = FavotterCrawler.new
  c.crawl(ARGV[0], ARGV[1])
end
