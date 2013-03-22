require "spec_helper"
require "fastladder/crawler"
require "stringio"

module Fastladder
  describe Crawler do
    let(:crawler) do
      described_class.new
    end

    describe ".new" do
      it "initialize a crawler" do
        crawler.should be_a described_class
      end
    end

    describe "#start" do
      before do
        count = 0
        CrawlStatus.stub(:fetch_crawlable_feed) do
          count += 1
          raise Interrupt if count == 100
        end
        crawler.stub(:sleep)
      end

      it "increments sleep interval at most 60" do
        crawler.start
        crawler.send(:interval).should == 60
      end

      context "when Interrupt is raised" do
        it "exits" do
          crawler.start
        end
      end
    end
  end
end
