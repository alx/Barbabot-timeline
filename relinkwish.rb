require 'rubygems'
require 'rexml/document'
require 'date'
require 'htmlentities'

class Relinkwish
  @link_arr = []
  @file_arr = []

  def initialize
    puts "This tool is for removing urls from xml based chat logs"
    @link_arr = []
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
    coder = HTMLEntities.new
    read_these.each do |f|
      File.open(f, "r") do |infile|
        while (line = infile.gets)
          if line.match(/sender="(.[^"]*)" time="(.[^"]*)" .*<div><a href="(http:.[^"]*)">.*<\/a> (.*)<\/div>/)
            sender = $1
            time = Date.parse($2)
            link = $3
            text = coder.encode(coder.decode($4).gsub(/<(.*?)>/, ''), :decimal)
            if senders.include? sender
              unless text.match(/.*tetalab(devel)*\/.*/)
                data = {:time => time, :link => link, :text => text}
                @link_arr << data
              end
            end
          end
        end
      end
    end
    @link_arr.sort!{|a, b| b[:time] <=> a[:time]}
    #@link_arr = all_file_links.flatten.uniq
    puts "Complete! #{@link_arr.size} links"
  end

  def build_link_file
    strip
    
    index = File.open("index.html", "w+")

    File.open("header.html", "r") do |header|
      while(line = header.gets)
        index.puts(line)
      end
    end

    index.puts("<ul class='vertical ' id='timeline'>")
    timeline_years = []
    current_month = 12
    first = true
    @link_arr.each do |link|
      if link[:time].month != current_month || first
        month_title = "<li class='month_before year_#{link[:time].year}'></li><a name='#{link[:time].strftime("%Y-%m")}'></a>"
        month_title += "<li class='month' id='#{link[:time].strftime("%Y-%m")}'><span class='m'>#{link[:time].strftime("%B")}</span>"
        month_title += "<span class='y'>#{link[:time].year}</span></li>"
        month_title += "<li class='month_after'></li>"
        index.puts(month_title+"\n")
        current_month = link[:time].month
        first = false
      end

      final_link = "<li class='timespot'><div class='text'><p>"
      final_link += "<a href=\"#{link[:link]}\">#{link[:link]}</a> #{link[:text]}"

      href_ext = link[:link][-4, 4];
      #
      # image
      if href_ext==".jpg" || href_ext==".png" || href_ext==".gif" || href_ext==".svg"
        final_link += '<br><img src="' + link[:link].gsub(/\"/, '&quot;') + '"><br>'
      end

      # YouTube
      #if youtube = link[:link].scan(/[http|https]\:\/\/www\.youtube\.com\/watch\?v=(.{11})/)[0]
      #  youtube_id = youtube[0]
      #  final_link += '<br><div style="height:385px"><iframe width=640 height=385 src="https://www.youtube.com/embed/' + youtube_id + '"></iframe></div>'
      #end

      # Vimeo
      if vimeo = link[:link].scan(/[http|https]\:\/\/vimeo\.com\/.*(\d{8})$/)[0]
        vimeo_id = vimeo[0]
        final_link += '<br><div style="height:238px"><iframe width=400 height=238 src="https://player.vimeo.com/video/' + vimeo_id + '?title=0&byline=0&portrait=0"></iframe></div>'
      end

      final_link += "</p></div><div class='long_date'>Posted on #{link[:time].strftime("%B %d, %Y at %H:%M")}</div>"
      final_link += "<div class='date'>#{link[:time].strftime("%B %d")}</div></li>"
      index.puts(final_link+"\n")
    end
    index.puts("</ul>")

    current_month = 12
    count = 0
    first = true
    timeline_footer = "<footer id='timeline_footer'><nav id='navigator'>"
    @link_arr.reverse.each do |link|
      if link[:time].month != current_month
        if current_month == 12
          unless first
            timeline_footer += "</ul></section>"
          end
          timeline_footer += "<section class='year'><h2 class='year'><a href=\"#year-#{link[:time].year}\" class=\"#{link[:time].year}\">#{link[:time].year}</a></h2><ul>"
          first = false
        end

        timeline_footer += "<li><a href=\"##{link[:time].strftime("%Y-%m")}\">#{link[:time].strftime("%B")}</a></li>"
        current_month = link[:time].month
        count = 0
      else
        count += 1
      end
    end
    timeline_footer += "</ul></section></nav></footer>"
    index.puts(timeline_footer)

    File.open("footer.html", "r") do |footer|
      while(line = footer.gets)
        index.puts(line)
      end
    end


    index.close
    puts "File is built"
  end

  def how_many?
    return @link_arr.count
  end

  def view_a_url(num)
    viewing = @link_arr[num]
    viewing.gsub("href=\"", "").chomp("\"")
  end

  def output_messages_by_file_by_id(file_id)
    traversable = REXML::Document.new(file)
    chat = traversable.root
    puts "FROM: #{chat.attributes["service"]}"
    puts "----------------------------------"
    puts chat.elements["message"].attributes["sender"]
    traversable.elements.each("message") do |msg|
      puts "#{msg.atrributes["sender"]} said __ :: __ #{msg}"
    end
  end
end

links = Relinkwish.new
links.build_link_file
