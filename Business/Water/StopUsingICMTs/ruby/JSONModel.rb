=begin
MIT License

Copyright (c) 2018 James Warren aka Sancarn (http://www.github.com/sancarn)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
=end

=begin
Resulting Structure:
{
  "type":"Model Network",
  "name":"Network name",
  "id":10
  "meta":{...},
  "scenarios":[
    {
      "type":"scenario",
      "name":"base",
      "meta":{...}
      "tables":[
        {
          "type":"table",
          "name":"hw_node",
          "meta":{...}
          "rows":[
            {
              "type":"row",
              "meta":{...}
              "cells":[
                {
                  "type":"cell",
                  ...
                }
              ]

            }
          ]
        },
        ...
      ]
    },
    ...
  ]
}


  <model name="current_network">
    <scenario name="Base">
      <table name="hw_manhole">
        <row>
          <column name="ground_level" flag="S3" dateModified="01/01/2020">10.7</column>
          ...
        </row>
        ...
      </table>
      ...
    </scenario>
  </model>
=end


#TODO: 
#* Export Option Minify - When uncompressed the file contains a lot of blanks which are essentially default data. E.G.
#     {
#       "type": "Date",
#       "meta": {
#         "flag": ""
#       },
#       "name": "year_laid",
#       "value": null
#     },
#     {
#       "type": "String",
#       "meta": {
#         "flag": ""
#       },
#       "name": "owner",
#       "value": ""
#     },
#     {
#       "type": "table",
#       "meta": {
#       },
#       "name": "cams_flood_defence_survey",
#       "rows": [
#
#       ]
#     }
#  The minify version should simply not include these fields... I.E. if data.type == "String" && data.value != "" then fields.push(data)
#  and if data.type == "table" && data.rows.length != 0 then scenario.push(data)


def os_to_hd(o)
  if o.is_a?(OpenStruct) || o.is_a?(Array) || o.is_a?(Hash)
    if o.is_a? OpenStruct
      obj = o.marshal_dump
    else
      obj = o
    end
    if obj.is_a? Hash
      obj.each do |k,v|
        next obj[k] = os_to_hd(v)
      end
    elsif obj.is_a? Array
      obj = obj.map do |v|
        next os_to_hd(v)
      end
    end
    return obj
  else
    return o
  end
end

module OJSONSnapshot
  require 'ostruct'
  require 'Date'
  require 'json'
  
  def export
    #...
  end
  def import
    #...
  end
  
  #Shim for Ruby 2.0 OpenStruct
  class ::OpenStruct
    def [](name)
      @table[name.to_sym]
    end
    def []=(name, value)
      modifiable[new_ostruct_member(name)] = value
    end
  end
  

  #Multithreaded for speed
  class JSONModel
    attr_accessor :errors
    
    #Singleton methods
    def self.export(file,net)
      JSONModel.new(net).to_file(file)
    end
    def self.import(file, net)
      JSONModel.new(File.new(file)).to_net(net)
    end

    def self.newObj(type)
      os = OpenStruct.new({})
      os.type = type
      os.meta = OpenStruct.new({})
      return os
    end

    #Initialiser
    def initialize(net)
      @document = nil
      @scenarios = []

      if net.is_a? File
        initialise_fromFile(net)
      elsif net.is_a? String
        initialise_fromString(net)
      elsif net.is_a? WSOpenNetwork
        initialise_fromNet(net)
      end
    end
    def initialise_fromNet(net)
      isExchange = getIsExchange()
      @document = OpenStruct.new({})
      mo = getModelObject(net)
      @document.name = mo.name
      @document.id = mo.id
      @document.type = mo.type
      @document.meta.description = mo.description if isExchange
      @document.scenarios = []
      net.scenarios do |scenario|
        #Create scenario XML node
        jsonScenario = JSONModel.newObj("scenario")
        jsonScenario.name = scenario
        jsonScenario.tables = []

        #Append node to model children
        @document.scenarios.push(jsonScenario)

        #Set scenario
        net.current_scenario = scenario

        #Loop over all tables
        net.tables.map do |table|
          next Thread.new do
            #Create table XML node
            jsonTable = JSONModel.newObj("table")
            jsonTable.name = table.name
            jsonTable.rows = []

            #Append node to scenario children
            jsonScenario.tables.push(jsonTable)

            #Loop over rows of table
            rows = net.row_object_collection(table.name)
            rows.enum_for(:each).each_with_index do |row,rowid|
              #Create row XML node
              jsonRow = JSONModel.newObj("row")
              jsonRow.id = row.id
              jsonRow.fields = []
              
              #Append node to table children
              jsonTable.rows.push(jsonRow)
              
              #Loop over fields of table
              table.fields.each do |field|
                if field.data_type=='Flag'
                  #Bind flag to existing field:w
                  match = /(?<field>.+)_flag/i.match(field.name)
                  if match
                    field_name = match["field"]
                    jsonCell = jsonRow.fields.select {|cell| cell.name==field_name}[0]
                    jsonCell.meta.flag = row[field.name]
                  end
                else
                  #Create cell XML node
                  jsonField = JSONModel.newObj("field")
                  jsonField.name=field.name
                  jsonField.type = field.data_type
                  #Append node to row:
                  jsonRow.fields.push(jsonField)

                  #Append content to jsonCell
                  jsonField.value = encodeValue(row,field)
                end
              end

              #TODO: Long term need to deal with scheduled flags here. Because not every format 
              #will start with non flag fields.
            end
          end
        end.each(&:join)
      end
    end
    def initialise_fromFile(file)
      begin
        @document = JSON.load(file,nil,{:object_class => OpenStruct})
      rescue Exception => e
        raise e 
      end
      validateDocument()
    end
    def initialise_fromString(json)
      begin
        @document = JSON.load(json,nil,{:object_class => OpenStruct})
      rescue Exception => e
        raise e 
      end
      validateDocument()
    end
    def validateDocument()
      errors = []
      if @document.scenarios.is_a? Array
        @document.scenarios.each do |scenario|
          if scenario.tables.is_a? Array
            scenario.tables.each do |table|
              if table.rows.is_a? Array
                table.rows.each do |row|
                  if !row.fields.is_a? Array
                    errors.push(Exception.new("All rows should have a fields array"))
                  end
                end
              else
                errors.push(Exception.new("All tables should have a rows array"))
              end
            end
          else
            errors.push(Exception.new("All scenarios should have a tables array"))
          end
        end
      else
        errors.push(Exception.new("All models should have a scenarios array"))
      end

      if errors.length > 0
        raise "Error parsing JSON\n" + errors.map{|n| n.message}.join("\n")
      end
    end
    
    #Instance methods
    def to_net(net,overwrite=true)
      
      #Import model to network
      isExchange = getIsExchange()
      
      transaction(net) do 
        if isExchange  
          mo = getModelObject(net)
          mo.description += @document.meta.description
          mo.name = @document.name
        end
        
        #Write scenarios based on existing scenarios
        existing_scenarios = net.enum_for(:scenarios).to_a
        @document.scenarios.each do |scenario|
          #If overwrite delete everything existing in the network:
          if overwrite
            if scenario.name == "Base"
              #Run SQL to delete everything from all tables
              net.current_scenario = "Base"
              net.tables.map do |table|
                Thread.new do
                  net.run_SQL(table.name, "DELETE")
                end
              end.each(&:join)
            else
              #If existing scenario exists, delete it
              if existing_scenarios.include?(scenario.name)
                net.delete_scenario(scenario.name)
              end
              net.add_scenario(scenario.name)
            end
          end
          
          #Set scenario - as per our prep if required this should be a blank network
          net.current_scenario = scenario.name
          net.tables.map do |netTable|
            Thread.new do
              #Find matching table:
              #  netTable  = table in network
              #  jsonTable = table in JSON
              jsonTable = scenario.tables.detect {|t| t.name == netTable.name}
              
              #If data to write then loop over each row to add
              if jsonTable.rows.length > 0
                jsonTable.rows.each do |jsonRow|
                  #Create row object in network
                  ro = net.new_row_object(netTable.name)

                  #Find fields which are similar between 2 tables:
                  netFields  = netTable.fields.select {|f| !f.read_only?}.map {|f| f.name + "-$-" + f.data_type}
                  jsonFields = jsonRow.fields.map  {|f| f.name + "-$-" + f.type}
                  simFields  = netFields.select {|netFieldName| jsonFields.include?(netFieldName)}
                  
                  #Loop over similar field names:
                  simFields.each do |fieldName|
                    #Grab type and 
                    fieldData = fieldName.split("-$-")
                    fieldData = {:name=>fieldData[0],:type=>fieldData[1]}
                    
                    #Get jsonField for field name
                    jsonField = jsonRow.fields.detect {|f| f.name==fieldData[:name]}
                    
                    #Ensure type consistency
                    if fieldData[:type]==jsonField.type
                      #Write data! Special setup for structures and dates
                      if jsonField.type == "Date"
                        ro[fieldData[:name]] = (jsonField.value==nil ? nil : DateTime.parse(jsonField.value).strftime("%d/%m/%Y %H:%M:%S")) #Note: Traditionally this value takes a string not a date time. Post 17.5.8 this field uses date time as well.
                        ro[fieldData[:name] + "_flag"] = jsonField.meta.flag if jsonField.meta.flag
                      elsif jsonField.type == "WSStructure"
                        #TODO: Implement WSStructure writing
                      else
                        begin
                          ro[fieldData[:name]] = jsonField.value
                          ro[fieldData[:name] + "_flag"] = jsonField.meta.flag if jsonField.meta.flag
                        rescue Exception => e
                          errors.push(Exception.new("Error row #{jsonRow.id} for field #{fieldData[:name]}: #{e.message}"))
                        end
                      end
                    end
                  end

                  #Write row data:
                  ro.write()
                end
              end
            end
          end.each(&:join)
        end
      end
    end
    def to_file(path,pretty=false)
      #Export model to file
      File.open(path,"w") do |file|
        if pretty
          file.write(JSON.pretty_generate(os_to_hd(@document)))
        else
          JSON.dump(os_to_hd(@document),file)
        end
      end
    end
    def to_s(indent)
      #Export model to string
      return @document.to_json(:indent => indent)
    end

    private
    def transaction(net,&block)
      net.transaction_begin
        block.call
      net.transaction_commit
    end
    def getIsExchange()
      false
    end
    def getModelObject(net)
      #Get network name
      net.clear_selection
      net.row_objects('_Nodes')[0].selected=true
      options=Hash.new
      options ['Export Selection'] = true
      tmpLoc = File.dirname(WSApplication.script_file) + '\tmp.'
      File.open(tmpLoc + 'cfg', 'w') { |file| file.write("DBX001\nNode,{{,Special,Default,Default,Default,NetworkID}},") }
      net.odec_export_ex('CSV',tmpLoc + 'cfg',options,'Node',tmpLoc + 'csv')
      file = File.open(tmpLoc + 'csv','r')
      networkID = [*file][2-1]
      file.close unless file.nil? or file.closed?
      begin
        File.delete(tmpLoc + 'cfg')
        File.delete(tmpLoc + 'csv')
      rescue Errno::ENOENT
      end
      networkID = networkID.to_i
      net.clear_selection
     
      #Get model network
      iwdb = WSApplication.current_database
      
      #Determine network type
      table1 = net.table_names[0]
      if table1["cams_"]
        netType = "Collection Network"
      elsif table1["hw_"]
        netType = "Model Network"
      elsif table1["wams_"]
        netType = "Distribution Network"
      else
        raise "Unknown network type"
      end

      return iwdb.model_object_from_type_and_id(netType,networkID)
    end
    def getName(net)
      getModelObject(net).name
    end
    def encodeValue(row,field)
      if field.data_type == "WSStructure"
        jsonStruct = JSONModel.newObj("WSStructure")
        jsonStruct.children=[]
        #Get fields
        struct_fields = field.fields

        #Loop over struct and generate XML
        jsonStruct.each do |row|
          jsonRow = JSONModel.newObj("WSStructure_Row")
          jsonStruct.children.push(jsonRow)
          jsonRow.fields = []

          #Append columns to jsonRow
          struct_fields.each do |field|
            #Create cell
            jsonCell = JSONModel.newObj("WSStructure_Cell")
            jsonCell.name=f.name
            jsonCell.type=f.data_type
            
            #Add value
            jsonCell.value = encodeValue(row[f.name])
            #TODO: Handle attachments here?

            #Append cell to row
            jsonRow.fields.push(jsonCell)
          end
        end
        return jsonStruct
      elsif field.data_type == "Date"
        if row[field.name]!=nil
          dt= DateTime.parse(row[field.name].to_s) #CHANGE
          return dt.to_s
        else
          return nil
        end 
      else
        return row[field.name]
      end
    end
  end

  #JSONModel.new(WSApplication.current_network).to_file("C:\\net.json",true)
  #JSONModel.import("C:\\net.json", WSApplication.current_network)
end


