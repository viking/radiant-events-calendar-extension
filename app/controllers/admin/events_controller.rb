class Admin::EventsController < Admin::ResourceController
  helper_method :categories
  before_filter :adjust_times, :only => [ :create, :update ]
  model_class Event

  helper 'admin/references'

  def auto_complete_for_event_category
    find_options = {
      :select => "DISTINCT category",
      :conditions => [ "LOWER(category) LIKE ?", "#{params[:event][:category].downcase}%" ],
      :order => "category ASC",
      :limit => 10 }
    @items = Event.send(:with_exclusive_scope) { Event.all find_options }
    render :inline => "<%= auto_complete_result @items, 'category' %>"
  end

  protected

    def load_models
      # Order the events by date, and exclude any in the past
      self.models = model_class.all(:order => 'date, start_time, name',
                                    :conditions => [ 'date >= ?', Date.today ])
    end

    def categories
      @categories ||= model_class.all({
        :select => "DISTINCT category", :order => "category"
      }).collect(&:category)
    end

    # FIXME: This should be in the model, probably.
    def adjust_times
      Time.use_zone(params[:event][:timezone]) do
        start_time = parse_time(params[:event][:'start_time(5i)'])
        end_time = parse_time(params[:event][:'end_time(5i)'])
        params[:event].delete(:'start_time(5i)')
        params[:event].delete(:'end_time(5i)')

        date = Date.parse(params[:event][:date])
        params[:event][:start_time] = start_time.blank? ? start_time : start_time.change(:year => date.year, :month => date.month, :day => date.day)
        params[:event][:end_time] = end_time.blank? ? end_time : end_time.change(:year => date.year, :month => date.month, :day => date.day)
      end
    end

  private

    def parse_time(str)
      str.blank? ? str : Time.zone.parse(str)
    end

end
