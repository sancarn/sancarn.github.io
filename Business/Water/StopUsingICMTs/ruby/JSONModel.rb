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


require 'ostruct'
require 'Date'
module OJSONSnapshot
  def export
    #...
  end
  def import
    #...
  end

  #Multithreaded for speed
  class JSONModel
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
                if field.datatype=='Flag'
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
                  jsonField.type = field.datatype
                  #Append node to row:
                  jsonRow.fields.push(jsonField)

                  #Append content to jsonCell
                  jsonField.value = encodeValue(row,field)
                end
              end

              #TODO: Possibly need to deal with scheduled flags here?
            end
          end
        end.each(&:sync)
      end
    end
    def initialise_fromFile(file)
      begin
        @document = JSON.load(file,{:object_class => OpenStruct})
      rescue Exception => e
        raise e 
      end
      validateDocument()
    end
    def initialise_fromString(json)
      begin
        @document = JSON.load(json,{:object_class => OpenStruct})
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
              end.each(&:sync)
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
              jsonTable = scenario.tables.detect {|t| t.name == table.name}

              #If data to write then loop over each row to add
              if jsonTable.rows.length > 0
                jsonTable.rows.each do |jsonRow|
                  #Create row object in network
                  ro = net.new_row_object(table.name)

                  #Find fields which are similar between 2 tables:
                  netFields  = netTable.fields.map {|f| f.name + "-" + f.data_type}
                  jsonFields = jsonRow.fields.map  {|f| f.name + "-" + f.type}
                  simFields  = netFields.select {|netFieldName| jsonFields.include?(netFieldName)}
                  
                  #Loop over similar field names:
                  simFields.each do |fieldName|
                    jsonField = jsonRow.fields.detect {|f| f.name==fieldName}
                    if jsonField.type != "WSStructure"
                      ro[fieldName] = jsonField.value
                      ro[fieldName + "_flag"] = jsonField.meta.flag if jsonField.meta.flag
                    else
                      #TODO: Implement WSStructure writing
                    end
                  end

                  #Write row data:
                  ro.write()
                end
              end
              
              table.fields.each do |field|
                table.fields.select {|f| f.name == field.name}
                if field.type != "WSStructure"
                  ro[field.name] = ro[field.value]
                  ro[field.name + "_flag"] = ro.meta.flag if ro.meta.flag
                else
                  #TODO: WSStructure handling
                end

              end
            end
          end.each(&:sync)
        end
      end
    end
    def to_file(path,pretty=false)
      #Export model to file
      File.open(path,"w") do |file|
        if pretty
          file.write(JSON.pretty_generate(@document))
        else
          JSON.dump(@document,file)
        end
      end
    end
    def to_s(indent)
      #Export model to string
      return doc.to_json(:indent => indent)
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
     
      return iwdb.model_object_from_type_and_id('Model Network',networkID)
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
        struct.each do |row|
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
      elsif field.datatype == "Date"
        return DateTime.parse(row[field.name]).to_s
      else
        return row[field.name]
      end
    end
  end
end