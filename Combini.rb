#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'parallel'
require 'ruby-progressbar'

def saveInfoIntoFile(type,result)
  case type
    when 'shoplist'
      CSV.open(type + '.csv','a') do |csv|
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
  status = 0
  csv_text = File.read('shoplist.csv')
  csv_tmp = CSV.parse(csv_text,:headers => false)
  csv = csv_tmp[from_index..to_index]
  #Parallel.map([1,2001,4001,6001,8001],:in_threads=>5,:progress=>"Overal") do |item|
    Parallel.map_with_index(csv,:in_threads=>20,:progress=>"Percentage Done:") do |row,i|
      #p 'Processing link ' + row[0]
      result = getCombiniInfo(row[0])
      saveInfoIntoFile('shopinfo',result)
      status = i
    end
  #end
   p status
end

def getCombiniInfo(url)
  #define
  result = []
  address = ''
  phone = ''
  note = []
  name = ''
  name_katana = ''

  #code
  begin
    html = open(url) do |f|
      f.read
    end
  rescue OpenURI::HTTPError => e
    p e
    p url
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
      else
        note << li.css('dt').text + ':' + li.css('dd').text
      end
  end
  result << name
  result << name_katana
  result << address
  result << phone
  result << note
  #p result
  return result
end

def getCombiniList(url)
  #get all the prefectures link
  html = open(url).read
  doc = Nokogiri::HTML.parse(html)
  a_prefs = doc.css('div[class="fieldset"]').css('a')
  a_prefs = a_prefs[0..46]
  Parallel.map(a_prefs,:in_threads=>20,:progress=>"Do stuff=") do |link|
    result = []
    #first get the current website
    #get all the list in the current site until don't have link in the last ul[class="col pages"] >> li
    #puts link
    next_link = link.attributes['href'].value
    while next_link != '' do
      html = open(next_link).read
      while html.include? "Access too much!" do
        #p 'Access too much'
        html = open(next_link) do |f|
          f.read
        end
      end
      #p 'Processing Page ' + url
      doc = Nokogiri::HTML.parse(html)
      tmp_result = getCombiniListInPage(next_link)
      result.concat(tmp_result)
      #find the next page link
      a_href = doc.css('ul[class="col pages"] li').children().last()
      if(a_href != nil && a_href.attributes['href'] != nil)
        next_link = a_href.attributes['href'].value
      else
        p 'TTTTTTTTTTTTTTTTTTTTTTTTTTTTT======'
        p next_link
        p doc.css('ul[class="col pages"] li').children()
        p 'TTTTTTTTTTTTTTTTTTTTTTTTTTTTT======'

        next_link = '';
      end
      #p next_link
    end
    #p result.count.to_s
    saveInfoIntoFile('shoplist',result)
  end
end

def getCombiniListInPage(url)
  result = []
  html = open(url) do |f|
    f.read
  end
  #p 'Processing Page ' + url

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
    url = 'http://www.navitime.co.jp/classified/A44_L0201001?cnt=529&p='
    url2 = 'http://www.navitime.co.jp/classified/A44202_L0201001?cnt=61&atr='
    getCombiniList(url2)

  end
end

def optimizeShopList()
  @result = []
  csv_text = File.read('shoplist.csv')
  csv_tmp = CSV.parse(csv_text,:headers => false)
  Parallel.each(csv_tmp,:in_processes=>0, :progress=>"Progress") do |link|
    temp = []
    if not link[0].include?("address")
      temp << link[0]
      temp << TRUE
      @result << temp
    end
  end
  p @result
  CSV.open('optimizedShoplist.csv','a') do |csv|
    @result.each_slice(1) do |link|
      csv << link
    end
  end
end

#main
#getCombiniList('http://www.navitime.co.jp/address/_L0801001')
#optimizeShopList()
