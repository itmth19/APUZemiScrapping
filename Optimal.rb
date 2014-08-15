#!/usr/bin/env ruby

require 'rubygems'
require 'csv'
require 'net/https'
require 'open-uri'
require 'json'
require 'uri'
require 'openssl'
require 'highline/import'
require 'geocoder'
require 'xlsx_writer'
require 'fileutils'

#require 'always_verify_ssl_certificates'
#AlwaysVerifySSLCertificates.ca_file = "cacert.pem"
#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

def loadAllGasStation

end

def searchInArea(arrInput, origin_postal_code)
  result = []
  (-1..1).each do |i|
    postal_code = origin_postal_code + i
    keyArea = getAreaName(postal_code.to_s)
    if keyArea != []
      arrInput.each do |combini|
        tmpAddress = combini[2]
        if /#{keyArea['level3']}/.match(tmpAddress)
          result << combini
        end
      end
    end
  end
  return result
end

def getAreaName(postal_code)
  #testing
  p 'Looking for postal code = ' + postal_code.to_s
  #testing
  
  #Send to Postal API
  result = []
  url = 'http://zipcloud.ibsnet.co.jp/api/search?zipcode=' + postal_code
  response = JSON.parse(open(url).read)
  if response['results'] != nil
    result = Hash.new
    result['level1']= response["results"][0]["address1"]
    result['level2']= response["results"][0]["address2"]
    result['level3']= response["results"][0]["address3"]
  end
  return result
end

def loadAllCombini
  csv_text = File.read('shopinfo.csv')
  csv_tmp = CSV.parse(csv_text, :headers => false)
  return csv_tmp
end

def loadAllGas
  csv_text = File.read('gasinfo.csv')
  csv_tmp = CSV.parse(csv_text, :headers => false)
  return csv_tmp
end

def findRoutes(nodes)
  #nodes should be address
  result = Hash.new
  url = 'https://maps.googleapis.com/maps/api/directions/json?'
  url = addPara(url,'origin',nodes['ori'])
  url = addPara(url,'destination',nodes['dest'])

  nodes_str = ''
  nodes['points'].each do |point|
    nodes_str += point + '|'
  end
  url = addPara(url,'waypoints','optimize:true|' + nodes_str)
  url = addPara(url,'key','AIzaSyBTE8sjiKQRe9VuVJzW8tbA-SP6aS7cIsU')
  url = addPara(url,'language','ja')
  #url = 'https://maps.googleapis.com/maps/api/directions/json?origin=ローソン%20杵築北浜店&destination=セブンイレブン%20別府石垣東7丁目店&waypoints=optimize:true|ファミリーマート%20別府汐見店|セブンイレブン%20別府タワー店|ァミリーマート%20別府石垣東店&key=AIzaSyBTE8sjiKQRe9VuVJzW8tbA-SP6aS7cIsU&language=ja'
  url = URI::encode(url)
  #p url
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host,uri.port)
  response = Net::HTTP.start(uri.host, use_ssl: true) do |http|
    http.get uri.request_uri, 'User-Agent' => 'MyLib v1.2'
  end
  
  #testing purpose
  #p uri
  #testing purpose

  json = JSON.parse(response.body)
  
  status = json['status']
  if status != nil && (status == 'ZERO_RESULTS' || status == 'MAX_WAYPOINTS_EXCEEDED')
    p status
    return 'ERROR'
  end
  #p json
  order = json['routes'][0]['waypoint_order']

  result['ori'] = nodes['ori']
  result['points'] = []
  result['points_name'] = []

  (0..nodes['points'].count-1).each do |node_i|
    result['points'] << nodes['points'][order[node_i].to_i]
    result['points_name'] << nodes['points_name'][order[node_i].to_i]
  end
  result['dest'] = nodes['dest']
  result['order'] =  []
  result['order'] = order
  
  #duration = 0;
  #distance = 0;
  #route_steps = json['routes'][0]['legs'][0]['steps']
  #route_steps.each do |step|
  #  distance += step['distance']['value'].to_i
  #  duration += step['duration']['value'].to_i
  #end
  #duration =  json['routes'][0]['legs'][0]['duration']['value']
  #distance =  json['routes'][0]['legs'][0]['distance']['value']
  #result['distance'] = distance
  #result['duration'] = duration

  return result
end

def addPara(url, key, value)
  return url + key + '=' + value + '&'
end

def saveResult
  
end

def saveExcelFile

end

def reachNearestCombini

end


def main(info)
  #variables
  if info['gasfirst'] != 'y'
    result = findRoutes(info)
    if result != 'ERROR'
      saveResult('OK',result)
      printResult(result)
    else
      p 'Could not locate some of the combini'
      saveResult('Failed',info)
    end
  else
    result_final = []
    gasList = []
    gasList = loadAllGas
    nearGas = searchInArea(gasList,info['area'].to_i)
    if nearGas.count > 0
      nearGas.each do |gas|
        @info_tmp = []
        @info_tmp =  Marshal.load(Marshal.dump(info))
        @info_tmp['points'] << gas[2]
        @info_tmp['points_name'] << gas[0]
        #p info['points_name'].count
        #p info_tmp['points_name'].count
        result = findRoutes(@info_tmp)
        #p result
        if result != 'ERROR'
          if result_final == []
            result_final = Marshal.load(Marshal.dump(result))
          else
            p result['distance']
            if result_final['distance'].to_i >> result['distance'].to_i
              result_final = Marshal.load(Marshal.dump(result))
            end
          end
          #saveResult('OK',result_final)
          #printResult(result_final)
        else
          #saveResult('Failed',info)
        end
      end
      
      #p result_final
      if result_final != []
        saveResult('OK',result_final)
        printResult(result_final)
      else
        saveResult('Failed',info)
      end
    else
      #could not find any gas stations
      p 'Could not find any gas stations in the area'
      result = findRoutes(info)
      if result != 'ERROR'
        saveResult('OK',result)
        printResult(result)
      else
        p 'Could not locate some of the combini'
        saveResult('Failed',info)
      end
    end
    puts '===================================================='
  end
  #getDataGrid(info,'duration')
end

def printResult(result)
  #p result
  puts '=============='
  puts 'Routing result'
  puts '=============='
  #puts 'Total distance (approximately) : ' + result['distance'].to_s
  #puts 'Total time (approximately) : ' + result['duration'].to_s
  puts 'Routes planning:'
  puts 'From ' + result['ori']
  result['points_name'].each do |point,i|
    puts 'Through ' + i.to_s + '.' + point
  end
  puts 'To ' + result['dest']
end

def test
  nodes = Hash.new
  nodes['ori'] = '別府駅'
  nodes['dest'] = '大分県別府市石垣東７丁目１−２１吉富ビル第一'
  nodes['points'] = []
  #nodes['points'] << 'セブンイレブン 別府石垣東7丁目店'
  nodes['points'] << 'ファミリーマート 別府汐見店'
  nodes['points'] << 'セブンイレブン 別府タワー店'
  nodes['points'] << 'ァミリーマート 別府石垣東店'
  findRoutes(nodes)
end

def test2
  
end

def askInfo
  info = Hash.new
  info['ori'] = ask("Origin address:"){ |q| q.default = '大分駅'}
  info['dest'] = ask('Destination address:'){ |q| q.default = '大分県大分市三川新町２丁目１－１２'}
  info['gasfirst'] = ask('Do you want to fill up the Gas first? (y/n)'){|q| q.default = 'n'}
  info['area'] = ask('Postal Code for the area of Combini stores:'){|q| q.default = '8740919'}
  address_mode = ask('Do you want to choose address mode (y/n):'){ |q| q.default = 'y'}
  
  info['points'] = []
  info['points_name'] = []
  combiniList = loadAllCombini()
  searchList = searchInArea(combiniList,info['area'].to_i)
  puts 'There are totally ' + searchList.count.to_s + ' Combini in this area:'
  searchList.each do |combini|
    p combini[0]
  end
  puts '===================='
  puts 'Please choose which Combini you want to add to the routes?'

  searchList.each do |combini|
    if ask('Add ' + combini[0] + ' into the routes? (y/n)'){|q| q.default = 'n'} == 'y' 
      if address_mode == 'y'
        info['points'] << combini[2]
        info['points_name'] << combini[0]
      else
        info['points'] << combini[0]
        info['points_name'] << combini[0]
      end
    end
  end

  return info
end

def getDataGrid(info,type)
  num = info['points'].count + 2

  grid = Hash.new { |h,k| h[k] = {} }

  points = []
  points << info['ori']
  points << info['dest']
  points.concat(info['points'])
  
  points.each_with_index do |point,i|
    points.each_with_index do |point2,j|
      #if grid[point] == nil
      #  grid[point] = Hash.new
      #end
      if i == j
        #grid.store(point,Hash.new.store(point2,0))
        grid[point][point2] = 0
      else
        result = Hash.new
        distance = findDrivingDetail(point,point2,type)
        grid[point][point2] = distance
      end
    end
  end
  createExcel(grid)
end

def createExcel(grid)
  doc = XlsxWriter::Document.new
  sheet1 = doc.add_sheet 'OptimalRoute'
  sheet1.add_row([])
  #sheet1.add_row(['No','Row','Point','Distance'])
  #sheet1.add_row(["Oita", 0, 13904, 5136, 0, 5305, 5492])
  i=0
  grid.each do |k,v|
    row = []
    i=i+1
    row << {:type => :String, :value => ''}
    row <<  {:type => :String, :value => k}
    row << {:type => :Integer, :value => i}
    v.each do |k2,v2|
      row <<  {:type => :Integer, :value => v2}
    end
    #p row
    sheet1.add_row(row)
  end
  FileUtils.mv doc.path, 'result.xlsx'
end

def saveResult(status,result)
  output = []
  output << status
  output << result.to_s
  CSV.open('result' + '.csv','a') do |csv|
    csv << output
  end
end

def findDrivingDetail(ori, dest,type)
  result = Hash.new
  url = 'https://maps.googleapis.com/maps/api/directions/json?'
  url = addPara(url,'origin',ori)
  url = addPara(url,'destination',dest)
  url = addPara(url,'key','AIzaSyBTE8sjiKQRe9VuVJzW8tbA-SP6aS7cIsU')
  url = addPara(url,'language','ja')
  url = URI::encode(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host,uri.port)
  response = Net::HTTP.start(uri.host, use_ssl: true) do |http|
    http.get uri.request_uri, 'User-Agent' => 'MyLib v1.2'
  end
  json = JSON.parse(response.body)
  return json['routes'][0]['legs'][0][type]['value']
end

def abstractTesting()
  url = 'http://homepage1.nifty.com/tabotabo/pzips/oita.htm'
  http = open(url).read
  postals = http.scan(/(\d{7})/)
  p postals.count
  #p postals
  postals.each do |postal|
    info = Hash.new
    info['ori'] = '大分駅'
    info['dest'] = '大分県大分市三川新町２丁目１－１２'
    info['gasfirst'] = 'n'
    info['area'] = postal
    address_mode = 'y'

    info['points'] = []
    info['points_name'] = []
    combiniList = loadAllCombini()
    searchList = searchInArea(combiniList,info['area'][0].to_i)
    if searchList.count == 0
      info['points'] = []
      info['points_name'] = []
    end
    if searchList.count <= 5
      searchList.each do |point|
        info['points'] << point[2]
        info['points_name'] << point[0]
      end
    end
    if searchList.count > 5
      (1..5).each do |i|
        info['points'] << searchList[i][2]
        info['points_name'] << searchList[i][0]
      end
    end

    #got info
    main(info)
  end
end
abstractTesting()
#info = askInfo()
#main(info)
#test
#test2
#info =  askInfo()
#getDataGrid(info)
#findDrivingDistance('大分県',)
