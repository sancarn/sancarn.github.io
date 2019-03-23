=begin
Structure:
  <model>
    <scenario>
      <table name="">
        <row>
          <column name=""> value </column>
          ...
        </row>
        ...
      </table>
      ...
    </scenario>
  </model>
=end

#Multithreaded for speed
class XMLModel < XMLElement
  @scenarios = nil
  
  #Singleton methods
  def self.export(file,net)
    XMLModel.new(net).to_file(file)
  end
  def self.import(file, net)
    XMLModel.new(File.new(file)).to_net(net)
  end

  #Initialiser
  def initialize(net)
    if net.is_a? File
      initialise_fromFile(net)
    elsif net.is_a? String
      initialise_fromString(net)
    elsif net.is_a? WSOpenNetwork
      initialise_fromNet(net)
    end
  end
  def initialize_fromNet(net)
    @scenarios = []
    net.scenarios do |sc|
      @scenarios.push(XMLScenario.fromNet(net,sc))
    end
  end
  def initialize_fromFile(file)
  end
  def initialise_fromString(pathOrXML)
  end


  #Instance methods
  def to_net(net)
    #Import model to network
  end
  def to_file(path)
    #Export model to file (instead of to string first)
  end
  def to_s(indent)
    s="<model>"
    #Export model to string
    model.scenarios.each do |xmlScenario|
      s += "\n" + xmlScenario.to_s(2)
    end
    s+="\n</model>"
    return s
  end
end
class XMLScenario < XMLElement
  attr_accessor :name, :tables
  @name = ""
  @tables = []
  
  def self.fromNet(net,sc)
    #Create scenario
    scenario = XMLScenario.new
    scenario.name = sc

    #Set scenario
    net.current_scenario = sc

    #Loop over all tables
    net.tables.map do |table|
      XMLTable.fromTable(net,table)
    end
    return scenario
  end
end
class XMLTable < XMLElement
  attr_accessor :rows
  def self.fromTable(net,table)
    table = XMLTable.new
    table.label = "table"
    table.rows = net.row_objects(table.name).map do |row|
      XMLRow.fromRow(net,table,row)
    end
    return table
  end
end
class XMLRow < XMLElement
  attr_accessor :columns
  def self.fromRow(net,table,row)
    #Create row
    row = XMLRow.new
    row.label = "row"
    row.fields.map {|f| f.name.gsub("_flag","")}
    row.columns = table.fields.map do |field|
      hasFlag = ...
      XMLColumn.fromRowField(net,table,row,field,hasFlag)
    end
    return row
  end
end
class XMLColumn < XMLElement
  attr_accessor :name, :flag
  @name = ""
  @flag = ""
  @content = ""
  def self.fromRowField(net,table,row,field,hasFlag)
    column = XMLColumn.new
    column.label = "column"
    column.name = field.name
    column.content = row[field.name]
    if hasFlag
      column.flag = row[field.name+"_flag"]
    end
    return column
  end
end
class XMLElement
  attr_accessor :label
  attr_accessor :content
  def to_s
    "<" + @label + ">" + content + "</" + @label + ">"
  end
end