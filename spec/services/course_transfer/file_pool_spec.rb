require "rails_helper"
require "timeout"
require Rails.root.join("app/services/course_transfer/file_pool")

RSpec.describe CourseTransfer::FilePool do
  it "runs independent operations concurrently" do
    started = Queue.new
    release = Queue.new
    coordinator = Thread.new do
      Timeout.timeout(2) { 2.times { started.pop } }
      2.times { release << true }
    end

    described_class.open(size: 2) do |pool|
      2.times do
        pool.post do
          started << true
          release.pop
        end
      end
    end
    coordinator.join
  end

  it "propagates worker errors after all operations finish" do
    expect {
      described_class.open(size: 2) do |pool|
        pool.post { raise "copy failed" }
      end
    }.to raise_error(RuntimeError, "copy failed")
  end
end
