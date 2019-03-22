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
class XMLModel
  @model = {}
  
  #Singleton methods
  def self.export(file,net)
    XMLModel.new(net).to_file(file)
  end
  def self.import(file, net)
    XMLModel.new(File.new(file)).to_net(net)
  end

  #Initialiser
  def initialize(net)
    #If net is File then initialise from file

    #If net is WSOpenNetwork then initialise from network.

  end

  #Instance methods
  def to_net(net)
    #Import model to network
  end
  def to_file(path)
    #Export model to file (instead of to string first)
  end
  def to_s
    #Export model to string
  end
end
class XMLScenario

end
class XMLTable

end
class XMLRow

end