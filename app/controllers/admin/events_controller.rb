class Admin::EventsController < Admin::ResourceController
  before_filter :adjust_times, :only => [ :create, :update ]
  model_class Event

  helper 'admin/references'

  protected

    def load_models
      # Order the events by date, and exclude any in the past
      self.models = model_class.all(:order => 'date, start_time, name',
                                    :conditions => [ 'date >= ?', Date.today ])
    end

    def adjust_times
      start_time = parse_time(params[:event][:'start_time(5i)'])
      end_time = parse_time(params[:event][:'end_time(5i)'])
      params[:event].delete(:'start_time(5i)')
      params[:event].delete(:'end_time(5i)')

      date = Date.parse(params[:event][:date])
      params[:event][:start_time] = start_time.blank? ? start_time : start_time.change(:year => date.year, :month => date.month, :day => date.day)
      params[:event][:end_time] = end_time.blank? ? end_time : end_time.change(:year => date.year, :month => date.month, :day => date.day)
    end

  private

    def parse_time(str)
      str.blank? ? str : Time.zone.parse(str)
    end

end
