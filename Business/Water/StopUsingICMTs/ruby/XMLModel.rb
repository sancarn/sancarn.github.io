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


require_relative 'libs/nokogiri/lib/nokogiri.rb'
require 'Date'
module OXMLSnapshot
  def export
    #...
  end
  def import
    #...
  end

  Schema = Nokogiri::XML::Schema(File.read(schema_path))
  #Multithreaded for speed
  class XMLModel < Nokogiri::XML::Element
    #Singleton methods
    def self.export(file,net)
      XMLModel.new(net).to_file(file)
    end
    def self.import(file, net)
      XMLModel.new(File.new(file)).to_net(net)
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
      @document = Nokogiri::XML::DocumentFragment.parse("<model name=\"\"></model>")
      model = @document.children[0]
      model.set_attribute("name",getName(net))
      net.scenarios do |scenario|
        #Create scenario XML node
        xmlScenario = Nokogiri::XML::Element.new("scenario",@document)
        xmlScenario.set_attribute("name",scenario)

        #Append node to model children
        model.add_child(xmlScenario)

        #Set scenario
        net.current_scenario = scenario

        #Loop over all tables
        net.tables.map do |table|
          next Thread.new do
            #Create table XML node
            xmlTable = Nokogiri::XML::Element.new("table",@document)
            xmlTable.set_attribute("name",table.name)

            #Append node to scenario children
            xmlScenario.add_child(xmlTable)

            #Loop over rows of table
            rows = net.row_object_collection(table.name)
            rows.enum_for(:each).each_with_index do |row,rowid|
              #Create row XML node
              xmlRow = Nokogiri::XML::Element.new("row",@document)
              xmlRow.set_attribute("id",rowid)

              #Append node to table children
              xmlTable.add_child(xmlRow)
              
              #Loop over fields of table
              table.fields.each do |field|
                if field.datatype=='Flag'
                  #Bind flag to existing field:w
                  match = /(?<field>.+)_flag/i.match(field.name)
                  if match
                    field_name = match["field"]
                    xmlCell = xmlRow.children.select {|cell| cell.attributes["name"].value==field_name}[0]
                    xmlCell.set_attribute("flag",row[field.name])
                  end
                else
                  #Create cell XML node
                  xmlCell = Nokogiri::XML::Element.new("cell",@document)
                  xmlCell.set_attribute("name",field.name)
                  xmlCell.set_attribute("type",field.datatype)
                  #Append node to row:
                  xmlRow.add_child(xmlCell)

                  #Append content to xmlCell
                  value = encodeValue(row,field)
                  if value.is_a? Nokogiri::XML::Element
                    xmlCell.add_child(value)
                  else
                    xmlCell.content = value
                  end
                end
              end

              #Possibly need to deal with scheduled flags here?
            end
          end
        end.each(&:sync)
      end
    end
    def initialise_fromFile(file)
      @document = Nokogiri::XML(file)
      validateDocument()
    end
    def initialise_fromString(xml)
      @document = Nokogiri::XML(xml)
      validateDocument()
    end
    def validateDocument()
      errors = Schema.validate(@document.to_s)
      if errors.length > 0
        raise "Error passing XML\n" + errors.map{|n| n.message}.join("\n")
      end
    end
    
    #Instance methods
    def to_net(net)
      #Import model to network
    end
    def to_file(path)
      #Export model to file
      return File.write(path,document.to_xml)
    end
    def to_s(indent)
      #Export model to string
      return doc.to_xml(:indent => indent)
    end

    private
    def getName(net)
      "current_network" #<-- TODO: I have some code to do this somewhere...
    end
    def encodeValue(row,field)
      if field.datatype == "WSStructure"
        xmlStruct = Nokogiri::XML::Element.new("WSStructure",@document)
        
        #Get fields
        struct_fields = field.fields

        #Loop over struct and generate XML
        struct.each do |row|
          xmlRow = Nokogiri::XML::Element.new("WSStructure_Row",@document)
          xmlStruct.add_child(xmlRow)

          #Append columns to xmlRow
          struct_fields.each do |field|
            #Create cell
            xmlCell = Nokogiri::XML::Element.new("WSStructure_Cell",@document)
            xmlCell.set_attribute("name",f.name)
            xmlCell.set_attribute("type",f.datatype)

            #Add value
            xmlCell.add_child(encodeValue(row[f.name])

            #Append cell to row
            xmlRow.add_child(xmlCell)
          end
        end
      elsif field.datatype == "Date"
        return DateTime.parse(row[field.name]).to_s
      else
        return row[field.name]
      end
    end
  end
end