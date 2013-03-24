require "fastladder"
require "digest/sha1"
require "tempfile"
begin
  require "image_utils"
rescue LoadError
end

module Fastladder
  class Crawler
    INTERVAL_MAX   = 60
    ITEMS_LIMIT    = 500
    REDIRECT_LIMIT = 5
    GETA           = [12307].pack("U")

    def self.start
      new.start
    end

    def start
      step until finished?
    end

    private

    def step
      sleep_interval
      crawl
    rescue Interrupt
      finish
    rescue Exception
    end

    def crawl
      if feed = CrawlStatus.fetch_crawlable_feed
        clear_interval
        handle_result(fetch(feed))
      else
        increment_interval
      end
    end

    def handle_result(result)
      if result[:error]
      elsif crawl_status = feed.crawl_status
        crawl_status.http_status = result[:response_code]
        crawl_status.change_to_ok
        crawl_status.save
      end
    end

    def finished?
      !!@finished
    end

    def finish
      @finished = true
    end

    def sleep_interval
      sleep(interval)
    end

    def interval
      @interval ||= 0
    end

    def clear_interval
      @interval = 0
    end

    def increment_interval
      @interval = [INTERVAL_MAX, interval + 1].min
    end

    def fetch(feed, redirect_count = 0)
      case response = Fastladder.fetch(feed.feedlink, :modified_on => feed.modified_on)
      when Net::HTTPNotModified
        {
          :message       => '',
          :error         => false,
          :response_code => response.code.to_i,
        }
      when Net::HTTPSuccess
        ret = update(feed, response)
        {
          :message       => "#{ret[:new_items]} new items, #{ret[:updated_items]} updated items",
          :error         => false,
          :response_code => response.code.to_i,
        }
      when Net::HTTPRedirection
        feed.update_attributes(
          :feedlink    => URI.join(feed.feedlink, response["location"]),
          :modified_on => nil
        )
        if redirect_count == REDIRECT_LIMIT
          {
            :message       => '',
            :error         => false,
            :response_code => response.code.to_i,
          }
        else
          fetch(feed, redirect_count + 1)
        end
      else
        {
          :message       => "Error: #{response.code} #{response.message}",
          :error         => true,
          :response_code => response.code.to_i,
        }
      end
    end

    private

    def update(feed, response)
      result = {
        :new_items     => 0,
        :updated_items => 0,
        :error         => nil
      }

      parsed = Feedzirra::Feed.parse(response.body)
      return result unless parsed

      items = parsed.entries.map {|item|
        Item.new(
          :author         => item.author,
          :body           => item.content || item.summary,
          :category       => item.categories.first,
          :digest         => item_digest(item),
          :enclosure      => nil,
          :enclosure_type => nil,
          :feed_id        => feed.id,
          :link           => item.url || "",
          :modified_on    => item.published ? item.published.to_datetime : nil,
          :stored_on      => Time.now,
          :title          => item.title || "",
        )
      }.first(ITEMS_LIMIT).reject {|item|
        feed.items.exists?(["link = ? and digest = ?", item.link, item.digest])
      }

      if items.size > ITEMS_LIMIT / 2
        Items.delete_all(["feed_id = ?", feed.id])
      end

      items.reverse_each do |item|
        if old_item = feed.items.find_by_link(item.link)
          old_item.increment(:version)
          unless almost_same(old_item.title, item.title) and almost_same((old_item.body || "").html2text, (item.body || "").html2text)
            old_item.stored_on = item.stored_on
            result[:updated_items] += 1
          end
          %w(title body author category enclosure enclosure_type digest stored_on modified_on).each do |col|
            old_item.send("#{col}=", item.send(col))
          end
          old_item.save
        else
          feed.items << item
          result[:new_items] += 1
        end
      end

      if result[:updated_items] + result[:new_items] > 0
        modified_on = Time.now
        if last_item = feed.items.recent.first
          modified_on = last_item.created_on
        elsif last_modified = sourece["last-modified"]
          modified_on = Time.rfc2822(last_modified)
        end
        feed.modified_on = modified_on
        Subscription.update_all(["has_unread = ?", true], ["feed_id = ?", feed.id])
      end

      feed.title       = parsed.title
      feed.link        = parsed.url
      feed.description = parsed.description || ""
      feed.save
      feed.fetch_favicon!

      GC.start

      result
    end

    def item_digest(item)
      str = "#{item.title}#{item.content}"
      str = str.gsub(%r{<br clear="all"\s*/>\s*<a href="http://rss\.rssad\.jp/(.*?)</a>\s*<br\s*/>}im, "")
      str = str.gsub(/\s+/, "")
      Digest::SHA1.hexdigest(str)
    end

    def almost_same(str1, str2)
      # Compare string
      return true if str1 == str2

      chars1 = str1.split(//)
      chars2 = str2.split(//)

      # Compare character length
      return false if chars1.length != chars2.length

      # Count character differences
      [chars1, chars2].transpose.select { |pair|
        !pair.include?(GETA) && pair[0] != pair[1]
      }.size <= 5
    end
  end
end
