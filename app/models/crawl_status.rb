# == Schema Information
#
# Table name: crawl_statuses
#
#  id               :integer          not null, primary key
#  feed_id          :integer          default(0), not null
#  status           :integer          default(1), not null
#  error_count      :integer          default(0), not null
#  error_message    :string(255)
#  http_status      :integer
#  digest           :string(255)
#  update_frequency :integer          default(0), not null
#  crawled_on       :datetime
#  created_on       :datetime         not null
#  updated_on       :datetime         not null
#

class CrawlStatus < ActiveRecord::Base
  STATUS_OK  = 1
  STATUS_NOW = 10

  belongs_to :feed
  attr_accessible :status, :crawled_on

  scope :status_ok, ->{ where(status: STATUS_OK) }
  scope :expired, ->(ttl){ where("crawled_on IS NULL OR crawled_on < ?", ttl.ago) }

  def self.fetch_crawlable_feed(options = {})
    CrawlStatus.update_all("status = #{STATUS_OK}", ['crawled_on < ?', 24.hours.ago])
    feed = nil
    CrawlStatus.transaction do
      if feed = Feed.crawlable.order("crawl_statuses.crawled_on").first
        feed.crawl_status.update_attributes(:status => STATUS_NOW, :crawled_on => Time.now)
      end
    end
    feed
  end

  def change_to_ok
    self.status = STATUS_OK
  end
end
