class Event < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  extend ActionView::Helpers::SanitizeHelper::ClassMethods

  validates_presence_of :name, :message => 'An event name must be specified'
  validates_presence_of :date, :message => 'A date must be specified'
  validates_length_of :filter_id, :maximum => 25, :allow_nil => true, :message => '{{count}}-character limit'
  validate :ensure_start_time_and_end_time_are_sane

  default_scope :order => "date, start_time"

  named_scope :for_date, lambda {|date| { :conditions => [ 'date = ?', date ], :order => 'start_time, name' } }
  named_scope :for_month, lambda {|month, year| { :conditions => [ 'date BETWEEN ? AND ?', Date.civil(year,month,1), Date.civil(year,month,-1) ] } }

  object_id_attr :filter, TextFilter

  attr_accessor :new_category

  def time(options = {})
    return nil unless start_time.is_a?(Time)

    format = options[:format] || '%H:%M'
    connector = options[:connector] || '-'

    str = start_time.strftime(format)
    str << " #{connector} #{end_time.strftime(format)}" if end_time.is_a?(Time)

    str
  end

  # Return a shortened description.
  # The <tt>:truncate</tt> option truncates the description to the specified number of characters.
  # The <tt>:sentences</tt> options truncates the description to the first N sentences.
  # If no options are specified, the first sentence is returned.
  #
  # A sentence is considered to end with a `.`, `!`, or `?`, followed by one or
  # more whitespace characters. This simple definition means that the string
  # "Good morning Mr. Teabag. A Mr. Pudey is waiting in your office." contains
  # four, not two, sentences.
  def short_description(options = {})
    return nil unless description
    if options[:truncate]
      l = options[:truncate] - 3
      chars = sanitize(description_html || description, :tags => %w(strong em b i sup sub br))
      (chars.length > options[:truncate] ? truncate_html(chars, :length => l) : description).to_s
    else
      count = [ options[:sentences].to_i, 1 ].max
      description.split(/([!.?])\s+/, count+1).in_groups_of(2)[0,count].collect{|arr| arr.join}.join(' ')
    end
  end

  def start_time
    if self['start_time'].is_a?(Time)
      self['start_time'].in_time_zone(self['timezone'])
    end
  end

  def end_time
    if self['end_time'].is_a?(Time)
      self['end_time'].in_time_zone(self['timezone'])
    end
  end

  protected

    def ensure_start_time_and_end_time_are_sane
      if end_time.is_a?(Time)
        if !start_time.is_a?(Time)
          errors.add(:start_time, "The event's start time must be specified when an end time is specified")
        elsif start_time >= end_time
          errors.add(:start_time, "The event's start time must be earlier than its end time")
        end
      end
    end

    def after_initialize
      self.filter_id ||= Radiant::Config['defaults.page.filter'] if new_record?
    end

    def before_save
      if self.timezone.blank?
        rtz = Radiant::Config['local.timezone']
        self.timezone = rtz.blank? ? 'UTC' : rtz
      end

      self.description_html = sanitize(filter.filter(description))

      if self.new_category.present?
        self.category = self.new_category
      end
    end

  private

    def filter
      filter_id.blank? ? SimpleFilter.new : TextFilter.descendants.find{|f| f.filter_name == filter_id}
    end

    class SimpleFilter
      include ERB::Util
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::TagHelper

      def filter(content)
        simple_format(h(content))
      end
    end

    require 'rexml/parsers/pullparser'

    # Truncate text that includes HTML tags.
    #
    # The HTML tags are not included in the length calculation. Any unterminated
    # HTML tags, caused by the truncation, are properly terminated in the result
    # string.
    #
    # Adapted from http://www.railsgarden.com/2007/12/09/html-aware-truncate-text/
    #
    # ==== Examples
    #
    #   truncate_html("<b>Lorem ipsum <em>dolor sit</em> amet</b>, consectetuer adipiscing elit.", :length => 20))
    #   # => <b>lorem ipsum <em>dolor</em></b>...
    def truncate_html(input, options = {})
      def attrs_to_s(attrs)
        return '' if attrs.empty?
        attrs.to_a.map { |attr| %{#{attr[0]}="#{attr[1]}"} }.join(' ')
      end

      len = options[:length] || 30
      extension = options[:omission] || "..."

      p = REXML::Parsers::PullParser.new(input)
      tags = []
      new_len = len
      results = ''
      while p.has_next? && new_len > 0
        p_e = p.pull
        case p_e.event_type
        when :start_element
          tags.push p_e[0]
          results << "<#{tags.last}"
          results << " #{attrs}" unless (attrs = attrs_to_s(p_e[1])).blank?
          results << ">"
        when :end_element
          results << "</#{tags.pop}>"
        when :text
          results << p_e[0].first(new_len)
          new_len -= p_e[0].length
        else
          results << "<!-- #{p_e.inspect} -->"
        end
      end

      tags.reverse.each do |tag|
        results << "</#{tag}>"
      end

      results.to_s + (input.length > len ? extension : '')
    end

end
