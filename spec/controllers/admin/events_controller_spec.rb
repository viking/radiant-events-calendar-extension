require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::EventsController do

  describe "POST create" do
    dataset :users, :events

    before(:each) do
      login_as :admin
      @previous = Radiant::Config['local.timezone']
    end

    it "should parse time correctly" do
      post :create, :event => {
        :name => "foobar", :date => "October 22, 2009",
        :'start_time(5i)' => "12:00:00",
        :'end_time(5i)'   => "13:00:00",
        :timezone => 'Central Time (US & Canada)'
      }
      utc = ActiveSupport::TimeZone.new('UTC')
      event = Event.find_by_name('foobar')
      event.start_time.should == utc.local(2009, 10, 22, 17)
      event.end_time.should   == utc.local(2009, 10, 22, 18)
    end

    after(:each) do
      Radiant::Config['local.timezone'] = @previous
    end
  end
end
