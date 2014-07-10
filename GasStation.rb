#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'

def getKenList(url)
  #code
  result = []
  html = open(url) do |f|
  f.read
  end
  #parse html
  doc = Nokogiri::HTML.parse(html)
  ken_divs = doc.css('div[id="gs-ranking"]').css('ul[class="cat-list clearfix"]')
  ken_divs = ken_divs[0].css('li')
  ken_divs.each do |ken_div|
    link = ken_div.css('a').first['href']
    result << link
    puts link
  end
  return result
end

def getShopList(args,from_index,to_index)
  ken_list = args
  puts ken_list.length
  ken_list = ken_list[from_index..to_index]
  ken_list.each do |ken|
    result = []
    #code
    url = ken
    #testing
    puts "::PARSING BRAND URL " + url
    #------
    test = false
    i = 0
    while test==false do
      #code
      i = i + 1
      urlx = url + '/' + i.to_s
      
      #testing
      puts "::::PAGE:" + urlx
      #-------
      
      html = open(urlx) do |f|
          f.read
      end
      doc = Nokogiri::HTML.parse(html)
      divs = doc.css('div[id="gs-ranking"]').css('table').css('tr')
      divs[0].remove
      divs.each do |div|
        rows = div.css('td[class="left"]').css('a')
        rows.each do |row|
          result << row['href']
        end
      end
      
      #save the current brand list into file
      
      #test if this is the last page
      test_div = doc.css('div[id="gs-ranking"]').css('p[class="pager"]').css('a')
      if test_div.children.length == 1
        #code
        if test_div.text == "« 前の20件"
          #code
          test= true
        end  
      end
      if test_div.children.length == 0
        #code
        test = true
      end
      
    end
    save_file_gasolin(result)
    puts "SAVED FOR " + url
  end
end

def save_file_gasolin(list)
  CSV.open('list.csv','a') do |csv|
    list.each_slice(1) do |link|
      csv << link
    end
  end
end

def test()
  #code
  from_index = ARGV[0].to_i
  to_index = ARGV[1].to_i
  ken_list = getKenList('http://carlifenavi.com/gs/shoplist')
  shop_list = getShopList(ken_list,from_index,to_index)
  #test_last_page
end

test
