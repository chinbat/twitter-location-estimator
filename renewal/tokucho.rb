require "json"

words_file = File.read("../../data/o50_json.txt")
words = JSON.parse(words_file)["words"]
log = File.open("../../data/tokucho.log","w")
tokucho = File.open("../../data/tokucho.goi","w")
limit = 5
warai = /^[w]+$/ 

map = Hash.new

words.each do |key,value|
  if warai.match(key)!=nil
    next
  end
  filename = "../../data/gois/#{key}"
  coordinates = Hash.new
  File.foreach(filename).each do |coor|
    coors = coor.split(",")
    lat = coors[0]
    long = coors[1]
    freq = coors[2].to_i
    coordinate = "#{lat},#{long}"
    coordinates[coordinate] = freq
  end
  frequency = coordinates.sort_by{|key,value| value}.reverse
  len = coordinates.length
  log.puts "#{key},#{len},#{value}"
  if value.to_f/len >= 10
    map[key] = value
  end
end

smap = map.sort_by{|key,value| value}.reverse

nsmap = {:words => smap}.to_json
tokucho.puts nsmap
puts map.length
