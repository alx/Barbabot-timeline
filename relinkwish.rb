# encoding: utf-8

require 'rubygems'
require 'rexml/document'
require 'date'
require 'htmlentities'
require 'time'

class Message

  attr_reader :sender, :link, :time, :content, :content_type, :content_id

  def initialize(line)
    coder = HTMLEntities.new
    if line.match(/sender="(.[^"]*)" time="(.[^"]*)" .*<div><a href="(http:.[^"]*)">.*<\/a> (.*)<\/div>/)
      @sender = $1
      @time = Date.parse($2)
      @link = $3
      text = coder.encode(coder.decode($4).gsub(/<(.*?)>/, ''), :decimal)
      @content = text unless text.match(/.*tetalab(devel)*\/.*/)

      href_ext = @link[-4, 4]
      @content_type = "image" if href_ext==".jpg" || href_ext==".png" || href_ext==".gif" || href_ext==".svg"
      @content_type = "audio" if href_ext==".mp3" || href_ext==".wav" || href_ext==".oga"
      @content_type = "video" if href_ext==".mp4" || href_ext==".ogv" || href_ext==".ogg" || @link[-5, 5]==".webm" || href_ext==".mov"

      if vimeo = @link.scan(/[http|https]\:\/\/vimeo\.com\/.*(\d{8})$/)[0]
        @content_id = vimeo[0]
        @content_type = "vimeo"
      end

      if youtube = @link.scan(/[http|https]\:\/\/www\.youtube\.com\/watch\?.*v=(.{11}).*/)[0]
        @content_id = youtube[0]
        @content_type = "youtube"
      end
    end
  end

  def to_html(show_content = true)
    output = "<li class='timespot "
    output += "hidden" unless show_content
    output +="'><div class='text'><p>"
    output += "<a href=\"#{@link}\">#{@link}</a> #{@content}"

    if @content_type
      output += case @content_type
      when "image"    then '<br><img src="' + @link.gsub(/\"/, '&quot;') + '"><br>'
      when "vimeo"    then '<br><div style="height:238px"><iframe width=400 height=238 src="https://player.vimeo.com/video/' + @content_id + '?title=0&byline=0&portrait=0"></iframe></div>'
      when "youtube"  then '<br><div style="height:238px"><iframe width=400 height=238 src="https://www.youtube.com/embed/' + @content_id + '"></iframe></div>'
      else ""
      end
    end

    output += "</p></div><div class='long_date'>Posted on #{@time.strftime("%B %d, %Y")}</div>"
    output += "<div class='date'>#{@time.strftime("%B %d")}</div></li>"

    return output
  end

end

class CalendarPage

  def initialize(filename, messages)
    @filename = filename
    @messages = messages
  end

  def to_html
    append_file("header.html")
    build_link_list
    build_calendar_menu_list
    append_file("footer.html")
  end

  def html_header(time, show_content = true)
    output = "<li class='month_before year_#{time.year} "
    output += "hidden" unless show_content
    output += "'></li><a name='#{time.strftime("%Y-%m")}'></a>"
    output += "<li class='month "
    output += "hidden" unless show_content
    output += "' id='#{time.strftime("%Y-%m")}'><span class='m'>#{time.strftime("%B")}</span>"
    output += "<span class='y'>#{time.year}</span></li>"
    output += "<li class='month_after"
    output += "hidden" unless show_content
    output += "'></li>"
    return output
  end

  def append_file(origin_file)
    dest_file = File.open(@filename, "a")
    File.open(origin_file, "r") do |content|
      while(line = content.gets)
        dest_file.puts(line)
      end
    end
    dest_file.close
  end

  def build_link_list
    dest_file = File.open(@filename, "a")
    dest_file.puts("<ul class='vertical ' id='timeline'>")

    timeline_years = []
    current_month = 12
    first = true
    show_content = true
    array_index = 0

    @messages.each do |message|
      show_content = false if array_index > 50
      array_index += 1
      if message.time.month != current_month || first
        dest_file.puts(html_header(message.time, show_content)+"\n")
        current_month = message.time.month
        first = false
      end
      dest_file.puts(message.to_html(show_content)+"\n")
    end
    dest_file.puts("</ul>")
    dest_file.close
  end

  def build_calendar_menu_list
    dest_file = File.open(@filename, "a")
    current_month = 12
    count = 0
    first = true
    timeline_footer = "<footer id='timeline_footer'><nav id='navigator'>"
    @messages.reverse.each do |message|
      if message.time.month != current_month
        if current_month == 12
          unless first
            #timeline_footer += "</ul></section>"
          end
          #timeline_footer += "<section class='year'><h2 class='year'><a href=\"#year-#{message.time.year}\" class=\"#{message.time.year}\">#{message.time.year}</a></h2><ul>"
          first = false
        end

        #timeline_footer += "<li><a href=\"##{message.time.strftime("%Y-%m")}\">#{message.time.strftime("%B")}</a></li>"
        current_month = message.time.month
        count = 0
      else
        count += 1
      end
    end
    timeline_footer += "</ul></section></nav></footer>"
    dest_file.puts(timeline_footer)
    dest_file.close
  end

end

class Relinkwish
  @messages = []
  @file_arr = []

  def initialize
    puts "This tool is for removing urls from xml based chat logs"
    @messages = []
  end

  def extract_links(line)
    line.scan(/href="(.*?)"/).flatten
  end

  def strip
    filetypes = File.join("/Users/alx/Library/Application\ Support/Adium\ 2.0/Users/Default/Logs/GTalk.alx.girard\@gmail.com/barbabot\@appspot.com", "**", "*.xml")
    @file_arr = Dir.glob(filetypes)
    pull_all_urls(@file_arr)
  end

  def pull_all_urls(read_these)
    senders = ["alx.girard@gmail.com"]
    all_file_links = []
    read_these.each do |f|
      File.open(f, "r") do |infile|
        while (line = infile.gets)
          message = Message.new line
          if senders.include? message.sender
            @messages << message
          end
        end
      end
    end
    @messages.sort!{|a, b| b.time <=> a.time}
    puts "Complete! #{@messages.size} links"
  end

  def build_link_file
    strip
    
    # For each week, create a file with a list of messages from this week
    begin_day_selection = Time.now

    while !@messages.empty?

      message_index = @messages.index{|message| message.time < DateTime.parse(Time.at(begin_day_selection).to_s)}
      message_list =  @messages.slice! 0, (message_index || @messages.size)

      unless message_list.empty?
        filename = message_list.first.time.strftime("links/%Y_%m_%d.html")

        unless File.exists?(filename)
          page = CalendarPage.new(filename, message_list)
          page.to_html
        end
      end

      begin_day_selection -= 60*60*24*7
    end

    puts "File is built"
  end

  def time_at_midnight(back_in_days = 0)
    #convert today's time to a string
    today = (Time.now - 60*60*24*back_in_days).to_s # => "Mon Dec 12 10:52:45 -0800 2011"

    #replace the hours:minutes:seconds and time-zone to the time and time zone that you need
    today[11, 14] = "00:00:00 +0000" # => "Mon Dec 12 00:00:00 +0000 2011"

    #if you need to, convert the time into a UTC
    return Time.parse(today).strftime("%s").to_i # => 1323648000
  end
end

links = Relinkwish.new
links.build_link_file
