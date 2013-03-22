require "spec_helper"
require "fastladder/crawler"
require "stringio"

module Fastladder
  describe Crawler do
    let(:crawler) do
      described_class.new(options)
    end

    let(:options) do
      {}
    end

    describe ".new" do
      it "initialize a crawler" do
        crawler.should be_a described_class
      end
    end

    describe "#logger" do
      let(:logger) do
        crawler.logger
      end

      it "is a Logger" do
        logger.should be_a Logger
      end

      describe "about its destination to write" do
        context "when options[:log_file] is given" do
          before do
            options[:log_file] = StringIO.new
          end

          it "writes logs into given store" do
            logger.info("test")
            options[:log_file].string.should include("test")
          end
        end

        context "when options[:log_file] is not given" do
          it "writes logs into STDOUT" do
            STDOUT.should_receive(:write).at_least(1).and_call_original
            logger.info("test")
          end
        end
      end

      describe "about its log level" do
        context "when options[:log_level] is given" do
          before do
            options[:log_level] = Logger::DEBUG
          end

          it "has given log level" do
            logger.level.should == Logger::DEBUG
          end
        end

        context "when options[:log_level] is not given" do
          it "has INFO log level" do
            logger.level.should == Logger::INFO
          end
        end
      end
    end
  end
end
