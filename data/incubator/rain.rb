require 'net/http'
require 'json'
require 'fileutils'
require 'chunky_png'
require 'MeCab'
require 'uri'


begin
  $base_url = "http://weather.map.c.yimg.jp/weather?"
  $base_dir = "/root/twitter/data/incubator/"
  start = Time.now
  json_file = "#{$base_dir}small.json"
  out_file = "#{$base_dir}small_edited.json"
  log_file = "#{$base_dir}log.txt"
  tweet_log_file = "#{$base_dir}tweet_log.txt"
  error_file = "#{$base_dir}error_log.txt"

  json = File.read(json_file)
  data_array = JSON.parse(json)
  rain = File.open(out_file,'w')
  log = File.open(log_file,'w')
  tweet_log = File.open(tweet_log_file,'w')
  error_log = File.open(error_file,'w')

  cnt_all = 0 # all
  geo_cnt = 0 # geo_enabled == false
  plc_cnt = 0 # place == nil
  ctd_cnt = 0 # timezone != 0900
  c_cnt = 0 # country != Japan
  l_cnt = 0 # lang != ja
  cnt = 0 # normal
  edt_cnt = 0 # text edited
  $rain_cnt0 = 0 # rain 0
  $rain_cnt15 = 0 # other color
  png_cnt = 0 # downloaded png
  $no_png_cnt = 0 # can't download

  data_array['tweets'].each do |tweet|
    cnt_all += 1
    if tweet["user"]["geo_enabled?"]!="true"
      geo_cnt += 1
    elsif tweet["place"]==nil
      plc_cnt += 1
    elsif tweet["created_at"][-4,4]!="0900"
      ctd_cnt += 1
    elsif tweet["place"]["country"]!="日本"
      c_cnt += 1
    elsif tweet["lang"]!="ja"
      l_cnt += 1
    else
      #normal tweet
      cnt += 1
      create_url(tweet["created_at"], tweet["coordinates"])
      $rain_v = 16
      def_rain   
      tweet["rain"] = $rain_v

      mecab_start = Time.now
      old_text = tweet["text"]
      new_text = mecaber(old_text)
      if old_text != new_text
	tweet["edited"]=true
	tweet["text"]=new_text
	edt_cnt += 1
      else
	tweet["edited"]=false
      end
      mecab_end = Time.now
      log.puts "Tweet:#{tweet['id']}, MecabTime:#{mecab_end-mecab_start}"
    end
  end

  rain.puts data_array.to_json

  log.puts "Converted #{json_file} to #{out_file}."
  log.puts "geo:#{geo_cnt}, plc:#{plc_cnt}, ctd:#{ctd_cnt}, country:#{c_cnt}, lang:#{l_cnt}, edited:#{edt_cnt}, rain_cnt0:#{$rain_cnt0}, rain_cnt15:#{$rain_cnt15}, cnt:#{cnt}, cnt_all:#{cnt_all}, png_cnt: #{png_cnt}, no_png_cnt:#{$no_png_cnt}"
  geo_cnt = 0 # geo_enabled == false
  plc_cnt = 0 # place == nil
  ctd_cnt = 0 # timezone != 0900
  c_cnt = 0 # country != Japan
  l_cnt = 0 # lang != ja
  edt_cnt = 0 # text edited
  $rain_cnt0 = 0 # rain 0
  $rain_cnt15 = 0 # other color
  cnt = 0 # normal
  cnt_all = 0 # all
  png_cnt = 0 # downloaded png
  $no_png_cnt = 0 # can't download

  finish = Time.now
  log.puts "Whole spent time: #{finish-start}" 
rescue Exception => e
  error_log.puts e.message
  # may exceeded ratelimit
end

def mecaber(old_tweet)
  text = old_text
  new_text = ""
  c = MeCab::Tagger.new
  r = /@[a-zA-Z0-9_]*/
  japanese = /(?:\p{Hiragana}|\p{Katakana}|[一-龠々]|[a-zA-Z0-9]|[.,。、])+/
  while r.match(text)!= nil do
    text.slice! r.match(text).to_s
  end
  URI.extract(text).each do |uri|
    text.slice! uri
  end
  text.delete!("\n")
  while japanese.match(text)!=nil do
    new_text << japanese.match(text).to_s
    new_text << " "
    text.slice! japanese.match(text).to_s
  end
  new_text
end

def create_url(created_at, coordinates)
  year = created_at[0,4]
  month = created_at[5,2]
  day = created_at[8,2]
  hour = created_at[11,2]
  min = created_at[14,2].to_i
  min -= min % 5
  if min == 0
    min = "00"
  end
  lat = coordinates[/(?<=\[).+(?=\,)/].to_f
  long = coordinates[/(?<=\s).+(?=\])/].to_f
  plat = Math.log((1+Math.sin(lat*Math::PI/180))/(1-Math.sin(lat*Math::PI/180)))/(4*Math::PI)*64
  plong = (long+180)*64/360
  x = plong.to_i
  y = plat.to_i
  $xpos = ((plong-x)*256).to_i
  $ypos = ((plat-y)*256).to_i
  url = "#{$base_url}x=#{x}&y=#{y}&z=7&date=#{year}#{month}#{day}#{hour}#{min}"
  $uri = URI(url)
  $filename = "img/#{year}/#{month}/#{day}/x#{x}y#{y}_#{hour}#{min}.png"
end

def det_rain
  if !File.exist?($filename)
    # download pnn
    FileUtils::mkdir_p "#{$base_dir}img" unless File.exist?("#{$base_dir}img")
    FileUtils::mkdir_p "#{$base_dir}img/#{$year}" unless File.exist?("#{$base_dir}img/#{$year}")
    FileUtils::mkdir_p "#{$base_dir}img/#{$year}/#{$month}" unless File.exist?("#{$base_dir}img/#{$year}/#{$month}")
    FileUtils::mkdir_p "#{$base_dir}img/#{$year}/#{$month}/#{$day}" unless File.exist?("#{$base_dir}img/#{$year}/#{$month}/#{$day}")
    response = Net::HTTP.get_response($uri)
    if response.code == "200"
      $png_cnt += 1
      img = File.open($filename,'wb')
      img << response.body
      img.close
      image = ChunkyPNG::Image.from_file($filename)
      color = ChunkyPNG::Color.to_hex(image[$xpos,255-$ypos], include_alph = false)
      case color
      when "#000000"
	$rain_v = 0
	$rain_cnt0 += 1
      when "#ccffff"
	$rain_v = 1
      when "#66ffff"
	$rain_v = 2
      when "#00ccff"
	$rain_v = 3
      when "#0099ff"
	$rain_v = 4
      when "#3366ff"
	$rain_v = 5
      when "#33ff00"
	$rain_v = 6
      when "#33cc00"
	$rain_v = 7
      when "#199900"
	$rain_v = 8
      when "#ffff00"
	$rain_v = 9
      when "#ffcc00"
	$rain_v = 10
      when "#ff9900"
	$rain_v = 11
      when "#ff5066"
	$rain_v = 12
      when "#ff0000"
	$rain_v = 13
      when "#b70014"
	$rain_v = 14
      else
	$rain_v = 15 # other colors
	$rain_cnt15 += 1
      end
    else
      $no_png_cnt += 1
      $rain_v = 16  # no png
    end
  end
end