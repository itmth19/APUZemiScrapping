#!/usr/bin/env ruby

require 'rubygems'
require 'csv'
require 'net/https'
require 'open-uri'
require 'json'
require 'uri'
require 'openssl'
require 'highline/import'
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

    arrInput.each do |combini|
      tmpAddress = combini[2]
      if /#{keyArea['level3']}/.match(tmpAddress)
        result << combini
      end
    end
  end
  return result
end

def getAreaName(postal_code)
  #Send to Postal API
  url = 'http://zipcloud.ibsnet.co.jp/api/search?zipcode=' + postal_code
  response = JSON.parse(open(url).read)
  result = Hash.new
  result['level1']= response["results"][0]["address1"]
  result['level2']= response["results"][0]["address2"]
  result['level3']= response["results"][0]["address3"]
  
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
  
  json = JSON.parse(response.body)
  
  status = json['status']
  if status != nil && (status == 'ZERO_RESULTS' || status == 'MAX_WAYPOINTS_EXCEEDED')
    p status
    return 'ERROR'
  end

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
  duration =  json['routes'][0]['legs'][0]['duration']['value']
  distance =  json['routes'][0]['legs'][0]['distance']['value']
  result['distance'] = distance
  result['duration'] = duration

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


def main
  #variables
  info = askInfo
  if info['gasfirst'] != 'y'
    result = findRoutes(info)
    if result != 'ERROR'
      printResult(result)
    else
      p 'Could not locate some of the combini'
    end
  else
    result_final = []
    gasList = []
    gasList = loadAllGas
    nearGas = searchInArea(gasList,info['area'].to_i)
    nearGas.each do |gas|
      @info_tmp = []
      @info_tmp =  Marshal.load(Marshal.dump(info))
      @info_tmp['points'] << gas[2]
      @info_tmp['points_name'] << gas[0]
      #p info['points_name'].count
      #p info_tmp['points_name'].count
      result = findRoutes(@info_tmp)
      if result != 'ERROR'
        if result_final == []
          result_final = Marshal.load(Marshal.dump(result))
        else
          if result_final['distance'] >> result['distance']
             result_final = Marshal.load(Marshal.dump(result))
          end
        end
      end
    end
    printResult(result_final)
    puts '===================================================='
  end
end

def printResult(result)
  puts '=============='
  puts 'Routing result'
  puts '=============='
  puts 'Total distance (approximately) : ' + result['distance'].to_s
  puts 'Total time (approximately) : ' + result['duration'].to_s
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
  info['ori'] = ask("Origin address:"){ |q| q.default = '別府駅'}
  info['dest'] = ask('Destination address:'){ |q| q.default = '大分県別府市石垣東７丁目１−２１吉富ビル第一'}
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

main
#test
#test2
