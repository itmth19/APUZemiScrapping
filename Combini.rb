#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'

def saveInfoIntoFile(type,result)
  case type
    when 'shoplist'
      CSV.open(type + '.csv','w') do |csv|
        result.each_slice(1) do |link|
          csv << link
        end
      end
    when 'shopinfo'
      CSV.open(type + '.csv','a') do |csv|
        csv << result
      end
    end
  end

def getTotal
  csv_text = File.read('shoplist.csv')
  csv = CSV.parse(csv_text,:headers => false)
  return csv.count
end

def readCombiniListAndGetInfo(from_index, to_index)
  csv_text = File.read('shoplist.csv')
  csv_tmp = CSV.parse(csv_text,:headers => false)
  csv = csv_tmp[from_index..to_index]
  p csv.count
  p from_index
  p to_index
  csv.each do |row|
      p 'Processing link ' + row[0]
      result = getCombiniInfo(row[0])
      saveInfoIntoFile('shopinfo',result)
  end

end

def getCombiniInfo(url)
  #define
  result = []
  address = ''
  phone = ''
  note = ''
  name = ''
  name_katana = ''

  #code
  html = open(url) do |f|
    f.read
  end
  doc = Nokogiri::HTML.parse(html)
  name_div = doc.css('div[class="spot_info_pane"]').css('div[class="name"]')
  name_katana =  name_div.css('rt').text
  name = name_div.css('h1').text
  
  #process
  detail_divs = doc.css('div[class="detail_info_pane"]').css('div[class="detail_contents"]').css('li')
  detail_divs.each do |li|
    case li.css('dt').text
      when '住所'
        address = li.css('dd').text
      when '電話番号'
        phone = li.css('dd').text
      when '備考'
        note = li.css('dd').text
      end
  end
  result << name
  result << name_katana
  result << address
  result << phone
  result << note
  p result
  return result
end

def getCombiniList(url,total_page)
  result = []
  (0..total_page).each do |i|
    current_page_url = url + i.to_s
    tmp_result = getCombiniListInPage(current_page_url)
    result.concat(tmp_result)
  end
  saveInfoIntoFile('shoplist',result)
end

def getCombiniListInPage(url)
  result = []
  html = open(url) do |f|
    f.read
  end
  p 'Processing Page ' + url

  doc = Nokogiri::HTML.parse(html)
  html_divs = doc.css('div[class="NormalPoiName"]')
  html_divs.each do |combini|
    tmp_link = combini.css('a').first['href']
    result << tmp_link
  end
  return result
end

def main
  case ARGV[0]
  when 'getTotal'
    p getTotal
  when 'getInfoWithIndex'
    from_index = ARGV[1].to_i
    to_index = ARGV[2].to_i
    readCombiniListAndGetInfo(from_index,to_index)
  when 'getInfo'
    readCombiniListAndGetInfo(0,getTotal-1)
  when 'getList'
    url = 'http://www.navitime.co.jp/classified/A44_L0201001?p='
    total_page = 27
    getCombiniList(url,total_page)

  end
end

main
